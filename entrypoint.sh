#!/bin/sh -l

########################################################
# check variables
########################################################
if [ -z "$DD_API_KEY" ]; then
    echo "DD_API_KEY not set. Please set one and try again."
    exit 1
fi

if [ -z "$DD_APP_KEY" ]; then
    echo "DD_APP_KEY not set. Please set one and try again."
    exit 1
fi

if [ -z "$DD_ENV" ]; then
    echo "DD_ENV not set. Please set this variable and try again."
    exit 1
fi

if [ -z "$DD_SERVICE" ]; then
    echo "DD_SERVICE not set. Please set this variable and try again."
    exit 1
fi

if [ -z "$CPU_COUNT" ]; then
    # the default CPU count is 2
    CPU_COUNT=2
fi

if [ "$ENABLE_PERFORMANCE_STATISTICS" = "true" ]; then
    ENABLE_PERFORMANCE_STATISTICS="--performance-statistics"
else
    ENABLE_PERFORMANCE_STATISTICS=""
fi

if [ "$ENABLE_DEBUG" = "yes" ]; then
    DEBUG_ARGUMENT_VALUE="yes"
else
    DEBUG_ARGUMENT_VALUE="no"
fi

if [ -n "$SUBDIRECTORY" ]; then
  for subdirectory in $SUBDIRECTORY; do
    SUBDIRECTORY_OPTION="$SUBDIRECTORY_OPTION --subdirectory $subdirectory"
  done
fi

if [ "$DIFF_AWARE" = "true" ]; then
    DIFF_AWARE_VALUE="--diff-aware"
else
    DIFF_AWARE_VALUE=""
fi

# verify ARCHITECTURE is x86_64 or aarch64
if [ "$ARCHITECTURE" != "x86_64" ] && [ "$ARCHITECTURE" != "aarch64" ]; then
    echo "ARCHITECTURE must be x86_64 or aarch64"
    exit 1
fi

########################################################
# static analyzer tool stuff
########################################################
TOOL_DIRECTORY=$(mktemp -d)

if [ ! -d "$TOOL_DIRECTORY" ]; then
    echo "Tool directory $TOOL_DIRECTORY does not exist"
    exit 1
fi

cd "$TOOL_DIRECTORY" || exit 1
curl -L -o datadog-static-analyzer.zip https://github.com/DataDog/datadog-static-analyzer/releases/latest/download/datadog-static-analyzer-$ARCHITECTURE-unknown-linux-gnu.zip >/dev/null 2>&1 || exit 1
unzip datadog-static-analyzer >/dev/null 2>&1 || exit 1
CLI_LOCATION=$TOOL_DIRECTORY/datadog-static-analyzer

########################################################
# datadog-ci stuff
########################################################
echo "Installing 'datadog-ci'"
npm install -g @datadog/datadog-ci || exit 1

DATADOG_CLI_PATH=/usr/bin/datadog-ci

# Check that datadog-ci was installed
if [ ! -x $DATADOG_CLI_PATH ]; then
    echo "The datadog-ci was not installed correctly, not found in $DATADOG_CLI_PATH."
    exit 1
fi

echo "Done: datadog-ci available $DATADOG_CLI_PATH"
echo "Version: $($DATADOG_CLI_PATH version)"

########################################################
# output directory
########################################################
echo "Getting output directory"
OUTPUT_DIRECTORY=$(mktemp -d)

# Check that datadog-ci was installed
if [ ! -d "$OUTPUT_DIRECTORY" ]; then
    echo "Output directory ${OUTPUT_DIRECTORY} does not exist"
    exit 1
fi

OUTPUT_FILE="$OUTPUT_DIRECTORY/output.sarif"

echo "Done: will output results at $OUTPUT_FILE"

########################################################
# execute the tool and upload results
########################################################

# navigate to workspace root, so the datadog-ci command can access the git info
cd ${GITHUB_WORKSPACE} || exit 1
git config --global --add safe.directory ${GITHUB_WORKSPACE} || exit 1

# Only upload git metadata if diff aware is enabled.
if [ "$DIFF_AWARE" = "true" ]; then
    echo "Disabling extensions.worktreeConfig"
    git config --unset extensions.worktreeConfig
    echo "Done"

    echo "Upload git metadata"
    ${DATADOG_CLI_PATH} git-metadata upload
    echo "Done"
fi

echo "Starting Static Analysis"
$CLI_LOCATION -i "$GITHUB_WORKSPACE" -g -o "$OUTPUT_FILE" -f sarif --cpus "$CPU_COUNT" "$ENABLE_PERFORMANCE_STATISTICS" --debug $DEBUG_ARGUMENT_VALUE $SUBDIRECTORY_OPTION $DIFF_AWARE_VALUE|| exit 1
echo "Done"

echo "Uploading Static Analysis Results to Datadog"
${DATADOG_CLI_PATH} sarif upload "$OUTPUT_FILE" --service "$DD_SERVICE" --env "$DD_ENV" || exit 1
echo "Done"

########################################################
# SCA/SBOM
########################################################
if [ "${SCA_ENABLED}" = "true" ] || [ "${SCA_ENABLED}" = "yes" ]; then
  echo "SCA no longer supported in this GitHub action, use https://github.com/DataDog/datadog-sca-github-action"
fi
