#!/usr/bin/env bash
#
# gitwatch - watch file or directory and git commit all changes as they happen
#
# Copyright (C) 2013-2018  Patrick Lehner
#   with modifications and contributions by:
#   - Matthew McGowan
#   - Dominik D. Geyer
#   - Phil Thompson
#   - Dave Musicant
#
#############################################################################
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
#
#   Idea and original code taken from http://stackoverflow.com/a/965274
#       original work by Lester Buck
#       (but heavily modified by now)
#
#   Requires the command 'inotifywait' to be available, which is part of
#   the inotify-tools (See https://github.com/rvoicilas/inotify-tools ),
#   and (obviously) git.
#   Will check the availability of both commands using the `which` command
#   and will abort if either command (or `which`) is not found.
#

REMOTE=""
BRANCH=""
SLEEP_TIME=2
DATE_FMT="+%Y-%m-%d %H:%M:%S"
COMMITMSG="Scripted auto-commit on change (%d) by gitwatch.sh"
LISTCHANGES=-1
LISTCHANGES_COLOR="--color=always"
GIT_DIR=""

# Print a message about how to use this script
shelp() {
  echo "gitwatch - watch file or directory and git commit all changes as they happen"
  echo ""
  echo "Usage:"
  echo "${0##*/} [-s <secs>] [-d <fmt>] [-r <remote> [-b <branch>]]"
  echo "          [-m <msg>] [-l|-L <lines>] <target>"
  echo ""
  echo "Where <target> is the file or folder which should be watched. The target needs"
  echo "to be in a Git repository, or in the case of a folder, it may also be the top"
  echo "folder of the repo."
  echo ""
  echo " -s <secs>        After detecting a change to the watched file or directory,"
  echo "                  wait <secs> seconds until committing, to allow for more"
  echo "                  write actions of the same batch to finish; default is 2sec"
  echo " -d <fmt>         The format string used for the timestamp in the commit"
  echo "                  message; see 'man date' for details; default is "
  echo '                  "+%Y-%m-%d %H:%M:%S"'
  echo " -r <remote>      If given and non-empty, a 'git push' to the given <remote>"
  echo "                  is done after every commit; default is empty, i.e. no push"
  echo " -b <branch>      The branch which should be pushed automatically;"
  echo "                - if not given, the push command used is  'git push <remote>',"
  echo "                    thus doing a default push (see git man pages for details)"
  echo "                - if given and"
  echo "                  + repo is in a detached HEAD state (at launch)"
  echo "                    then the command used is  'git push <remote> <branch>'"
  echo "                  + repo is NOT in a detached HEAD state (at launch)"
  echo "                    then the command used is"
  echo "                    'git push <remote> <current branch>:<branch>'  where"
  echo "                    <current branch> is the target of HEAD (at launch)"
  echo "                  if no remote was defined with -r, this option has no effect"
  echo " -g <path>        Location of the .git directory, if stored elsewhere in"
  echo "                  a remote location. This specifies the --git-dir parameter"
  echo " -l <lines>       Log the actual changes made in this commit, up to a given"
  echo "                  number of lines, or all lines if 0 is given"
  echo " -L <lines>       Same as -l but without colored formatting"
  echo " -m <msg>         The commit message used for each commit; all occurrences of"
  echo "                  %d in the string will be replaced by the formatted date/time"
  echo "                  (unless the <fmt> specified by -d is empty, in which case %d"
  echo "                  is replaced by an empty string); the default message is:"
  echo '                  "Scripted auto-commit on change (%d) by gitwatch.sh"'
  echo " -e <events>      Events passed to inotifywait to watch (defaults to "
  echo "                  '$EVENTS')"
  echo "                  (useful when using inotify-win, e.g. -e modify,delete,move)"
  echo "                  (currently ignored on Mac, which only uses default values)"
  echo ""
  echo "As indicated, several conditions are only checked once at launch of the"
  echo "script. You can make changes to the repo state and configurations even while"
  echo "the script is running, but that may lead to undefined and unpredictable (even"
  echo "destructive) behavior!"
  echo "It is therefore recommended to terminate the script before changing the repo's"
  echo "config and restarting it afterwards."
  echo ""
  echo 'By default, gitwatch tries to use the binaries "git", "inotifywait", and'
  echo "\"readline\", expecting to find them in the PATH (it uses 'which' to check this"
  echo "and will abort with an error if they cannot be found). If you want to use"
  echo "binaries that are named differently and/or located outside of your PATH, you can"
  echo "define replacements in the environment variables GW_GIT_BIN, GW_INW_BIN, and"
  echo "GW_RL_BIN for git, inotifywait, and readline, respectively."
}

