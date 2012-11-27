#!/bin/bash
#
# gitwatch - watch file or directory and git commit all changes as they happen
#
# Copyright (C) 2012  Patrick Lehner
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
#   the inotify-tools (See https://github.com/rvoicilas/inotify-tools )
#

if [ -z $1 ]; then
    exit
fi

# Check for both git and inotifywait and generate an error
# if either don't exist or you cannot run them

which git > /dev/null 2>/dev/null
if [ $? -eq 1 ]; then
    echo >&2 "Git not found and it is required to use this script."
    exit 1;

fi
which inotifywait > /dev/null 2>/dev/null
if [ $? -eq 1 ]; then
    echo >&2 "inotifywait not found and it is required to use this script."
    exit;
fi

#These two strings are used to construct the commit comment
#  They're glued together like "<CCPREPEND>(<DATE&TIME>)<CCAPPEND>"
#If you don't want to add text before and/or after the date/time, simply
#  set them to empty strings
CCPREPEND="Scripted auto-commit on change "
CCAPPEND=" by gitwatch.sh"

IN=$(readlink -f "$1")

if [ -d $1 ]; then
    TARGETDIR=`echo "$IN" | sed -e "s/\/*$//" ` #dir to CD into before using git commands: trim trailing slash, if any
    INCOMMAND="inotifywait --exclude=\"^${TARGETDIR}/.git\" -qqr -e close_write,moved_to,delete $TARGETDIR" #construct inotifywait-commandline
    GITADD="." #add "." (CWD) recursively to index
    GITINCOMMAND=" -a" #add -a switch to "commit" call just to be sure
elif [ -f $1 ]; then
    TARGETDIR=$(dirname $IN) #dir to CD into before using git commands: extract from file name
    INCOMMAND="inotifywait -qq -e close_write,moved_to,delete $IN" #construct inotifywait-commandline
    GITADD="$IN" #add only the selected file to index
    GITINCOMMAND="" #no need to add anything more to "commit" call
else
    exit
fi

while true; do
    $INCOMMAND #wait for changes
    sleep 2 #wait 2 more seconds to give apps time to write out all changes
    DATE=`date "+%Y-%m-%d %H:%M:%S"` #construct date-time string
    cd $TARGETDIR #CD into right dir
    git add $GITADD #add file(s) to index
    git commit$GITINCOMMAND -m"${CCPREPEND}(${DATE})${CCAPPEND}" # construct commit message and commit
done
