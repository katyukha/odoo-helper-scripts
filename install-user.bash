#!/bin/bash

# Simple script to install odoo-helper-script userspace of current user
# This script does not require sudo, but some features of installed
# odoo-helper-scripts may require sudo.

set -e;  # Fail on each error

# Define colors
NC='\e[0m';
REDC='\e[31m';
GREENC='\e[32m';
YELLOWC='\e[33m';
BLUEC='\e[34m';
LBLUEC='\e[94m';

if ! command -v git >/dev/null 2>&1; then
    echo -e "${REDC}ERROR${NC}: To use this script collection you must install ${YELLOWC}git${NC}!"
    exit 1;
fi

if ! command -v wget >/dev/null 2>&1; then
    echo -e "${REDC}ERROR${NC}: To use this script collection you must install ${YELLOC}wget${NC}!"
    exit 1;
fi

# Get odoo-helper branch. Default is master
ODOO_HELPER_BRANCH=${1:-master}

# define vars
ODOO_HELPER_USER_CONF="$HOME/odoo-helper.conf";

# Test if there is odoo-helper conf in home dir, which means
# that odoo-helper-scripts may be already installed
if [ -f "$ODOO_HELPER_USER_CONF" ]; then
    source $ODOO_HELPER_USER_CONF;
fi

# Configure paths
INSTALL_PATH=${ODOO_HELPER_INSTALL_PATH:-$HOME/odoo-helper-scripts};
ODOO_HELPER_LIB=${ODOO_HELPER_LIB:-$INSTALL_PATH/lib};
ODOO_HELPER_BIN=${ODOO_HELPER_BIN:-$INSTALL_PATH/bin};

# clone repo
if [ ! -d $INSTALL_PATH ]; then
    git clone -q https://gitlab.com/katyukha/odoo-helper-scripts $INSTALL_PATH;
    (cd $INSTALL_PATH && git checkout -q $ODOO_HELPER_BRANCH);
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
echo -e "${BLUEC}Adding links to ${YELLOWC}$HOME/bin${NC}"
if [ ! -d $HOME/bin ]; then
    mkdir -p $HOME/bin;
fi
for oh_cmd in $ODOO_HELPER_BIN/*; do
    if ! command -v $(basename $oh_cmd) >/dev/null 2>&1; then
        ln -s $oh_cmd $HOME/bin;
    fi
done

    
echo -e "${YELLOWC}odoo-helper-scripts${GREENC} seems to be successfully installed for current user!${NC}";
echo -e "Install path is ${YELLOWC}${INSTALL_PATH}${NC}";
echo;
echo -e "${YELLOWC}NOTE${NC}: Do not forget to install odoo-helper system dependencies.";
echo -e "To do this for debian-like systems run following command (${YELLOWC}sudo access required${NC}):";
echo -e "    $ ${BLUEC}odoo-helper install pre-requirements${NC}";
echo;
echo -e "To update odoo-helper-scripts, just run following command:";
echo -e "    $ ${BLUEC}odoo-helper system update${NC}";
echo;

if ! command -v odoo-helper >/dev/null 2>&1; then
    echo -e "${YELLOWC}WARNING${NC}: ${BLUEC}$HOME/bin${NC} is not on ${BLUEC}\$PATH${NC}. One of following actions may be required:";
    echo -e "    - shell reload/restart (for example open new termial window)"
    echo -e "    - manualy add ${BLUEC}$HOME/bin${NC} directory to ${BLUEC}\$PATH${NC} (Stack Exchange question: https://unix.stackexchange.com/questions/381228/home-bin-dir-is-not-on-the-path)"
fi
