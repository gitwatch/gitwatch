#!/usr/bin/env bats

# This inserts customs setup and teardown because of spaces in the file name

function spaces_in_target_dir { #@test
    # Time to wait for gitwatch to respond
    # shellcheck disable=SC2034
    WAITTIME=4
    # Set up directory structure and initialize remote
    testdir=$(mktemp -d "/tmp/tmp space.XXXXXXX")
    # shellcheck disable=SC2164
    cd "$testdir"
    mkdir remote
    # shellcheck disable=SC2164
    cd remote
    git init -q --bare
    # shellcheck disable=SC2103
    cd ..
    # shellcheck disable=SC2164
    mkdir local
    # shellcheck disable=SC2164
    cd local
    git clone -q ../remote

    # Start up gitwatch with logging, see if works
    "${BATS_TEST_DIRNAME}"/../gitwatch.sh -l 10 "$testdir/local/remote" 3>&- &
    GITWATCH_PID=$!
    echo "$GITWATCH_PID"

    # Keeps kill message from printing to screen
    disown

    # Create a file, verify that it hasn't been added yet, then commit
    cd remote

    echo '# Teardown started' >&3
    # Remove testing directories
    # shellcheck disable=SC2164
    cd /tmp

    # Kill background process
    # kill -9 %1
    # fg

    # Also make sure to kill fswatch if on Mac
    killall fswatch || true
    # Make sure gitwatch script gets killed if script stopped background
    # Must kill the entire tree of processes generated
    pkill -15 -f gitwatch.sh
    pkill -15 -f gitwatch.sh
    # pkill -15 -P "$GITWATCH_PID"

    echo '# Teardown complete' >&3
}

