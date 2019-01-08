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


teardown() {
    # Remove testing directories
    cd /tmp

    rm -rf $testdir

    # Make sure gitwatch script gets killed if script stopped background
    # Must kill the entire tree of processes generated
    pkill -15 -P $GITWATCH_PID
}
