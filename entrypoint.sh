#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Environment Variable Configuration with Defaults ---

# Target directory to watch
GIT_WATCH_DIR=${GIT_WATCH_DIR:-/app/watched-repo}

# Git options
GIT_REMOTE=${GIT_REMOTE:-origin}
GIT_BRANCH=${GIT_BRANCH:-main}

# Gitwatch behavior
SLEEP_TIME=${SLEEP_TIME:-2}
COMMIT_MSG=${COMMIT_MSG:-"Scripted auto-commit on change (%d) by gitwatch.sh"}
DATE_FMT=${DATE_FMT:-"+%Y-%m-%d %H:%M:%S"}
EXCLUDE_PATTERN=${EXCLUDE_PATTERN:-""}
EVENTS=${EVENTS:-""}

# Boolean flags (set to "true" to enable)
PULL_BEFORE_PUSH=${PULL_BEFORE_PUSH:-false}
SKIP_IF_MERGING=${SKIP_IF_MERGING:-false}

# --- Command Construction ---

# Start with the base command
CMD_ARGS=""

# Add options with arguments
CMD_ARGS+=" -r ${GIT_REMOTE}"
CMD_ARGS+=" -b ${GIT_BRANCH}"
CMD_ARGS+=" -s ${SLEEP_TIME}"
CMD_ARGS+=" -m \"${COMMIT_MSG}\""
CMD_ARGS+=" -d \"${DATE_FMT}\""

if [ -n "${EXCLUDE_PATTERN}" ]; then
  CMD_ARGS+=" -x \"${EXCLUDE_PATTERN}\""
fi

if [ -n "${EVENTS}" ]; then
  CMD_ARGS+=" -e \"${EVENTS}\""
fi

# Add boolean flags if they are set to "true"
if [ "${PULL_BEFORE_PUSH}" = "true" ]; then
  CMD_ARGS+=" -R"
fi

if [ "${SKIP_IF_MERGING}" = "true" ]; then
  CMD_ARGS+=" -M"
fi

# The final argument is the directory to watch
CMD_ARGS+=" \"${GIT_WATCH_DIR}\""

# --- Execution ---

echo "Starting gitwatch with the following arguments:"
echo "/app/gitwatch.sh ${CMD_ARGS}"
echo "-------------------------------------------------"

# Use eval to correctly handle quotes in arguments
eval exec /app/gitwatch.sh "${CMD_ARGS}"
