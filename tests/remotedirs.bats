#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown

@test "remote git dirs working" {
    # Start up gitwatch, intentionally in wrong directory, wiht remote dir specified
    ${BATS_TEST_DIRNAME}/../gitwatch.sh -g "$testdir/local/remote" "/tmp" 3>&- &
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
    sleep 5

    # Store commit for later comparison
    lastcommit=$(git rev-parse master)

    # Make a new change
    echo "line2" >> file1.txt
    sleep 5
    
    # Verify that new commit has happened
    currentcommit=$(git rev-parse master)
    [ "$lastcommit" != "$currentcommit" ]
}

