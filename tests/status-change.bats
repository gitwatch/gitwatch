#!/usr/bin/env bats

# This is a testscript using the bats testing framework:
# https://github.com/sstephenson/bats
# To run it, at a command prompt:
# bats testscript.bats

load startup-shutdown

function commit_only_when_git_status_change { #@test

  # Start up gitwatch and capture its output
  ${BATS_TEST_DIRNAME}/../gitwatch.sh "$testdir/local/remote" > "$testdir/output.txt" 3>&- &
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

  # Touch the file, but no change
  touch file1.txt
  sleep $WAITTIME

  echo "hi there" > "$testdir/output.txt"
  cat "$testdir/output.txt"
  run git log -1 --oneline
  echo $output
  #run bash -c "grep \"nothing to commit\" $testdir/output.txt | wc -l"
  run grep "nothing to commit" $testdir/output.txt
  [ $status -ne 0 ]

}
