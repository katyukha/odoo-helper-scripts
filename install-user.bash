#!/bin/bash

# Simple script to install odoo-helper-script userspace of current user
# This script does not require sudo, but some features of installed
# odoo-helper-scripts may require sudo.

set -e;  # Fail on each error

if ! command -v git >/dev/null 2>&1; then
    echo "To use this script collection you must install Git!"
    exit 1;
fi

# define vars
ODOO_HELPER_USER_CONF="$HOME/odoo-helper.conf";

# Test if there is odoo-helper conf in home dir, which means
# that odoo-helper-scripts may be already installed
if [ -f "$ODOO_HELPER_USER_CONF" ]; then
    source $ODOO_HELPER_USER_CONF;
fi

# Configure paths
INSTALL_PATH=${ODOO_HELPER_ROOT:-$HOME/odoo-helper-scripts};
ODOO_HELPER_LIB=${ODOO_HELPER_LIB:-$INSTALL_PATH/lib};
ODOO_HELPER_BIN=${ODOO_HELPER_BIN:-$INSTALL_PATH/bin};

# clone repo
if [ ! -d $INSTALL_PATH ]; then
    git clone https://github.com/katyukha/odoo-helper-scripts $INSTALL_PATH;
    # TODO: may be it is good idea to pull changes from repository if it is already exists?
    # TODO: implement here some sort of upgrade mechanism?
fi

# install odoo-helper user config
if [ ! -f "$ODOO_HELPER_USER_CONF" ]; then
    echo "ODOO_HELPER_ROOT=$INSTALL_PATH;"   >> $ODOO_HELPER_USER_CONF;
    echo "ODOO_HELPER_BIN=$ODOO_HELPER_BIN;" >> $ODOO_HELPER_USER_CONF;
    echo "ODOO_HELPER_LIB=$ODOO_HELPER_LIB;" >> $ODOO_HELPER_USER_CONF;
fi

# add odoo-helper-bin to path
echo "Adding links to $HOME/bin"
if [ ! -d $HOME/bin ]; then
    mkdir -p $HOME/bin;
fi
for oh_cmd in $ODOO_HELPER_BIN/*; do
    if ! command -v $(basename $oh_cmd) >/dev/null 2>&1; then
        ln -s $oh_cmd $HOME/bin;
    fi
done
    
echo "Odoo-helper-scripts seems to be correctly installed for current user!";
echo "Install path is $INSTALL_PATH";
echo "To update odoo-helper-scripts, just go to install path, and pull last repo changes:";
echo "    (cd $INSTALL_PATH && git pull)";
