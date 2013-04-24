#!/usr/bin/env bash
#
# gitwatch - watch file or directory and git commit all changes as they happen
#
# Copyright (C) 2013  Patrick Lehner
#   with modifications and contributions by:
#   - Matthew McGowan
#   - Dominik D. Geyer
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

shelp () { # Print a message about how to use this script
    echo "gitwatch - watch file or directory and git commit all changes as they happen"
    echo ""
    echo "Usage:"
    echo "${0##*/} [-s <secs>] [-d <fmt>] [-r <remote> [-b <branch>]]"
    echo "          [-m <msg>] <target>"
    echo ""
    echo "Where <target> is the file or folder which should be watched. The target needs"
    echo "to be in a Git repository, or in the case of a folder, it may also be the top"
    echo "folder of the repo."
    echo ""
    echo " -s <secs>        after detecting a change to the watched file or directory,"
    echo "                  wait <secs> seconds until committing, to allow for more"
    echo "                  write actions of the same batch to finish; default is 2sec"
    echo " -d <fmt>         the format string used for the timestamp in the commit"
    echo "                  message; see 'man date' for details; default is "
    echo "                  \"+%Y-%m-%d %H:%M:%S\""
    echo " -r <remote>      if defined, a 'git push' to the given <remote> is done after"
    echo "                  every commit"
    echo " -b <branch>      the branch which should be pushed automatically;"
    echo "                - if not given, the push command used is  'git push <remote>',"
    echo "                    thus doing a default push (see git man pages for details)"
    echo "                - if given and"
    echo "                  + repo is in a detached HEAD state (at launch)"
    echo "                    then the command used is  'git push <remote> <branch>'"
    echo "                  + repo is NOT in a detached HEAD state (at launch)"
    echo "                    then the command used is"
    echo "                    'git push <remote> <current branch>:<branch>'  where"
    echo "                    <current branch> is the target of HEAD (at launch)"
    echo "                  if no remote was define with -r, this option has no effect"
    echo " -m <msg>         the commit message used for each commit; all occurences of"
    echo "                  %d in the string will be replaced by the formatted date/time"
    echo "                  (unless the <fmt> specified by -d is empty, in which case %d"
    echo "                  is replaced by an empty string); the default message is:"
    echo "                  \"Scripted auto-commit on change (%d) by gitwatch.sh\""
    echo ""
    echo "As indicated, several conditions are only checked once at launch of the"
    echo "script. You can make changes to the repo state and configurations even while"
    echo "the script is running, but that may lead to undefined and unpredictable (even"
    echo "destructive) behavior!"
    echo "It is therefore recommended to terminate the script before changin the repo's"
    echo "config and restarting it afterwards."
}

while getopts b:d:hm:p:r:s: option # Process command line options 
do 
    case "${option}" in 
        b) BRANCH=${OPTARG};;
        d) DATE_FMT=${OPTARG};;
        h) shelp; exit;;
        m) COMMITMSG=${OPTARG};;
        p|r) REMOTE=${OPTARG};;
        s) SLEEP_TIME=${OPTARG};;
    esac
done

shift $((OPTIND-1)) # Shift the input arguments, so that the input file (last arg) is $1 in the code below

if [ $# -ne 1 ]; then # If no command line arguments are left (that's bad: no target was passed)
    shelp # print usage help
    exit # and exit
fi

is_command () { # Tests for the availability of a command
	which $1 &>/dev/null
}

# Check dependencies and die if not met
for cmd in git inotifywait; do
	is_command $cmd || { echo "Error: Required command '$cmd' not found." >&2; exit 1; }
done
unset cmd

# Check if commit message needs any formatting (date splicing)
if ! grep "%d" > /dev/null <<< "$COMMITMSG"; then # if commitmsg didnt contain %d, grep returns non-zero
    DATE_FMT="" # empty date format (will disable splicing in the main loop)
    FORMATTED_COMMITMSG="$COMMITMSG" # save (unchanging) commit message
fi

# Expand the path to the target to absolute path
IN=$(readlink -f "$1")

if [ -d $1 ]; then # if the target is a directory
    TARGETDIR=$(sed -e "s/\/*$//" <<<"$IN") # dir to CD into before using git commands: trim trailing slash, if any
    INCOMMAND="inotifywait --exclude=\"^${TARGETDIR}/.git\" -qqr -e close_write,move,delete,create $TARGETDIR" # construct inotifywait-commandline
    GITADD="." # add "." (CWD) recursively to index
    GIT_COMMIT_ARGS="-a" # add -a switch to "commit" call just to be sure
elif [ -f $1 ]; then # if the target is a single file
    TARGETDIR=$(dirname "$IN") # dir to CD into before using git commands: extract from file name
    INCOMMAND="inotifywait -qq -e close_write,move,delete $IN" # construct inotifywait-commandline
    GITADD="$IN" # add only the selected file to index
    GIT_COMMIT_ARGS="" # no need to add anything more to "commit" call
else
    echo >&2 "Error: The target is neither a regular file nor a directory."
    exit 1
fi

cd $TARGETDIR # CD into right dir

# check if we are on a detached HEAD
HEADREF=$(git symbolic-ref HEAD 2> /dev/null)
if [ $? -eq 0 ]; then # HEAD is not detached
    PUSH_BRANCH_EXPR="$(sed "s_^refs/heads/__" <<< "$HEADREF"):$BRANCH"
else # HEAD is detached
    PUSH_BRANCH_EXPR="$BRANCH"
fi

# main program loop: wait for changes and commit them
while true; do
    $INCOMMAND # wait for changes
    sleep $SLEEP_TIME # wait some more seconds to give apps time to write out all changes
    if [ -n "$DATE_FMT" ]; then
        FORMATTED_COMMITMSG="$(sed "s/%d/$(date "$DATE_FMT")/" <<< "$COMMITMSG")" # splice the formatted date-time into the commit message
    fi
    cd $TARGETDIR # CD into right dir
    git add $GITADD # add file(s) to index
    git commit $GIT_COMMIT_ARGS -m"$FORMATTED_COMMITMSG" # construct commit message and commit

    if [ -n "$REMOTE" ]; then # are we pushing to a remote?
       if [ -z "$BRANCH" ]; then # Do we have a branch set to push to ?
           git push $REMOTE # Branch not set, push to remote without a branch
       else
           git push $REMOTE $PUSH_BRANCH_EXPR # Branch set, push to the remote with the given branch
       fi
    fi
done

