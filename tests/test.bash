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

# Check if db has demo-data
odoo-helper db is-demo odoo8-odoo-test

# Check if db has demo-data, but database does not exists
odoo-helper db is-demo unexisting-database || true

# and run tests for it
odoo-helper test -m project_sla

# Install py-tools to get coverage reports
odoo-helper install py-tools

# or run tests with test-coverage enabled
(cd ./repositories/oca/project; odoo-helper test --recreate-db --coverage-report project_sla || true);

# Also it is possible to fail if test coverage less than specified value
(cd ./repositories/oca/project; odoo-helper test --recreate-db --coverage-fail-under 50 project_sla || true);

# Also we may generate html coverage report too
(cd ./repositories/oca/project; odoo-helper test --create-test-db --coverage-html --dir . --skip project_sla || true);

# Skip all addons that starts with project
(cd ./repositories/oca/project; odoo-helper test --create-test-db --coverage-html --dir . --skip-re "^project_" || true);

# Show addons status for this project
odoo-helper --use-unbuffer addons status

# Or check for updates of addons
odoo-helper --use-unbuffer addons check-updates


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
    --db-user odoo9 --db-pass odoo

cd odoo-9.0;

echo "";
echo "Generated odoo config:"
echo "$(cat ./conf/odoo.conf)"
echo "";

odoo-helper server --stop-after-init;  # test that it runs

# Create odoo 9 database
odoo-helper db create test-9-db;

# Ensure database does not have demo-data installed
! odoo-helper db is-demo test-9-db;
! odoo-helper db is-demo -q test-9-db;

odoo-helper addons list ./custom_addons;  # list addons available to odoo
odoo-helper addons list --help;
odoo-helper addons list --recursive ./custom_addons;
odoo-helper addons list --installable ./custom_addons;
odoo-helper addons list --color --recursive ./repositories;
odoo-helper --no-colors addons list --color --recursive ./repositories;
odoo-helper addons list --not-linked --recursive ./repositories;
odoo-helper addons list --linked --recursive ./repositories;
odoo-helper addons list --by-path ./repositories;
(cd repositories && odoo-helper addons list --recursive);
odoo-helper addons update-list --help;
odoo-helper addons update-list;
odoo-helper start;
odoo-helper stop;

# uninstall addon that is not installed
odoo-helper addons uninstall account;

# uninstall all addons (error)
odoo-helper addons uninstall all || true;

# List addon repositories
odoo-helper addons list-repos;

# List addons without repositories
odoo-helper addons list-no-repo;

# Generate requirements
odoo-helper addons generate-requirements;

# Generate requirements (shortcut)
odoo-helper generate-requirements;

# Update odoo sources
odoo-helper update-odoo

# Reinstall odoo downloading archive
odoo-helper install reinstall-odoo download;

# Remove created backup of previous odoo code
rm -rf ./odoo-backup-*;

# Reinstall python dependencies for Odoo
odoo-helper install py-deps

# Drop created database
odoo-helper db drop test-9-db;

# Show project status
odoo-helper status

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions

# Install dev tools
odoo-helper install dev-tools

# Install unoconv
odoo-helper install unoconv

# Install openupgradelib
odoo-helper install openupgradelib

# And show odoo-helper status after tools installed
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
backup_file=$(odoo-helper db backup --format zip my-test-odoo-database);

# Also it is possible to backup SQL only (without filesystem)
backup_file_sql=$(odoo-helper db backup --format sql my-test-odoo-database);

# drop test database if it exists
if odoo-helper db exists my-test-odoo-database; then
    odoo-helper db drop my-test-odoo-database;
fi

# restore dropped database
odoo-helper db restore my-test-odoo-database "$backup_file";

# ensure that database exists
odoo-helper db exists my-test-odoo-database

# rename database to my-test-db-renamed
odoo-helper db rename my-test-odoo-database my-test-db-renamed

# Run psql and list all databases visible for odoo user
# This command will automaticaly pass connection params from odoo config
odoo-helper postgres psql -c "\l"

# Run psql and list all databases visible for odoo user (shortcut)
odoo-helper psql -c "\l"

