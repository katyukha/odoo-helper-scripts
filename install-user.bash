if ! command -v git >/dev/null 2>&1; then
    echo "To use this script collection you must install Git!"
    exit 1;
fi

# define vars
INSTALL_PATH=$HOME/odoo-helper-scripts;
BASHRC_FILE=$HOME/.bashrc
ODOO_HELPER_LIB=$INSTALL_PATH/lib;
ODOO_HELPER_BIN=$INSTALL_PATH/bin;
ODOO_HELPER_USER_CONF=$HOME/odoo-helper.conf;

# clone repo
if [ ! -d $INSTALL_PATH ]; then
    git clone https://github.com/katyukha/odoo-helper-scripts $INSALL_PATH;
fi

# install odoo-helper user config
if [ ! -f $ODOO_HELPER_USER_CONF ]; then
    echo "ODOO_HELPER_ROOT=$INSTALL_PATH;"   >> $ODOO_HELPER_USER_CONF;
    echo "ODOO_HELPER_BIN=$ODOO_HELPER_BIN;" >> $ODOO_HELPER_USER_CONF;
    echo "ODOO_HELPER_LIB=$ODOO_HELPER_LIB;" >> $ODOO_HELPER_USER_CONF;
fi

# add odoo-helper-bin to path
if ! command -v odoo-helper >/dev/null 2>&1; then
    echo "" >> $BASHRC_FILE;
    echo "PATH=$PATH:$ODOO_HELPER_BIN" >> $BASHRC_FILE;
    export PATH=$PATH:$ODOO_HELPER_BIN;
fi
    
echo "Odoo-helper-scripts seems to be correctly installed for current user!";
echo "Install path is $INSTALL_PATH";
echo "To update odoo-helper-scripts, just go to install path, and pull last repo changes:";
echo "    (cd $INSTALL_PATH && git pull)";
