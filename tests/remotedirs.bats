#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown

@test "remote git dirs working, with commit logging"
{
    # Move .git somewhere else
    dotgittestdir=$(mktemp -d)
    mv "$testdir/local/remote/.git" "$dotgittestdir"

    # Start up gitwatch, intentionally in wrong directory, with remote dir specified
    ${BATS_TEST_DIRNAME}/../gitwatch.sh -l 10 -g "$dotgittestdir/.git" "$testdir/local/remote" 3>&- &
    GITWATCH_PID=$!

    # Keeps kill message from printing to screen
    disown

    # Create a file, verify that it hasn't been added yet, then commit
    cd remote

    # According to inotify documentation, a race condition results if you write
    # to directory too soon after it has been created; hence, a short wait.
    sleep 1
    echo "line1" >> file1.txt

    # Wait a bit for inotify to figure out the file has changed, and do its add,
    # and commit
    sleep $WAITTIME

    # Store commit for later comparison
    lastcommit=$(git --git-dir $dotgittestdir/.git rev-parse master)

    # Make a new change
    echo "line2" >> file1.txt
    sleep $WAITTIME
    
    # Verify that new commit has happened
    currentcommit=$(git --git-dir $dotgittestdir/.git rev-parse master)
    [ "$lastcommit" != "$currentcommit" ]

    # Check commit log that the diff is in there
    run git --git-dir $dotgittestdir/.git log -1 --oneline
    [[ $output == *"file1.txt"* ]]

    rm -rf $dotgittestdir
}

