#!/bin/bash

# this script run's basic tests

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
WORK_DIR=`pwd`;
TEST_TMP_DIR="$WORK_DIR/test-temp";

tempfiles=( )

# do cleanup on exit
cleanup() {
  rm -rf "$TEST_TMP_DIR";
}
trap cleanup 0

# Handle errors
# Based on: http://stackoverflow.com/questions/64786/error-handling-in-bash#answer-185900
error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
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

# Prepare for test
if [ ! -z $CI_RUN ]; then
    echo "Running as in CI environment";
    export ALWAYS_ANSWER_YES=1;
fi

#
# Start test
# ==========
#

odoo-install --install-dir odoo-7.0 --branch 7.0 --extra-utils --install-and-conf-postgres --install-sys-deps
cd odoo-7.0

# Now You will have odoo-7.0 installed in this directory.
# Note, thant Odoo this odoo install uses virtual env (venv dir)
# Also You will find there odoo-helper.conf config file

# So now You may run local odoo server (i.e openerp-server script).
# Note that this command run's server in foreground.
odoo-helper server --stop-after-init  # This will automaticaly use config file: conf/odoo.conf

# Also you may run server in background using
odoo-helper server start

# there are also few additional server related commands:
odoo-helper server status
# odoo-helper server log    # note that this option runs less, so blocks for input
odoo-helper server restart
odoo-helper server stop
odoo-helper server status

# Let's install base_tags addon into this odoo installation
odoo-helper fetch --github katyukha/base_tags --branch master

# Now look at custom_addons/ dir, there will be placed links to addons
# from https://github.com/katyukha/base_tags repository
# But repository itself is placed in downloads/ directory
# By default no branch specified when You fetch module,
# but there are -b or --branch option which can be used to specify which branch to fetch

# Now let's run tests for these just installed modules
odoo-helper test --create-test-db -m base_tags -m product_tags

# this will create test database (it will be dropt after test finishes) and 
# run tests for modules 'base_tags' and 'product_tags'

# If You need color output from Odoo, you may use '--use-unbuffer' option,
# but it depends on 'expect-dev' package
odoo-helper --use-unbuffer test --create-test-db -m base_tags -m product_tags

# The one cool thing of odoo-helper script, you may not remeber paths to odoo instalation,
# and if you change directory to another inside your odoo project, everything will continue to work.
cd custom_addons
odoo-helper server status
odoo-helper server restart
odoo-helper server stop
odoo-helper server status

# So... let's install one more odoo version
# go back to directory containing our projects (that one, where odoo-7.0 project is placed)
cd ../../

# Let's install odoo of version 8.0 too here.
odoo-install --install-dir odoo-8.0 --branch 8.0 --extra-utils
cd odoo-8.0

# and install there for example addon 'project_sla' for 'project-service' Odoo Comutinty repository
# Note  that odoo-helper script will automaticaly fetch branch named as server version in current install,
# if another branch was not specified
odoo-helper fetch --oca project-service -m project_sla

# and run tests for it
odoo-helper test --create-test-db -m project_sla


# also if you want to install python packages in current installation environment, you may use command:
odoo-helper fetch -p suds  # this installs 'suds' python package

# and as one more example, let's install aeroo-reports with dependancy to aeroolib in odoo 7.0
cd ../odoo-7.0
odoo-helper fetch --github gisce/aeroo -n aeroo
odoo-helper fetch -p git+https://github.com/jamotion/aeroolib#egg=aeroolib

# got back to test root and install odoo version 9.0
cd ../;
odoo-install --install-dir odoo-9.0 --branch 9.0 --extra-utils
cd odoo-9.0;
odoo-helper server --stop-after-init;  # test that it runs

