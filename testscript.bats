#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

setup() {
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
}

@test "syncing correctly" {

    # Start up gitwatch and see if commit and push happen automatically
    # after waiting two seconds
    ${BATS_TEST_DIRNAME}/gitwatch.sh -r origin "$testdir/local/remote" 3>- &
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
     
    # Try making subdirectory with file
    lastcommit=$(git rev-parse master)
    mkdir subdir
    cd subdir
    echo "line2" >> file2.txt

    sleep 5

    # Verify that new commit has happened
    currentcommit=$(git rev-parse master)
    [ "$lastcommit" != "$currentcommit" ]
      
    # Verify that push happened
    currentcommit=$(git rev-parse master)
    remotecommit=$(git rev-parse origin/master)
    [ "$currentcommit" = "$remotecommit" ]


    # Try removing file to see if can work
    rm file2.txt
    sleep 5

    # Verify that new commit has happened
    currentcommit=$(git rev-parse master)
    [ "$lastcommit" != "$currentcommit" ]
      
    # Verify that push happened
    currentcommit=$(git rev-parse master)
    remotecommit=$(git rev-parse origin/master)
    [ "$currentcommit" = "$remotecommit" ]

    # Remove testing directories
    cd /tmp
    rm -rf $testdir
}


@test "commit log messages working" {

    # Start up gitwatch with logging, see if works
    ${BATS_TEST_DIRNAME}/gitwatch.sh -l 10 "$testdir/local/remote" 3>- &
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

    # Make a new change
    echo "line2" >> file1.txt
    sleep 5

    # Check commit log that the diff is in there
    run git log -1 --oneline
    echo "# Output is $output" >&3
    [[ $output == *"file1.txt"* ]]

}

teardown() {
    # Remove testing directories
    cd /tmp

    rm -rf $testdir

    # Make sure gitwatch script gets killed if script stopped background
    # Must kill the entire tree of processes generated
    pkill -15 -P $GITWATCH_PID
}
