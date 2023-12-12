#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown


# Test for exclude from notifications. Verify that a subdirectory is ignored from notification.

function notify_ignore { #@test

    # Start up gitwatch and capture its output
    ${BATS_TEST_DIRNAME}/../gitwatch.sh -x test_subdir "$testdir/local/remote" > "$testdir/output.txt" 3>&- &
    GITWATCH_PID=$!

    # Keeps kill message from printing to screen
    disown

    # Create a file, verify that it hasn't been added yet, then commit
    cd remote
    mkdir test_subdir

    # According to inotify documentation, a race condition results if you write
    # to directory too soon after it has been created; hence, a short wait.
    sleep 1
    echo "line1" >> file1.txt

    # Wait a bit for inotify to figure out the file has changed, and do its add,
    # and commit
    sleep $WAITTIME

    # Add second file that we plan to ignore
    cd test_subdir
    echo "line2" >> file2.txt

    # Wait a bit for inotify to figure out the file has changed, and do its add,
    # and commit
    sleep $WAITTIME

    cat "$testdir/output.txt"
    run git log --name-status --oneline
    echo $output

    # Look for files in log: file1 should be there, file2 should not be
    run grep "file1.txt" $testdir/output.txt
    [ $status -eq 0 ]

    run grep "file2.txt" $testdir/output.txt
    [ $status -ne 0 ]
}