# Show running queries
odoo-helper pg stat-activity

# Show active locks
odoo-helper pg locks-info

# Show connections info
odoo-helper pg stat-connections

# recompute parent-store for ir.ui.menu
odoo-helper odoo recompute --dbname my-test-db-renamed -m ir.ui.menu --parent-store

# recompute menus (parent-store values)
odoo-helper odoo recompute-menu --dbname my-test-db-renamed

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

# Remove odoo 8 and odoo 9,
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-8.0
rm -rf ./odoo-9.0

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
odoo-helper fetch --git-single-branch --oca partner-contact;

# Regenerate Ukrainian translations for partner_firstname addons
odoo-helper tr regenerate --lang uk_UA --file uk_UA partner_firstname;
odoo-helper tr rate --lang uk_UA partner_firstname;

# Check partner_first_name addon with pylint and flake8
odoo-helper install py-tools
odoo-helper pylint ./repositories/oca/partner-contact/partner_firstname || true;
odoo-helper flake8 ./repositories/oca/partner-contact/partner_firstname || true;
odoo-helper addons list --filter "first" ./repositories/oca/partner-contact
odoo-helper addons list --except-filter "first" ./repositories/oca/partner-contact

# Show project status
odoo-helper status

# Update odoo-sources
odoo-helper update-odoo

