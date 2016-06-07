#!/bin/bash

# this script run's basic tests

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
WORK_DIR=`pwd`;
TEST_TMP_DIR="$WORK_DIR/test-temp";

ERROR=;

tempfiles=( )

# do cleanup on exit
cleanup() {
  if [ -z $ERROR ]; then
      rm -rf "$TEST_TMP_DIR";
  fi
}
trap cleanup 0

# Handle errors
# Based on: http://stackoverflow.com/questions/64786/error-handling-in-bash#answer-185900
error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  ERROR=1;
  if [[ -n "$message" ]] ; then
    echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
  fi
  exit "${code}"
}
trap 'error ${LINENO}' ERR

# Fail on any error
set -e;

# Init test tmp dir
mkdir -p $TEST_TMP_DIR;
cd $TEST_TMP_DIR;

# Prepare for test (if running on CI)
if [ ! -z $CI_RUN ]; then
    echo "Running as in CI environment";
    export ALWAYS_ANSWER_YES=1;

    if ! command -v "odoo-install" >/dev/null 2>&1 || ! command -v "odoo-helper" >/dev/null 2>&1; then
        echo "Seems that odoo-helper-scripts were not installed correctly!";
        echo "PATH: $PATH";
        echo "Current path: $(pwd)";
        echo "Home var: $HOME";
        echo "";
        if [ -f $HOME/odoo-helper.conf ]; then
            echo "User conf: ";
            echo "$(cat $HOME/odoo-helper.conf)";
        else
            echo "User conf not found!";
        fi
        echo "";
        echo "Content of ~/.profile file:";
        echo "$(cat $HOME/.profile)";
        echo "";
        echo "Content of ~/.bashrc file:";
        echo "$(cat $HOME/.bashrc)";
        echo "";
        echo "Content of ~/.bash_profile file:";
        echo "$(cat $HOME/.bash_profile)";
        echo "";
        
    fi
    sudo pip install --upgrade pytz
fi

#
# Start test
# ==========
#

odoo-helper --help
odoo-install --help
