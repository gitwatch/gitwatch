#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

@test "syncing correctly" {

    # Set up directory structure and initialize remote
    testdir=$(mktemp -d)
    cd $testdir
    mkdir remote
    cd remote
    git init -q --bare
    cd ..
    mkdir local
    cd local
    git clone -q ../remote

    # Start up gitwatch and see if commit and push happen automatically
    # after waiting two seconds
    ~/system/gitwatch/gitwatch.sh -r origin "$testdir/local/remote" 3>- &
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
    sleep 5
    
    # Verify that push happened
    currentcommit=$(git rev-parse master)
    remotecommit=$(git rev-parse origin/master)
    [ "$currentcommit" = "$remotecommit" ]

    # Remove testing directories
    cd /tmp
    rm -rf $testdir
}


teardown() {
    # Make sure gitwatch script gets killed if script stopped background
    kill $GITWATCH_PID
}
