# This inserts customs setup and teardown because of spaces in the file name

setup() {
  # Time to wait for gitwatch to respond
  # shellcheck disable=SC2034
  WAITTIME=4
  # Set up directory structure and initialize remote
  testdir=$(mktemp -d)
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
  git clone -q ../remote "remote with spaces"
}

teardown() {
  echo '# Teardown started' >&3
  # Remove testing directories
  # shellcheck disable=SC2164
  cd /tmp

  # Kill background process
  kill -9 %1
  fg

  # Also make sure to kill fswatch if on Mac
  killall fswatch
  # Make sure gitwatch script gets killed if script stopped background
  # Must kill the entire tree of processes generated
  pkill -15 -P "$GITWATCH_PID"

  echo '# Teardown complete' >&3
}
