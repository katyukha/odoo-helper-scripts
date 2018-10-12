#!/bin/bash

# Copyright © 2016-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# this script run's basic tests

SCRIPT=$0;
SCRIPT_NAME=$(basename $SCRIPT);
PROJECT_DIR=$(readlink -f "$(dirname $SCRIPT)/..");
TEST_TMP_DIR="${TEST_TMP_DIR:-$PROJECT_DIR/test-temp}";
WORK_DIR=$(pwd);

ERROR=;

tempfiles=( )

# do cleanup on exit
cleanup() {
  if [ -z $ERROR ]; then
      if ! rm -rf "$TEST_TMP_DIR"; then
          echo "Cannot remove $TEST_TMP_DIR";
      fi
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
source "$PROJECT_DIR/tests/ci.bash";

# import odoo-helper common lib to allow colors in test output
source $(odoo-helper system lib-path common);
allow_colors;

#
# Start test
# ==========
#
echo -e "${YELLOWC}
===================================================
Show odoo-helper-scripts version
===================================================
${NC}"
odoo-helper --version;


echo -e "${YELLOWC}
===================================================
Install odoo-helper and odoo system prerequirements
===================================================
${NC}"

odoo-helper install pre-requirements -y;
odoo-helper install bin-tools -y;
odoo-helper install postgres;

if [ ! -z $CI_RUN ] && ! odoo-helper exec postgres_test_connection; then
    echo -e "${YELLOWC}WARNING${NC}: Cannot connect to postgres instance. Seems that postgres not started, trying to start it now..."
    sudo /etc/init.d/postgresql start;
fi


echo -e "${YELLOWC}
===================================================
Run odoo-helper postgres speedify
===================================================
${NC}"
odoo-helper postgres speedify

echo -e "${YELLOWC}
==================================================
Test install of odoo version 7.0
Also install dependencies and configure postgresql
==================================================
${NC}"

# Install system dependencies for odoo version 7.0
odoo-helper install sys-deps -y 7.0;

# Install postgres and create there user with name='odoo' and password='odoo'
odoo-helper install postgres odoo7 odoo

# Install odoo 7.0
odoo-install -i odoo-7.0 --odoo-version 7.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 \
    --db-user odoo7 --db-pass odoo
cd odoo-7.0

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

# Now You will have odoo-7.0 installed in this directory.
# Note, thant Odoo this odoo install uses virtual env (venv dir)
# Also You will find there odoo-helper.conf config file

echo -e "${YELLOWC}
=================================
Test 'odoo-helper server' command
=================================
${NC}"
# So now You may run local odoo server (i.e openerp-server script).
# Note that this command run's server in foreground.
odoo-helper server --stop-after-init  # This will automaticaly use config file: conf/odoo.conf

# Also you may run server in background using
odoo-helper server start

# there are also few additional server related commands:
odoo-helper server status

# list odoo processes
odoo-helper server ps

# odoo-helper server log    # note that this option runs less, so blocks for input
odoo-helper server restart
odoo-helper server stop
odoo-helper server status

# The one cool thing of odoo-helper script is that you may not remeber paths to odoo instalation,
# and if you change directory to another inside your odoo project, everything will continue to work.
cd custom_addons
odoo-helper server status
odoo-helper server restart
odoo-helper server stop
odoo-helper server status


echo -e "${YELLOWC}
============================================================
Fetch and test 'https://github.com/katyukha/base_tags' addon
============================================================
${NC}"
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
cd ../repositories
odoo-helper --use-unbuffer test --create-test-db -d ./base_tags
# So... let's install one more odoo version
# go back to directory containing our projects (that one, where odoo-7.0 project is placed)
cd ../../

echo -e "${YELLOWC}
========================================================================
Install odoo 8.0, fetch and run tests for OCA addon 'project_sla'
Also install python package 'suds' in virtual env of this odoo instance
========================================================================
${NC}"
# Let's install odoo of version 8.0 too here.
odoo-helper install sys-deps -y 8.0;
odoo-helper postgres user-create odoo8 odoo
odoo-install --install-dir odoo-8.0 --odoo-version 8.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo8 --db-pass odoo

cd odoo-8.0

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

# and install there for example addon 'project_sla' for 'project-service' Odoo Comutinty repository
# Note  that odoo-helper script will automaticaly fetch branch named as server version in current install,
# if another branch was not specified
odoo-helper fetch --oca project -m project_sla

# create test database
odoo-helper db create --demo odoo8-odoo-test

# and run tests for it
odoo-helper test -m project_sla

# Install py-tools to get coverage reports
odoo-helper install py-tools

# or run tests with test-coverage enabled
(cd ./repositories/project; odoo-helper test --coverage-report -m project_sla || true);

# Also we may generate html coverage report too
(cd ./repositories/project; odoo-helper test --coverage-html -m project_sla || true);


# also if you want to install python packages in current installation environment, you may use command:
odoo-helper fetch -p suds  # this installs 'suds' python package

# Show addons status for this project
odoo-helper --use-unbuffer addons status

# Or check for updates of addons
odoo-helper --use-unbuffer addons check-updates

echo -e "${YELLOWC}
===============================================================================
Go back to Odoo 7.0 instance, we installed at start of test
and fetch and install there aeroo reports addon with it's dependency 'aeroolib'
After this, generate requirements list.
===============================================================================
${NC}"

# and as one more example, let's install aeroo-reports with dependancy to aeroolib in odoo 7.0
cd ../odoo-7.0
odoo-helper fetch --github gisce/aeroo -n aeroo
odoo-helper fetch -p git+https://github.com/jamotion/aeroolib#egg=aeroolib
odoo-helper generate_requirements

echo -e "${YELLOWC}
==========================
Install and check Odoo 9.0 
==========================
${NC}"

# got back to test root and install odoo version 9.0 (clonning it)
cd ../;
odoo-helper install sys-deps -y 9.0;
odoo-helper postgres user-create odoo9 odoo;
odoo-install --install-dir odoo-9.0 --odoo-version 9.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo9 --db-pass odoo --download-archive off --single-branch on

cd odoo-9.0;

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

odoo-helper server --stop-after-init;  # test that it runs

# Update odoo source code (here odoo source is under git)
odoo-helper server auto-update

# Create odoo 9 database
odoo-helper db create test-9-db;

# Clone addon from Mercurial repo (Note it is required Mercurial to be installed)
odoo-helper pip install Mercurial;
odoo-helper fetch --hg https://bitbucket.org/anybox/bus_enhanced/ --branch 9.0
odoo-helper addons list ./custom_addons;  # list addons available to odoo
odoo-helper addons list --help;
odoo-helper addons list --recursive ./custom_addons;
odoo-helper addons list --installable ./custom_addons;
odoo-helper addons list --color --recursive ./repositories;
odoo-helper addons update-list --help;
odoo-helper addons update-list;
odoo-helper addons install bus_enhanced;
odoo-helper addons test-installed bus_enhanced;  # find databases where this addons is installed
odoo-helper addons update -m bus_enhanced;
odoo-helper addons uninstall bus_enhanced;

# uninstall addon that is not installed
odoo-helper addons uninstall account;

# uninstall all addons (error)
odoo-helper addons uninstall all || true;

# Update python dependencies of addons
odoo-helper addons update-py-deps

# List addon repositories
odoo-helper addons list-repos;

# List addons without repositories
odoo-helper addons list-no-repo;

# Generate requirements
odoo-helper addons generate-requirements;

# Reinstall odoo downloading archive
odoo-helper install reinstall-odoo download;

# Drop created database
odoo-helper db drop test-9-db;

# Show project status
odoo-helper status

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions


echo -e "${YELLOWC}
=================================
Test database management features
(create, list, and drop database)
=================================
${NC}"

# create test database if it does not exists yet
if ! odoo-helper db exists my-test-odoo-database; then
    odoo-helper db create my-test-odoo-database;
fi

# list all odoo databases available for this odoo instance
odoo-helper db list

# backup database
backup_file=$(odoo-helper db backup my-test-odoo-database zip);

# Also it is possible to backup SQL only (without filesystem)
backup_file_sql=$(odoo-helper db backup my-test-odoo-database sql);

# drop test database if it exists
if odoo-helper db exists my-test-odoo-database; then
    odoo-helper db drop my-test-odoo-database;
fi

# restore dropped database
odoo-helper db restore my-test-odoo-database $backup_file;

# ensure that database exists
odoo-helper db exists my-test-odoo-database

# rename database to my-test-db-renamed
odoo-helper db rename my-test-odoo-database my-test-db-renamed

# Run psql and list all databases visible for odoo user
# This command will automaticaly pass connection params from odoo config
odoo-helper postgres psql -c "\l"

# recompute parent-store for ir.ui.menu
odoo-helper odoo recompute --dbname my-test-db-renamed -m ir.ui.menu --parent-store

# recompute 'web_icon_data' field on ir.ui.menu
odoo-helper odoo recompute --dbname my-test-db-renamed -m ir.ui.menu -f web_icon_data


# drop database egain
odoo-helper db drop my-test-db-renamed;


echo -e "${YELLOWC}
===========================
Install and check Odoo 10.0
===========================
${NC}"

# got back to test root and install odoo version 9.0
cd ../;
odoo-helper install sys-deps -y 10.0;
odoo-helper postgres user-create odoo10 odoo;
odoo-install --install-dir odoo-10.0 --odoo-version 10.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo10 --db-pass odoo

cd odoo-10.0;

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

odoo-helper server --stop-after-init;  # test that it runs

# Also in odoo 10 it is possible to install addons via pip.
# For example there are some OCA addons available for such install
# Let's install for example mis-builder.
# odoo-helper will automaticaly set correct pypi indexx or findlinks option
# for pip, if it is called with this command.
odoo-helper pip install odoo10-addon-mis-builder;

# Also there is odoo-helper npm command
odoo-helper npm help

# Install extra js tools
odoo-helper install js-tools;


# Install oca/partner-contact addons
odoo-helper fetch --oca partner-contact;

# Regenerate Ukrainian translations for partner_firstname addons
odoo-helper tr regenerate --lang uk_UA --file uk_UA partner_firstname;
odoo-helper tr rate --lang uk_UA partner_firstname;

# Check partner_first_name addon with pylint and flake8
odoo-helper install py-tools
odoo-helper pylint ./repositories/partner-contact/partner_firstname || true;
odoo-helper flake8 ./repositories/partner-contact/partner_firstname || true;

# Show project status
odoo-helper status

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions

# Print odoo helper configuration
odoo-helper print-config

# Update odoo source code (here odoo source is archive)
odoo-helper server auto-update

# Pull odoo addons update
odoo-helper addons pull-updates

# Update odoo base addon
odoo-helper addons update base

# Fetch OCA account-financial-reporting, which seems to have
# complicated enough dependencies for this test
odoo-helper fetch --oca account-financial-reporting

# Clone repository explicitly and link it
(cd repositories && \
    git clone -b 10.0 https://github.com/OCA/contract && \
    odoo-helper addons list --color contract && \
    odoo-helper link contract && \
    odoo-helper addons list --color contract)

# Update addons list
odoo-helper addons update-list


# Generate requirements and fetch them again
odoo-helper addons generate-requirements > /tmp/odoo-requirements.txt
odoo-helper fetch --requirements /tmp/odoo-requirements.txt

# Try to reinstall virtualenv and run server
odoo-helper install reinstall-venv;
odoo-helper server status
odoo-helper start
odoo-helper status
odoo-helper server status
odoo-helper stop

# Test doc-utils. List all addons available in *contract* addon
odoo-helper doc-utils addons-list --sys-name -f name -f version -f summary -f application --git-repo ./repositories/contract

# Same but in CSV format
odoo-helper doc-utils addons-list --sys-name -f name -f version -f summary -f application --git-repo --format csv ./repositories/contract


echo -e "${YELLOWC}
=================================
Install and check Odoo 11.0 (Py3)
=================================
${NC}"

cd ../;
odoo-helper install sys-deps -y 11.0;
odoo-helper postgres user-create odoo11 odoo;
odoo-install --install-dir odoo-11.0 --odoo-version 11.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo11 --db-pass odoo

cd odoo-11.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

# Test python version
echo -e "${YELLOWC}Ensure that it is Py3${NC}";
odoo-helper exec python --version
if ! [[ "$(odoo-helper exec python --version 2>&1)" == "Python 3."* ]]; then
    echo -e "${REDC}FAIL${NC}: No py3";
    exit 3;
fi

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status
odoo-helper start
odoo-helper server ps
odoo-helper server status
odoo-helper stop

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions

echo -e "${YELLOWC}
==========================================
Test how translation-related commands work
==========================================
${NC}"
odoo-helper db create --demo test-11-db;
odoo-helper tr load --lang uk_UA --db test-11-db;
odoo-helper tr export test-11-db uk_UA uk-test web;
odoo-helper tr import test-11-db uk_UA uk-test web;

# Install oca/partner-contact addons
odoo-helper fetch --oca partner-contact;

# Regenerate Ukrainian translations for all addons in partner-contact
odoo-helper tr regenerate --lang uk_UA --file uk_UA --dir ./repositories/partner-contact;
odoo-helper tr rate --lang uk_UA --dir ./repositories/partner-contact;

# Update addons list on specific db
odoo-helper addons update-list test-11-db


echo -e "${YELLOWC}
==========================================
Show list of running sql queries
==========================================
${NC}"
odoo-helper server start
odoo-helper db list
odoo-helper postgres stat-activity
odoo-helper postgres stat-connections
odoo-helper stop


echo -e "${YELLOWC}
==========================================
Drop temporary database
==========================================
${NC}"
odoo-helper db drop test-11-db;


echo -e "${YELLOWC}
==========================================
Test shortcuts
==========================================
${NC}"

odoo-helper --help
odoo-install --help
odoo-helper-addons --help
odoo-helper-db --help
odoo-helper-fetch --help
odoo-helper-server --help
odoo-helper-test --help
odoo-helper git --help
odoo-helper-restart
odoo-helper stop # ensure server stopped

# There is also shortcut for odoo.py command
odoo-helper odoo-py --help


echo -e "${YELLOWC}
==========================================
Test Unitilty commands
==========================================
${NC}"

echo -e "${YELLOWC}Print server url:${NC}";
odoo-helper odoo server-url

# Check that specified directory is inside odoo-helper project
odoo-helper system is-project ./repositories;

echo -e "${YELLOWC}Print path to virtualenv directory of current odoo-helper project:${NC}";
odoo-helper system get-venv-dir;

echo -e "${YELLOWC}Print path to virtualenv directory of odoo 10.0 project:${NC}";
odoo-helper system get-venv-dir ../odoo-10.0;

echo -e "${YELLOWC}
==========================================
Test stylelint on OCA/website repo
==========================================
${NC}"

odoo-helper install js-tools
odoo-helper fetch --oca web
odoo-helper lint style ./repositories/web/web_widget_color || true
odoo-helper lint style ./repositories/web/web_widget_datepicker_options || true


echo -e "${GREENC}
==========================================
Tests finished
==========================================
${NC}"

echo -e "${YELLOWC}
=================================
Install and check Odoo 12.0 (Py3)
=================================
${NC}"

cd ../;
odoo-helper install sys-deps -y 12.0;
odoo-helper postgres user-create odoo12 odoo;
odoo-install --install-dir odoo-12.0 --odoo-version 12.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo12 --db-pass odoo

cd odoo-12.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

# Test python version
echo -e "${YELLOWC}Ensure that it is Py3${NC}";
odoo-helper exec python --version
if ! [[ "$(odoo-helper exec python --version 2>&1)" == "Python 3."* ]]; then
    echo -e "${REDC}FAIL${NC}: No py3";
    exit 3;
fi

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status
odoo-helper server status
odoo-helper start
odoo-helper ps
odoo-helper status
odoo-helper server status
odoo-helper stop

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions
