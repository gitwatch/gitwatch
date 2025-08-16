#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown

function pulling_and_rebasing_correctly { #@test

    # Create a file, verify that it hasn't been added yet,
    # then commit and push
    cd remote

    # Start up gitwatch and see if commit and push happen automatically
    # after waiting two seconds
    ${BATS_TEST_DIRNAME}/../gitwatch.sh -r origin -R "$testdir/local/remote" 3>- &
    GITWATCH_PID=$!

    # Keeps kill message from printing to screen
    disown

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

    # Create a second local
    cd ../..
    mkdir local2
    cd local2
    git clone -q ../remote
    cd remote

    # Add a file to new repo
    sleep 1
    echo "line2" >> file2.txt
    git add file2.txt
    git commit -am "file 2 added"
    git push

    # Change back to original repo, make a third change, then verify that
    # second one got here
    cd ../../local/remote
    sleep 1
    echo "line3" >> file3.txt

    # Verify that push happened
    currentcommit=$(git rev-parse main)
    remotecommit=$(git rev-parse origin/main)
    [ "$currentcommit" = "$remotecommit" ]

    # Verify that new file is here
    sleep $WAITTIME
    [ -f file2.txt ]

    # Remove testing directories
    cd /tmp
    rm -rf $testdir
}

