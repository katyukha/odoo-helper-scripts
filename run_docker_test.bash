#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
PROJECT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=`pwd`;


#------------------------------------------------------
# Prepare test command
#------------------------------------------------------
TEST_CMD="sudo /etc/init.d/postgresql start;";
TEST_CMD="$TEST_CMD cd /home/odoo/odoo-helper-scripts;";
TEST_CMD="$TEST_CMD bash install-user.bash;";
TEST_CMD="$TEST_CMD source /home/odoo/.profile;";

#------------------------------------------------------
# Set up default values
#------------------------------------------------------
TEST_FILE=tests/test.bash;
DOCKER_FILE=$PROJECT_DIR/tests/docker/;

#------------------------------------------------------
# Parse commandline arguments
#------------------------------------------------------
usage="Usage:

    $SCRIPT_NAME --docker-file <path>       - path to dockerfile to build docker image for.
                                              Default: $DOCKER_FILE
    $SCRIPT_NAME --docker-ti                - add '-ti' options to 'docker run' cmd
    $SCRIPT_NAME --with-coverage            - run with code coverage
    $SCRIPT_NAME --test-file <path>         - run test file. default: $TEST_FILE
    $SCRIPT_NAME --help                     - show this help message

";

if [[ $# -lt 1 ]]; then
    echo "$usage";
    exit 0;
fi

while [[ $# -gt 0 ]]
do
    key="$1";
    case $key in
        --docker-file)
            DOCKER_FILE=$2;
            shift;
        ;;
        --docker-ti)
            EXTRA_DOCKER_RUN_OPT="-ti";
        ;;
        --with-coverage)
            WITH_COVERAGE=bashcov;
        ;;
        --test-file)
            TEST_FILE=$2;
            shift;
        ;;
        -h|--help|help)
            echo "$usage";
            exit 0;
        ;;
        *)
            echo "Unknown option / command $key";
            exit 1;
        ;;
    esac
    shift
done
#------------------------------------------------------

D_TEST_CMD="$TEST_CMD $WITH_COVERAGE $TEST_FILE;";

set -e; # fail on errors


IMAGE=$(docker build -q -t odoo-helper-test $DOCKER_FILE)

exec docker run --rm $EXTRA_DOCKER_RUN_OPT \
    -v $PROJECT_DIR:/home/odoo/odoo-helper-scripts:rw \
    -e "CI_RUN=1" -e "TEST_TMP_DIR=/home/odoo/test-tmp" $IMAGE  bash -c "$D_TEST_CMD";
