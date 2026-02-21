#!/bin/bash

# Copyright © 2016-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# this script runs tests for Odoo 11.0–18.0 (Python 3)

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
=================================
Install and check Odoo 11.0 (Py3)
=================================
${NC}"

# Already in $TEST_TMP_DIR from init block above
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

echo -e "${YELLOWC}Print path to virtualenv directory of odoo 11.0 project:${NC}";
odoo-helper system get-venv-dir ../odoo-11.0;

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


echo -e "${YELLOWC}
#=================================
#Install and check Odoo 17.0 (Py3)
#=================================
${NC}"

cd ../;

# Remove odoo 16
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-16.0

# Install odoo 17
odoo-helper install sys-deps -y 17.0;

odoo-install --install-dir odoo-17.0 --odoo-version 17.0 \
    --http-port 17569 \
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
#=================================
#Install and check Odoo 18.0 (Py3)
#=================================
${NC}"

cd ../;

# Remove odoo 17
# this is needed to bypass gitlab.com limitation of disk space for CI jobs
rm -rf ./odoo-17.0

# Install odoo 18
odoo-helper install sys-deps -y 18.0;

odoo-install --install-dir odoo-18.0 --odoo-version 18.0 \
    --http-port 18069 \
    --db-user odoo18 --db-pass odoo --create-db-user \
    --build-python-if-needed

cd odoo-18.0;

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
odoo-helper db drop odoo18-odoo-test;



echo -e "${YELLOWC}
=============================================================
Run 'prepare-docs' script to test generation of help messages
=============================================================
${NC}"

bash "$PROJECT_DIR/scripts/prepare_docs.bash";

echo -e "${GREENC}
==========================================
Tests finished (py3: Odoo 11–18)
==========================================
${NC}"
