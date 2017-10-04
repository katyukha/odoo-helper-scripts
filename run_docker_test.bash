#!/bin/bash

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
PROJECT_DIR=$(readlink -f "$(dirname $SCRIPT)");
WORK_DIR=`pwd`;


#------------------------------------------------------
# Environment
#------------------------------------------------------
E_TEST_TMP_DIR=/opt/odoo-helper-scripts/test-temp;

#------------------------------------------------------
# Prepare install
#------------------------------------------------------
L_LANG='en_US.UTF-8'
L_LANGUAGE="en_US:en"
CMD_INSTALL="apt-get update && apt-get install -y adduser sudo locales && \
sed -i 's/^# *\($L_LANG\)/\1/' /etc/locale.gen && locale-gen $L_LANG && \
export LANG=$L_LANG && export LANGUAGE=$L_LANGUAGE && export LC_ALL=$L_LANG && \
update-locale LANG=$L_LANG && update-locale LANGUAGE=$L_LANGUAGE && \
adduser --disabled-password --gecos '' --shell '/bin/bash' --home=/home/odoo odoo && \
echo 'odoo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/odoo && \
bash /opt/odoo-helper-scripts/install-system.bash \
rm -rf $E_TEST_TMP_DIR && \
sudo mkdir -p $E_TEST_TMP_DIR && \
sudo chown odoo:odoo -R $E_TEST_TMP_DIR";


#------------------------------------------------------
# Prepare cleanup cmd
#------------------------------------------------------
CMD_CLEANUP="sudo rm -rf rm -rf $E_TEST_TMP_DIR";

#------------------------------------------------------
# Set up default values
#------------------------------------------------------
TEST_FILE=/opt/odoo-helper-scripts/tests/test.bash;
#DOCKER_FILE=$PROJECT_DIR/tests/docker/;
DOCKER_TEST_IMAGE=odoo-helper-test
DOCKER_IMAGE="ubuntu:16.04"

#------------------------------------------------------
# Parse commandline arguments
#------------------------------------------------------
usage="Usage:

    $SCRIPT_NAME --docker-build <path>      - path to dockerfile to build docker image for.
                                              Default: $DOCKER_FILE
    $SCRIPT_NAME --docker-image <image>     - name of docker image to test on
                                              Default: $DOCKER_IMAGE
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
            DOCKER_IMAGE=$DOCKER_TEST_IMAGE;
            shift;
        ;;
        --docker-image)
            DOCKER_FILE=;
            DOCKER_IMAGE=$2;
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

D_CMD_TEST="cd /home/odoo && sudo -E -u odoo -H bash $TEST_FILE";

set -e; # fail on errors

if [ ! -z $DOCKER_FILE ]; then
    echo "Building image for $DOCKER_FILE"
    IMAGE=$(docker build -q -t $DOCKER_TEST_IMAGE $DOCKER_FILE);
else
    IMAGE=$DOCKER_IMAGE;
fi

exec docker run --rm $EXTRA_DOCKER_RUN_OPT \
    -v $PROJECT_DIR:/opt/odoo-helper-scripts:rw \
    -e "CI_RUN=1" -e "TEST_TMP_DIR=$E_TEST_TMP_DIR" $IMAGE \
    bash -c "$CMD_INSTALL && $D_CMD_TEST && $CMD_CLEANUP";
