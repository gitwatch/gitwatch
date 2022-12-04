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
  git clone -q ../remote
}

function close_non_std_fds() {
  local open_fds non_std_fds=()
  get_open_fds
  for fd in "${open_fds[@]}"; do
    if [[ $fd -gt 2 ]]; then
      non_std_fds+=("$fd")
    fi
  done
  close_fds "${non_std_fds[@]}"
}

teardown() {
  echo '# Teardown started' >&3
  # Remove testing directories
  # shellcheck disable=SC2164
  cd /tmp

  #    rm -rf $testdir

  echo "Process id again $GITWATCH_PID" >&3
  # Make sure gitwatch script gets killed if script stopped background
  # Also make sure to kill fswatch if on Mac
  killall fswatch
  # Must kill the entire tree of processes generated
  pkill -15 -P "$GITWATCH_PID"

  close_non_std_fds

  echo '# Teardown complete' >&3

}
