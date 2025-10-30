#!/usr/bin/env bats

# This inserts customs setup and teardown because of spaces in the file name

load startup-shutdown-spaces

function spaces_in_target_dir { #@test
  # Start up gitwatch with logging, see if works
  "${BATS_TEST_DIRNAME}"/../gitwatch.sh -l 10 "$testdir/local/rem with spaces" 3>&- &
  echo "Testdir: $testdir" >&3
  GITWATCH_PID=$!

  # Keeps kill message from printing to screen
  disown

  # Create a file, verify that it hasn't been added yet, then commit
  cd "rem with spaces"

  # According to inotify documentation, a race condition results if you write
  # to directory too soon after it has been created; hence, a short wait.
  sleep 1
  echo "line1" >> file1.txt

  # Wait a bit for inotify to figure out the file has changed, and do its add,
  # and commit
  sleep "$WAITTIME"

  # Make a new change
  echo "line2" >> file1.txt
  sleep "$WAITTIME"

  # Check commit log that the diff is in there
  run git log -1 --oneline
  [[ $output == *"file1.txt"* ]]
}
