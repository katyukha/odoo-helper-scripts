#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
PROJECT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=`pwd`;

WITH_COVERAGE=bashcov;
#WITH_COVERAGE=;
TEST_CMD="sudo /etc/init.d/postgresql start;";
TEST_CMD="$TEST_CMD cd /home/odoo/odoo-helper-scripts;";
TEST_CMD="$TEST_CMD bash install-user.bash;";
TEST_CMD="$TEST_CMD source /home/odoo/.profile;";

if [ -z $1 ]; then
    TEST_CMD="$TEST_CMD $WITH_COVERAGE tests/test.bash;";
else
    TEST_CMD="$TEST_CMD $1";
    EXTRA_DOCKER_RUN_OPT="-ti";
fi


set -e; # fail on errors


IMAGE=$(docker build -q -t odoo-helper-test $PROJECT_DIR/tests/docker/)

exec docker run --rm $EXTRA_DOCKER_RUN_OPT \
    -v $PROJECT_DIR:/home/odoo/odoo-helper-scripts:rw \
    -e "CI_RUN=1" -e "TEST_TMP_DIR=/home/odoo/test-tmp" $IMAGE  bash -c "$TEST_CMD";
