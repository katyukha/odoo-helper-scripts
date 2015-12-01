#!/bin/bash

# Simple script to install odoo-helper-script system-wide


set -e;  # Fail on each error

if ! command -v git >/dev/null 2>&1; then
    sudo apt-get install -y git
    exit 1;
fi

# define vars
ODOO_HELPER_SYS_CONF="/etc/odoo-helper.conf";

# Test if there is odoo-helper conf in home dir, which means
# that odoo-helper-scripts may be already installed
if [ -f $ODOO_HELPER_SYS_CONF ]; then
    source $ODOO_HELPER_SYS_CONF;
fi

# Configure paths
INSTALL_PATH=${ODOO_HELPER_ROOT:-/opt/odoo-helper-scripts};
ODOO_HELPER_LIB=${ODOO_HELPER_LIB:-$INSTALL_PATH/lib};
ODOO_HELPER_BIN=${ODOO_HELPER_BIN:-$INSTALL_PATH/bin};

# clone repo
if [ ! -d $INSTALL_PATH ]; then
    sudo git clone https://github.com/katyukha/odoo-helper-scripts $INSTALL_PATH;
    # TODO: may be it is good idea to pull changes from repository if it is already exists?
    # TODO: implement here some sort of upgrade mechanism?
fi

# install odoo-helper user config
if [ ! -f $ODOO_HELPER_SYS_CONF ]; then
    sudo echo "ODOO_HELPER_ROOT=$INSTALL_PATH;"   >> $ODOO_HELPER_SYS_CONF;
    sudo echo "ODOO_HELPER_BIN=$ODOO_HELPER_BIN;" >> $ODOO_HELPER_SYS_CONF;
    sudo echo "ODOO_HELPER_LIB=$ODOO_HELPER_LIB;" >> $ODOO_HELPER_SYS_CONF;
fi

# add odoo-helper-bin to path
if ! command -v odoo-helper >/dev/null 2>&1; then
    sudo ln -s $ODOO_HELPER_BIN/odoo-helper /usr/local/bin/;
    sudo ln -s $ODOO_HELPER_BIN/odoo-install /usr/local/bin/;
fi
    
echo "Odoo-helper-scripts seems to be correctly installed system-wide!";
echo "Install path is $INSTALL_PATH";
echo "To update odoo-helper-scripts, just go to install path, and pull last repo changes:";
echo "    (cd $INSTALL_PATH && sudo git pull)";

