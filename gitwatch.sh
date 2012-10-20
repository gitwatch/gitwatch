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

IN=$(readlink -f "$1")

if [ -d $1 ]; then
    TARGETDIR=`echo "$IN" | sed -e "s/\/*$//" `
    INCOMMAND="inotifywait --exclude=\"^${TARGETDIR}/.git\" -qqr -e close_write,moved_to,delete $TARGETDIR"
    GITADD="."
    GITINCOMMAND=" -a"
elif [ -f $1 ]; then
    TARGETDIR=$(dirname $IN)
    INCOMMAND="inotifywait -qq -e close_write,moved_to,delete $IN"
    GITADD="$IN"
    GITINCOMMAND=""
else
    exit
fi

#echo $INCOMMAND
#echo $TARGETDIR
#echo $GITPREPCOMMAND
#echo $GITINCOMMAND
#exit

while true; do
    $INCOMMAND
    sleep 2
#    echo "committing"
    DATE=`date "+%Y-%m-%d %H:%M:%S"`
    #CMD="cd $TARGETDIR ; git add $GITADD ; git commit$GITINCOMMAND -m\"Scripted auto-commit on change (${DATE})\""
    #`$CMD`
    cd $TARGETDIR
    git add $GITADD
    git commit$GITINCOMMAND -m"Scripted auto-commit on change (${DATE})"
done
#echo '$TARGETDIR'
