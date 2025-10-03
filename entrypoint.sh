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
# Read the user-friendly pattern
USER_EXCLUDE_PATTERN=${EXCLUDE_PATTERN:-""}
EVENTS=${EVENTS:-""}

# Boolean flags (set to "true" to enable)
PULL_BEFORE_PUSH=${PULL_BEFORE_PUSH:-false}
SKIP_IF_MERGING=${SKIP_IF_MERGING:-false}

# --- Command Construction ---

# Use a bash array to safely build the command and its arguments
cmd=( "/app/gitwatch.sh" )

# Add options with arguments
cmd+=( -r "${GIT_REMOTE}" )
cmd+=( -b "${GIT_BRANCH}" )
cmd+=( -s "${SLEEP_TIME}" )
cmd+=( -m "${COMMIT_MSG}" )
cmd+=( -d "${DATE_FMT}" )

# --- Convert User-Friendly Exclude Pattern to Regex ---
if [ -n "${USER_EXCLUDE_PATTERN}" ]; then
  # 1. Replace commas and any surrounding spaces with the regex OR pipe `|`
  PROCESSED_PATTERN=$(echo "$USER_EXCLUDE_PATTERN" | sed 's/\s*,\s*/|/g')

  # 2. Escape periods to treat them as literal dots in regex
  PROCESSED_PATTERN=${PROCESSED_PATTERN//./\\.}

  # 3. Convert glob stars `*` into the regex equivalent `.*`
  PROCESSED_PATTERN=${PROCESSED_PATTERN//\*/\.\*}

  cmd+=( -x "${PROCESSED_PATTERN}" )
fi


if [ -n "${EVENTS}" ]; then
  cmd+=( -e "${EVENTS}" )
fi

# Add boolean flags if they are set to "true"
if [ "${PULL_BEFORE_PUSH}" = "true" ]; then
  cmd+=( -R )
fi

if [ "${SKIP_IF_MERGING}" = "true" ]; then
  cmd+=( -M )
fi

# The final argument is the directory to watch
cmd+=( "${GIT_WATCH_DIR}" )

# --- Execution ---

echo "Starting gitwatch with the following arguments:"
# Use printf with %q to safely quote the arguments for display
printf "%q " "${cmd[@]}"
echo # Add a newline for cleaner logging
echo "-------------------------------------------------"

# Use exec to replace the current shell process with gitwatch
exec "${cmd[@]}"
