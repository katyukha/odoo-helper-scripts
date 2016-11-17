#!/bin/bash

# Simple script to install odoo-helper-script system-wide
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Get odoo-helper branch. Default is master
ODOO_HELPER_BRANCH=${1:-master}

set -e;  # Fail on each error

if ! command -v git >/dev/null 2>&1; then
    apt-get install -y git;
fi

# define vars
ODOO_HELPER_SYS_CONF="/etc/odoo-helper.conf";

# Test if there is odoo-helper conf in home dir, which means
# that odoo-helper-scripts may be already installed
if [ -f "$ODOO_HELPER_SYS_CONF" ]; then
    source $ODOO_HELPER_SYS_CONF;
fi

# Configure paths
INSTALL_PATH=${ODOO_HELPER_ROOT:-/opt/odoo-helper-scripts};
ODOO_HELPER_LIB=${ODOO_HELPER_LIB:-$INSTALL_PATH/lib};
ODOO_HELPER_BIN=${ODOO_HELPER_BIN:-$INSTALL_PATH/bin};

# clone repo
if [ ! -d $INSTALL_PATH ]; then
    git clone -q -b $ODOO_HELPER_BRANCH \
        https://github.com/katyukha/odoo-helper-scripts $INSTALL_PATH;
    # TODO: may be it is good idea to pull changes from repository if it is already exists?
    # TODO: implement here some sort of upgrade mechanism?
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
    
echo "Odoo-helper-scripts seems to be correctly installed system-wide!";
echo "Install path is $INSTALL_PATH";
echo "To update odoo-helper-scripts, just run following command:";
echo "    odoo-helper system update";

