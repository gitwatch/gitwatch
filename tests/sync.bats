#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown

function syncing_correctly { #@test
    # Start up gitwatch and see if commit and push happen automatically
    # after waiting two seconds
    ${BATS_TEST_DIRNAME}/../gitwatch.sh -r origin "$testdir/local/remote" 3>- &
    GITWATCH_PID=$!

    # Keeps kill message from printing to screen
    disown

    # Create a file, verify that it hasn't been added yet,
    # then commit and push
    cd remote

    # According to inotify documentation, a race condition results if you write
    # to directory too soon after it has been created; hence, a short wait.
    sleep 1
    echo "line1" >> file1.txt

    # Wait a bit for inotify to figure out the file has changed, and do its add,
    # commit, and push.
    sleep $WAITTIME

    # Verify that push happened
    currentcommit=$(git rev-parse main)
    remotecommit=$(git rev-parse origin/main)
    [ "$currentcommit" = "$remotecommit" ]

    # Try making subdirectory with file
    lastcommit=$(git rev-parse main)
    mkdir subdir
    cd subdir
    echo "line2" >> file2.txt

    sleep $WAITTIME

    # Verify that new commit has happened
    currentcommit=$(git rev-parse main)
    [ "$lastcommit" != "$currentcommit" ]

    # Verify that push happened
    currentcommit=$(git rev-parse main)
    remotecommit=$(git rev-parse origin/main)
    [ "$currentcommit" = "$remotecommit" ]


    # Try removing file to see if can work
    rm file2.txt
    sleep $WAITTIME

    # Verify that new commit has happened
    currentcommit=$(git rev-parse main)
    [ "$lastcommit" != "$currentcommit" ]

    # Verify that push happened
    currentcommit=$(git rev-parse main)
    remotecommit=$(git rev-parse origin/main)
    [ "$currentcommit" = "$remotecommit" ]

    # Remove testing directories
    cd /tmp
    rm -rf $testdir
}