# Clean up odoo backups dir
rm -rf ./backups/*;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions

# Print odoo helper configuration
odoo-helper print-config

# Pull odoo addons update
(cd ./repositories/oca/partner-contact && git reset --hard HEAD^^^1)
odoo-helper addons pull-updates

# Update odoo base addon
odoo-helper-addons-update base

# Fetch OCA account-financial-reporting, which seems to have
# complicated enough dependencies for this test
odoo-helper fetch --git-single-branch --oca account-financial-reporting

# Clone repository explicitly and link it
(cd repositories && \
    git clone -b 10.0 https://github.com/OCA/contract && \
    odoo-helper addons list --color contract && \
    odoo-helper link --ual contract && \
    odoo-helper addons list --color contract)

# Update addons list
odoo-helper addons update-list


# Generate requirements and fetch them again
odoo-helper addons generate-requirements > /tmp/odoo-requirements.txt
odoo-helper fetch --git-single-branch --requirements /tmp/odoo-requirements.txt

# Try to reinstall virtualenv and run server
odoo-helper install reinstall-venv;
odoo-helper server status
odoo-helper start
odoo-helper status
odoo-helper server status
odoo-helper stop

# Update python dependencies of addons
odoo-helper addons update-py-deps

# Test doc-utils. List all addons available in *contract* addon
odoo-helper doc-utils addons-list --sys-name -f name -f version -f summary -f application --git-repo ./repositories/contract

# Same but in CSV format and with list of dependencies
odoo-helper doc-utils addons-list --sys-name -f name -f version --dependencies -f summary -f application --git-repo --format csv ./repositories/contract


echo -e "${YELLOWC}
=================================
Install and check Odoo 11.0 (Py3)
=================================
${NC}"

cd ../;
odoo-helper install sys-deps -y 11.0;
odoo-helper postgres user-create odoo11 odoo;


# Odoo 11 does not run on python 3.9, so build custom python interpreter
odoo-install --install-dir odoo-11.0 --odoo-version 11.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo11 --db-pass odoo --build-python-if-needed

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

echo -e "${YELLOWC}
==============================
Fetch OCA/partner-contact repo
==============================
${NC}"
# Install oca/partner-contact addons
odoo-helper fetch --oca partner-contact;

echo -e "${YELLOWC}
===================================================================
Test CI Tools (ensure icons, ensure changelog, check versions, etc)
===================================================================
${NC}"
# Check oca/partner-contact with ci commands
odoo-helper ci ensure-icons repositories/oca/partner-contact || true
odoo-helper ci ensure-changelog repositories/oca/partner-contact HEAD^^^1 || true
odoo-helper ci ensure-changelog --ignore-trans repositories/oca/partner-contact HEAD^^^1 || true
odoo-helper ci check-versions-git --repo-version repositories/oca/partner-contact HEAD^^^1 HEAD || true
odoo-helper ci check-versions-git --repo-version repositories/oca/partner-contact HEAD^^^1 || true
odoo-helper ci check-versions-git --ignore-trans --repo-version repositories/oca/partner-contact HEAD^^^1 || true

echo -e "${YELLOWC}
===================================
Show list of changed addons in repo
===================================
${NC}"
# Show addons changed
odoo-helper git changed-addons repositories/oca/partner-contact HEAD^^^1 HEAD

echo -e "${YELLOWC}
==================
Fetch OCA/web repo
==================
${NC}"
# Fetch oca/web passing only repo url and branch to fetch command
odoo-helper fetch https://github.com/oca/web --branch 11.0 --git-single-branch --git-depth-1;

echo -e "${YELLOWC}
============================================
Update list of addons for specific databases
============================================
${NC}"
# Update addons list on specific db
odoo-helper addons update-list test-11-db

echo -e "${YELLOWC}
===========================================================================
Regenerate UA translations for partner-contact and compute translation rate
===========================================================================
${NC}"
# Regenerate Ukrainian translations for all addons in partner-contact
odoo-helper tr regenerate --lang uk_UA --file uk_UA --dir ./repositories/oca/web;
odoo-helper tr rate --lang uk_UA --dir ./repositories/oca/web;


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
odoo-helper-link --help
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
odoo-helper lint style ./repositories/oca/web/web_widget_color || true
odoo-helper lint style ./repositories/oca/web/web_widget_datepicker_options || true


echo -e "${YELLOWC}
=================================
Install and check Odoo 12.0 (Py3)
=================================
${NC}"

cd ../;
odoo-helper install sys-deps -y 12.0;
odoo-helper postgres user-create odoo12 odoo;

# Odoo 12 does not run on python 3.9, so build custom python interpreter
odoo-install --install-dir odoo-12.0 --odoo-version 12.0 \
    --conf-opt-xmlrpc_port 8369 --conf-opt-xmlrpcs_port 8371 --conf-opt-longpolling_port 8372 \
    --db-user odoo12 --db-pass odoo --ocb --build-python-if-needed

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
echo "Generated odoo config:";
echo "$(cat ./conf/odoo.conf)";
echo "";

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status;
odoo-helper-server status;
odoo-helper start;
odoo-helper ps;
odoo-helper status;
odoo-helper server status;
odoo-helper stop;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions;

# Database management
odoo-helper db create --demo --lang en_US odoo12-odoo-test;
odoo-helper db create --recreate --demo --lang en_US --install contacts odoo12-odoo-test;
odoo-helper db copy odoo12-odoo-test odoo12-odoo-tmp;
odoo-helper db exists odoo12-odoo-test;
odoo-helper db exists odoo12-odoo-tmp;
odoo-helper db backup-all;
odoo-helper db dump-manifest odoo12-odoo-test;
odoo-helper lsd;  # list databases

# Fetch oca/contract
odoo-helper fetch --github crnd-inc/generic-addons

# Install addons from OCA contract
odoo-helper addons install --ual --dir ./repositories/crnd-inc/generic-addons;

# List addons in generic_addons
odoo-helper lsa ./repositories/crnd-inc/generic-addons;

# Install poppler utils package, that is required by bureaucrat knowledge base
sudo apt-get install -qqy poppler-utils

# Fetch bureaucrat_knowledge from Odoo market and try to install it
odoo-helper fetch --odoo-app bureaucrat_knowledge;
odoo-helper addons install --ual --show-log-on-error bureaucrat_knowledge;

# Fetch knowledge base second time testing bechavior
# when same addons already present in system
odoo-helper-fetch --odoo-app bureaucrat_knowledge;

# Prepare to test pull updates with --do-update option
(cd ./repositories/crnd-inc/generic-addons && git reset --hard HEAD^^^1);

# Test pull-updates with --do-update option
odoo-helper-addons pull-updates --do-update;

# Regenerate pot files for modules from generic-addons
odoo-helper tr regenerate --pot --dir ./repositories/crnd-inc/generic-addons;
odoo-helper tr regenerate --lang-file "uk_UA:uk" --lang-file "ru_RU:ru" --dir ./repositories/crnd-inc/generic-addons;

# Print list of installed addons
odoo-helper addons find-installed;

# Drop created databases
odoo-helper-db drop odoo12-odoo-test;
odoo-helper db drop -q odoo12-odoo-tmp;

cd ../;


# Remove odoo 10, 11, 12,
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-10.0
rm -rf ./odoo-11.0
rm -rf ./odoo-12.0

echo -e "${YELLOWC}
=================================
Install and check Odoo 13.0 (Py3)
=================================
${NC}"

# Install odoo 13
odoo-helper install sys-deps -y 13.0;
odoo-helper postgres user-create odoo13 odoo;

# System python is less than 3.6 or greater than 3.9,
# so build python 3.7 to use for this odoo version
odoo-install --install-dir odoo-13.0 --odoo-version 13.0 \
    --http-port 8469 --http-host local-odoo-13 \
    --db-user odoo13 --db-pass odoo --build-python-if-needed

cd odoo-13.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status;
odoo-helper server status;
odoo-helper start;
odoo-helper ps;
odoo-helper status;
odoo-helper server status;
odoo-helper stop;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions;

# Database management
odoo-helper db create --demo --lang en_US odoo13-odoo-test;

# Fetch oca/contract
odoo-helper fetch --github crnd-inc/generic-addons

# Install addons from OCA contract
odoo-helper addons install --ual --dir ./repositories/crnd-inc/generic-addons;

# Fetch bureaucrat_knowledge from Odoo market and try to install it
odoo-helper fetch --odoo-app bureaucrat_knowledge;
odoo-helper addons install --ual bureaucrat_knowledge;

# Print list of installed addons
odoo-helper addons find-installed --packager-format;

# Drop created databases
odoo-helper db drop odoo13-odoo-test;


# Odoo 14 runs only with python 3.6+
echo -e "${YELLOWC}
=================================
Install and check Odoo 14.0 (Py3)
=================================
${NC}"

cd ../;
odoo-helper install sys-deps -y 14.0;

# System python is less then 3.6, so build python 3.7 to use for
# this odoo version
odoo-install --install-dir odoo-14.0 --odoo-version 14.0 \
    --http-port 8569 --http-host local-odoo-14 \
    --db-user odoo14 --db-pass odoo --create-db-user \
    --build-python-if-needed

cd odoo-14.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status;
odoo-helper server status;
odoo-helper start;
odoo-helper ps;
odoo-helper status;
odoo-helper server status;
odoo-helper stop;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions;

# Database management
odoo-helper db create --demo --lang en_US odoo14-odoo-test;

# Fetch oca/contract
odoo-helper fetch --github crnd-inc/generic-addons

# Install addons from OCA contract
odoo-helper addons install --ual --dir ./repositories/crnd-inc/generic-addons;

# Fetch bureaucrat_knowledge from Odoo market and try to install it
odoo-helper fetch --odoo-app bureaucrat_knowledge;
odoo-helper addons install --ual bureaucrat_knowledge;

# Print list of installed addons
odoo-helper addons find-installed;

# Drop created databases
odoo-helper db drop odoo14-odoo-test;


echo -e "${YELLOWC}
=================================
Install and check Odoo 15.0 (Py3)
=================================
${NC}"

cd ../;

# Remove odoo 13, 14,
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-13.0
rm -rf ./odoo-14.0

# Install odoo 15
odoo-helper install sys-deps -y 15.0;


# System python is less then 3.7, so build python 3.7 to use for
# this odoo version
odoo-install --install-dir odoo-15.0 --odoo-version 15.0 \
    --http-port 8569 --http-host local-odoo-15 \
    --db-user odoo15 --db-pass odoo --create-db-user \
    --build-python-if-needed

cd odoo-15.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status;
odoo-helper server status;
odoo-helper start;
odoo-helper ps;
odoo-helper status;
odoo-helper server status;
odoo-helper stop;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions;

# Database management
odoo-helper db create --tdb --lang en_US;

odoo-helper addons update-list --tdb;
odoo-helper addons install --tdb --module crm;
odoo-helper addons test-installed crm;

odoo-helper lsd;  # List databases

## Install addon website via 'odoo-helper install'
odoo-helper install website;

## Fetch oca/contract
odoo-helper fetch --github crnd-inc/generic-addons

## Install addons from OCA contract
odoo-helper addons install --ual --dir ./repositories/crnd-inc/generic-addons;

## Fetch bureaucrat_knowledge from Odoo market and try to install it
odoo-helper fetch --odoo-app bureaucrat_knowledge;
odoo-helper addons install --ual bureaucrat_knowledge;

## Print list of installed addons
odoo-helper addons find-installed;

## Run tests for knowledge
odoo-helper test bureaucrat_knowledge

# Drop created databases
odoo-helper db drop odoo15-odoo-test;

echo -e "${YELLOWC}
=================================
Install and check Odoo 16.0 (Py3)
=================================
${NC}"

cd ../;

# Remove odoo 15
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-15.0

# Install odoo 16
odoo-helper install sys-deps -y 16.0;

odoo-install --install-dir odoo-16.0 --odoo-version 16.0 \
    --http-port 8569 --http-host local-odoo-16 \
    --db-user odoo16 --db-pass odoo --create-db-user \
    --build-python-if-needed

cd odoo-16.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status;
odoo-helper server status;
odoo-helper start;
odoo-helper ps;
odoo-helper status;
odoo-helper server status;
odoo-helper stop;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions;

# Database management
odoo-helper db create --tdb --lang en_US;

odoo-helper addons update-list --tdb;
odoo-helper addons install --tdb --module crm;
odoo-helper addons test-installed crm;

odoo-helper lsd;  # List databases

## Install addon website via 'odoo-helper install'
odoo-helper install website;

## Fetch oca/contract
odoo-helper fetch --github crnd-inc/generic-addons

## Fetch bureaucrat_knowledge from Odoo market and try to install it
odoo-helper fetch --odoo-app bureaucrat_knowledge;
odoo-helper addons install --ual bureaucrat_knowledge;

## Print list of installed addons
odoo-helper addons find-installed;

## Run tests for helpdesk lite
odoo-helper test bureaucrat_knowledge

# Drop created databases
odoo-helper db drop odoo16-odoo-test;


#echo -e "${YELLOWC}
#=================================
#Install and check Odoo 17.0 (Py3)
#=================================
#${NC}"

cd ../;

# Remove odoo 17
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-16.0

# Install odoo 17
odoo-helper install sys-deps -y 17.0;

odoo-install --install-dir odoo-17.0 --odoo-version 17.0 \
    --http-port 8569 --http-host local-odoo-17 \
    --db-user odoo17 --db-pass odoo --create-db-user \
    --build-python-if-needed

cd odoo-17.0;

# Install py-tools and js-tools
odoo-helper install py-tools;
odoo-helper install js-tools;

odoo-helper server run --stop-after-init;  # test that it runs

# Show project status
odoo-helper status;
odoo-helper server status;
odoo-helper start;
odoo-helper ps;
odoo-helper status;
odoo-helper server status;
odoo-helper stop;

# Show complete odoo-helper status
odoo-helper status  --tools-versions --ci-tools-versions;

# Database management
odoo-helper db create --tdb --lang en_US;

odoo-helper addons update-list --tdb;
odoo-helper addons install --tdb --module crm;
odoo-helper addons test-installed crm;

odoo-helper lsd;  # List databases

## Install addon website via 'odoo-helper install'
odoo-helper install website;

# Drop created databases
odoo-helper db drop odoo17-odoo-test;


echo -e "${YELLOWC}
=============================================================
Run 'prepare-docs' script to test generation of help messages
=============================================================
${NC}"

bash "$PROJECT_DIR/scripts/prepare_docs.bash";

echo -e "${GREENC}
==========================================
Tests finished
==========================================
${NC}"

