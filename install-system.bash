#!/bin/bash

# Copyright © 2015-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# Define colors
NC='\e[0m';
REDC='\e[31m';
GREENC='\e[32m';
YELLOWC='\e[33m';
BLUEC='\e[34m';
LBLUEC='\e[94m';

# Simple script to install odoo-helper-script system-wide
if [[ $UID != 0 ]]; then
    echo -e "${REDC}ERROR${NC}: Please run this script with ${YELLOWC}sudo${NC}:"
    echo -e "$ ${BLUEC}sudo $0 $* ${NC}"
    exit 1
fi

# Get odoo-helper branch. Default is master
ODOO_HELPER_BRANCH=${1:-master}

set -e;  # Fail on each error

# Install git if not installed yet
if ! command -v git >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
    if [ -e "/etc/debian_version" ]; then
        echo -e "${BLUEC}INFO${NC}: Installing minimal system dependencies...${NC}";
        apt-get install -yqq --no-install-recommends git wget;
    else
        echo -e "${REDC}ERROR${NC}: Please, install wget and git to be able to install odoo-helper-scripts!"
        exit 2;
    fi
fi

# define vars
ODOO_HELPER_SYS_CONF="/etc/odoo-helper.conf";

# Test if there is odoo-helper conf in home dir, which means
# that odoo-helper-scripts may be already installed
if [ -f "$ODOO_HELPER_SYS_CONF" ]; then
    source $ODOO_HELPER_SYS_CONF;
fi

# Configure paths
INSTALL_PATH=${ODOO_HELPER_INSTALL_PATH:-/opt/odoo-helper-scripts};
ODOO_HELPER_LIB=${ODOO_HELPER_LIB:-$INSTALL_PATH/lib};
ODOO_HELPER_BIN=${ODOO_HELPER_BIN:-$INSTALL_PATH/bin};

# clone repo
if [ ! -d $INSTALL_PATH ]; then
    echo -e "${BLUEC}INFO${NC}: clonning odoo-helper-scripts...${NC}";
    git clone --recurse-submodules -q https://gitlab.com/katyukha/odoo-helper-scripts $INSTALL_PATH;
    echo -e "${BLUEC}INFO${NC}: fetching submodules...${NC}";
    (cd $INSTALL_PATH && git checkout -q $ODOO_HELPER_BRANCH && git submodule init && git submodule update);
    # TODO: may be it is good idea to pull changes from repository if it is already exists?
    # TODO: implement here some sort of upgrade mechanism?
    echo -e "${GREENC}OK${NC}: odoo-helper-scripts successfully clonned${NC}";
fi

# install odoo-helper user config
if [ ! -f "$ODOO_HELPER_SYS_CONF" ]; then
    echo "ODOO_HELPER_ROOT=$INSTALL_PATH;"   >> $ODOO_HELPER_SYS_CONF;
    echo "ODOO_HELPER_BIN=$ODOO_HELPER_BIN;" >> $ODOO_HELPER_SYS_CONF;
    echo "ODOO_HELPER_LIB=$ODOO_HELPER_LIB;" >> $ODOO_HELPER_SYS_CONF;
fi

# add odoo-helper-bin to path
for oh_cmd in $ODOO_HELPER_BIN/*; do
    if ! command -v $(basename $oh_cmd) >/dev/null 2>&1; then
        ln -s $oh_cmd /usr/local/bin/;
    fi
done


if [ -e "/etc/debian_version" ]; then
    odoo-helper install pre-requirements;
    ODOO_HELPER_PRE_REQUIREMENTS_INSTALLED=1;
fi

echo -e "${YELLOWC}odoo-helper-scripts${GREENC} seems to be successfully installed system-wide!${NC}";
echo -e "Install path is ${YELLOWC}${INSTALL_PATH}${NC}";
echo;
if [ -z "$ODOO_HELPER_PRE_REQUIREMENTS_INSTALLED" ]; then
    echo -e "${YELLOWC}NOTE${NC}: Do not forget to install odoo-helper system dependencies.";
    echo -e "To do this for debian-like systems run following command (${YELLOWC}sudo access required${NC}):";
    echo -e "    $ ${BLUEC}odoo-helper install pre-requirements${NC}";
    echo;
fi
echo -e "${YELLOWC}NOTE2${NC}: Do not forget to install and configure postgresql.";
echo -e "To do this for debian-like systems run following command (${YELLOWC}sudo access required${NC}):";
echo -e "    $ ${BLUEC}odoo-helper install postgres${NC}";
echo -e "Or use command below to create postgres user for Odoo too:";
echo -e "    $ ${BLUEC}odoo-helper install postgres odoo odoo${NC}";
echo;
echo -e "To update odoo-helper-scripts, just run following command:";
echo -e "    $ ${BLUEC}odoo-helper system update${NC}";