# print all arguments to stderr
stderr() {
  echo "$@" >&2
}

# clean up at end of program, killing the remaining sleep process if it still exists
cleanup() {
  if [[ -n $SLEEP_PID ]] && kill -0 "$SLEEP_PID" &> /dev/null; then
    kill "$SLEEP_PID" &> /dev/null
  fi
  exit 0
}

# Tests for the availability of a command
is_command() {
  hash "$1" 2> /dev/null
}

###############################################################################

while getopts b:d:h:g:L:l:m:p:r:s:e: option; do # Process command line options
  case "${option}" in
    b) BRANCH=${OPTARG} ;;
    d) DATE_FMT=${OPTARG} ;;
    h)
      shelp
      exit
      ;;
    g) GIT_DIR=${OPTARG} ;;
    l) LISTCHANGES=${OPTARG} ;;
    L)
      LISTCHANGES=${OPTARG}
      LISTCHANGES_COLOR=""
      ;;
    m) COMMITMSG=${OPTARG} ;;
    p | r) REMOTE=${OPTARG} ;;
    s) SLEEP_TIME=${OPTARG} ;;
    e) EVENTS=${OPTARG} ;;
    *)
      stderr "Error: Option '${option}' does not exist."
      shelp
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1)) # Shift the input arguments, so that the input file (last arg) is $1 in the code below

