#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown

function commit_command_single { #@test

  # Start up gitwatch with custom commit command, see if works
  "${BATS_TEST_DIRNAME}"/../gitwatch.sh -c "uname" "$testdir/local/remote" 3>&- &
  GITWATCH_PID=$!

  # Keeps kill message from printing to screen
  disown

  # Create a file, verify that it hasn't been added yet, then commit and push
  cd remote

  # According to inotify documentation, a race condition results if you write
  # to directory too soon after it has been created; hence, a short wait.
  sleep 1
  echo "line1" >> file1.txt

  # Wait a bit for inotify to figure out the file has changed, and do its add, commit, and push.
  sleep $WAITTIME

  run git log -1 --oneline
  [[ $output == *$(uname) ]]
}

function commit_command_format { #@test
  # tests nested commit command

  # Start up gitwatch with custom commit command, see if works
  "${BATS_TEST_DIRNAME}"/../gitwatch.sh -c "echo '$(uname) is the uname of this device, the time is $(date)' " "$testdir/local/remote" 3>&- &
  GITWATCH_PID=$!

  # Keeps kill message from printing to screen
  disown

  # Create a file, verify that it hasn't been added yet, then commit and push
  cd remote

  # According to inotify documentation, a race condition results if you write
  # to directory too soon after it has been created; hence, a short wait.
  sleep 1
  echo "line1" >> file1.txt

  # Wait a bit for inotify to figure out the file has changed, and do its add, commit, and push.
  sleep $WAITTIME

  run git log -1 --oneline
  [[ $output == *$(uname)* ]]
  [[ $output == *$(date +%Y)* ]]
}

function commit_command_overwrite { #@test
  # Start up gitwatch with custom commit command, see if works
  "${BATS_TEST_DIRNAME}"/../gitwatch.sh -c "uname" -l 123 -L 0 -d "+%Y" "$testdir/local/remote" 3>&- &
  GITWATCH_PID=$!

  # Keeps kill message from printing to screen
  disown

  # Create a file, verify that it hasn't been added yet, then commit and push
  cd remote

  # According to inotify documentation, a race condition results if you write
  # to directory too soon after it has been created; hence, a short wait.
  sleep 1
  echo "line1" >> file1.txt

  # Wait a bit for inotify to figure out the file has changed, and do its add, commit, and push.
  sleep $WAITTIME

  run git log -1 --oneline
  [[ $output == *$(uname)* ]]
}