if [ $# -ne 1 ]; then # If no command line arguments are left (that's bad: no target was passed)
  shelp               # print usage help
  exit                # and exit
fi

# if custom bin names are given for git, inotifywait, or readlink, use those; otherwise fall back to "git", "inotifywait", and "readlink"
if [ -z "$GW_GIT_BIN" ]; then GIT="git"; else GIT="$GW_GIT_BIN"; fi

if [ -z "$GW_INW_BIN" ]; then
  # if Mac, use fswatch
  if [ "$(uname)" != "Darwin" ]; then
    INW="inotifywait"
    EVENTS="${EVENTS:-close_write,move,move_self,delete,create,modify}"
  else
    INW="fswatch"
    # default events specified via a mask, see
    # https://emcrisostomo.github.io/fswatch/doc/1.14.0/fswatch.html/Invoking-fswatch.html#Numeric-Event-Flags
    # default of 414 = MovedTo + MovedFrom + Renamed + Removed + Updated + Created
    #                = 256 + 128+ 16 + 8 + 4 + 2
    EVENTS="${EVENTS:---event=414}"
  fi
else
  INW="$GW_INW_BIN"
fi

if [ -z "$GW_RL_BIN" ]; then RL="readlink"; else RL="$GW_RL_BIN"; fi

# Check availability of selected binaries and die if not met
for cmd in "$GIT" "$INW"; do
  is_command "$cmd" || {
    stderr "Error: Required command '$cmd' not found."
    exit 2
  }
done
unset cmd

###############################################################################

SLEEP_PID="" # pid of timeout subprocess

trap "cleanup" EXIT # make sure the timeout is killed when exiting script

# Expand the path to the target to absolute path
if [ "$(uname)" != "Darwin" ]; then
  IN=$($RL -f "$1")
else
  if is_command "greadlink"; then
    IN=$(greadlink -f "$1")
  else
    IN=$($RL -f "$1")
    if [ $? -eq 1 ]; then
      echo "Seems like your readlink doesn't support '-f'. Running without. Please 'brew install coreutils'."
      IN=$($RL "$1")
    fi
  fi
fi

if [ -d "$1" ]; then # if the target is a directory

  TARGETDIR=$(sed -e "s/\/*$//" <<< "$IN") # dir to CD into before using git commands: trim trailing slash, if any
  # construct inotifywait-commandline
  if [ "$(uname)" != "Darwin" ]; then
    INW_ARGS=("-qmr" "-e" "$EVENTS" "--exclude" "'(\.git/|\.git$)'" "\"$TARGETDIR\"")
  else
    # still need to fix EVENTS since it wants them listed one-by-one
    INW_ARGS=("--recursive" "$EVENTS" "-E" "--exclude" "'(\.git/|\.git$)'" "\"$TARGETDIR\"")
  fi
  GIT_ADD_ARGS="--all ." # add "." (CWD) recursively to index
  GIT_COMMIT_ARGS=""     # add -a switch to "commit" call just to be sure

elif [ -f "$1" ]; then # if the target is a single file

  TARGETDIR=$(dirname "$IN") # dir to CD into before using git commands: extract from file name
  # construct inotifywait-commandline
  if [ "$(uname)" != "Darwin" ]; then
    INW_ARGS=("-qm" "-e" "$EVENTS" "$IN")
  else
    INW_ARGS=("$EVENTS" "$IN")
  fi

  GIT_ADD_ARGS="$IN" # add only the selected file to index
  GIT_COMMIT_ARGS="" # no need to add anything more to "commit" call
else
  stderr "Error: The target is neither a regular file nor a directory."
  exit 3
fi

# If $GIT_DIR is set, verify that it is a directory, and then add parameters to
# git command as need be
if [ -n "$GIT_DIR" ]; then

  if [ ! -d "$GIT_DIR" ]; then
    stderr ".git location is not a directory: $GIT_DIR"
    exit 4
  fi

  GIT="$GIT --no-pager --work-tree $TARGETDIR --git-dir $GIT_DIR"
fi

# Check if commit message needs any formatting (date splicing)
if ! grep "%d" > /dev/null <<< "$COMMITMSG"; then # if commitmsg didn't contain %d, grep returns non-zero
  DATE_FMT=""                                     # empty date format (will disable splicing in the main loop)
  FORMATTED_COMMITMSG="$COMMITMSG"                # save (unchanging) commit message
fi

# CD into right dir
cd "$TARGETDIR" || {
  stderr "Error: Can't change directory to '${TARGETDIR}'."
  exit 5
}

if [ -n "$REMOTE" ]; then        # are we pushing to a remote?
  if [ -z "$BRANCH" ]; then      # Do we have a branch set to push to ?
    PUSH_CMD="$GIT push $REMOTE" # Branch not set, push to remote without a branch
  else
    # check if we are on a detached HEAD
    if HEADREF=$($GIT symbolic-ref HEAD 2> /dev/null); then # HEAD is not detached
      #PUSH_CMD="$GIT push $REMOTE $(sed "s_^refs/heads/__" <<< "$HEADREF"):$BRANCH"
      PUSH_CMD="$GIT push $REMOTE ${HEADREF#refs/heads/}:$BRANCH"
    else # HEAD is detached
      PUSH_CMD="$GIT push $REMOTE $BRANCH"
    fi
  fi
else
  PUSH_CMD="" # if not remote is selected, make sure push command is empty
fi

# A function to reduce git diff output to the actual changed content, and insert file line numbers.
# Based on "https://stackoverflow.com/a/12179492/199142" by John Mellor
diff-lines() {
  local path=
  local line=
  local previous_path=
  while read -r; do
    esc=$'\033'
    if [[ $REPLY =~ ---\ (a/)?([^[:blank:]$esc]+).* ]]; then
      previous_path=${BASH_REMATCH[2]}
      continue
    elif [[ $REPLY =~ \+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
      path=${BASH_REMATCH[2]}
    elif [[ $REPLY =~ @@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@.* ]]; then
      line=${BASH_REMATCH[2]}
    elif [[ $REPLY =~ ^($esc\[[0-9;]+m)*([\ +-]) ]]; then
      REPLY=${REPLY:0:150} # limit the line width, so it fits in a single line in most git log outputs
      if [[ $path == "/dev/null" ]]; then
        echo "File $previous_path deleted or moved."
        continue
      else
        echo "$path:$line: $REPLY"
      fi
      if [[ ${BASH_REMATCH[2]} != - ]]; then
        ((line++))
      fi
    fi
  done
}

###############################################################################

# main program loop: wait for changes and commit them
#   whenever inotifywait reports a change, we spawn a timer (sleep process) that gives the writing
#   process some time (in case there are a lot of changes or w/e); if there is already a timer
#   running when we receive an event, we kill it and start a new one; thus we only commit if there
#   have been no changes reported during a whole timeout period
eval "$INW" "${INW_ARGS[@]}" | while read -r line; do
  # is there already a timeout process running?
  if [[ -n $SLEEP_PID ]] && kill -0 "$SLEEP_PID" &> /dev/null; then
    # kill it and wait for completion
    kill "$SLEEP_PID" &> /dev/null || true
    wait "$SLEEP_PID" &> /dev/null || true
  fi

  # start timeout process
  (
    sleep "$SLEEP_TIME" # wait some more seconds to give apps time to write out all changes

    if [ -n "$DATE_FMT" ]; then
      #FORMATTED_COMMITMSG="$(sed "s/%d/$(date "$DATE_FMT")/" <<< "$COMMITMSG")" # splice the formatted date-time into the commit message
      FORMATTED_COMMITMSG="${COMMITMSG/\%d/$(date "$DATE_FMT")}" # splice the formatted date-time into the commit message
    fi

    if [[ $LISTCHANGES -ge 0 ]]; then # allow listing diffs in the commit log message, unless if there are too many lines changed
      DIFF_COMMITMSG="$($GIT diff -U0 "$LISTCHANGES_COLOR" | diff-lines)"
      LENGTH_DIFF_COMMITMSG=0
      if [[ $LISTCHANGES -ge 1 ]]; then
        LENGTH_DIFF_COMMITMSG=$(echo -n "$DIFF_COMMITMSG" | grep -c '^')
      fi
      if [[ $LENGTH_DIFF_COMMITMSG -le $LISTCHANGES ]]; then
        # Use git diff as the commit msg, unless if files were added or deleted but not modified
        if [ -n "$DIFF_COMMITMSG" ]; then
          FORMATTED_COMMITMSG="$DIFF_COMMITMSG"
        else
          FORMATTED_COMMITMSG="New files added: $($GIT status -s)"
        fi
      else
        #FORMATTED_COMMITMSG="Many lines were modified. $FORMATTED_COMMITMSG"
        FORMATTED_COMMITMSG=$($GIT diff --stat | grep '|')
      fi
    fi

    # CD into right dir
    cd "$TARGETDIR" || {
      stderr "Error: Can't change directory to '${TARGETDIR}'."
      exit 6
    }
    STATUS=$($GIT status -s)
    if [ -n "$STATUS" ]; then # only commit if status shows tracked changes.
      # We want GIT_ADD_ARGS and GIT_COMMIT_ARGS to be word splitted
      # shellcheck disable=SC2086
      $GIT add $GIT_ADD_ARGS # add file(s) to index
      # shellcheck disable=SC2086
      $GIT commit $GIT_COMMIT_ARGS -m"$FORMATTED_COMMITMSG" # construct commit message and commit

      if [ -n "$PUSH_CMD" ]; then
        echo "Push command is $PUSH_CMD"
        eval "$PUSH_CMD"
      fi
    fi
  ) & # and send into background

  SLEEP_PID=$! # and remember its PID
done
