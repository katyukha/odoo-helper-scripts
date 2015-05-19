#!/bin/bash

# Odoo install helper script

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
F=`readlink -f $SCRIPT`;  # full script path;
WORKDIR=`pwd`;

REQUIREMENTS_FILE_NAME="odoo_requirements.txt";
CONF_FILE_NAME="odoo-helper.conf";
 
set -e;

# Check environment for config
BRANCH=${ODOO_BRANCH:-8.0};
SHALLOW_CLONE=${ODOO_SHALLOW_CLONE:-off};
DOWNLOAD_ARCHIVE=${ODOO_DOWNLOAD_ARCHIVE:-on};
DB_USER=${ODOO_DBUSER:-odoo};
DB_PASSWORD=${ODOO_DBPASSWORD:-odoo};
DB_HOST=${ODOO_DBHOST:-localhost};

# Utility functions
function create_dirs {
    # Simple function to create directories passed as arguments
    for dir in $@; do
        if [ ! -d $dir ]; then
            mkdir -p "$dir";
        fi
    done;
}

function print_usage {
    echo "Bash script to instal dev version of odoo in local environment

    Usage:
         bash $SCRIPT_NAME [options]

    Environment variables used:
         ODOO_BRANCH         - allow to clone specified branch. Default is 8.0
         ODOO_DOWNLOAD_ARCHIVE - (on|off) if on then only archive will be downloaded
                                 not clonned. Default 'on'
         ODOO_SHALLOW_CLONE  - (on|off) allow or disallow shallow clone.
                               signifianly increases performance, but have some limitations.
                               If ODOO_DOWNLOAD_ARCHIVE option is on, then this option
                               has no effect
                               Default is: off
         ODOO_DBHOST         - allow to specify Postgresql's server host.
                               Default: localhost
         ODOO_DBUSER         - allow to specify user to connect to DB as.
                               Default: odoo
         ODOO_DBPASSWORD     - allow to specify db password to connect to DB as.
                               Default: odoo

    Available options:
         --install-dir <dir>         - directory to install odoo in. default: $INSTALL_DIR
         --branch <branch>           - specify odoo branch to clone. default: $BRANCH
         --download-archive on|off   - if on, then odoo will be downloaded as archive. it is faster
                                       Default: $DOWNLOAD_ARCHIVE
         --use-shallow-clone on|off  - if not set 'download-archive' then, this option may increase
                                       download speed using --depth=1 option in git clone. this will
                                       download all by one commit. Default: $SHALLOW_CLONE
         --db-host <host>            - database host to be used in settings. default: $DB_HOST
         --db-user <user>            - database user to be used in settings. default: $DB_USER
         --db-pass <password>        - database password to be used in settings. default: odoo

    Prerequirements:
         Next packages must be installed system-wide:
             - virtualenv
             - postgres
             - python-dev
             - g++
             - libpq-dev
             - git

    After instalation configs will be generated in 'conf' dir
    Also 'log' directory will contain Odoo logs
    ";
}

function parse_options {
    if [[ $# -lt 1 ]]; then
        echo "No options supplied $#: $@";
        print_usage;
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --install-dir)
                INSTALL_DIR=`readlink -f $2`;
                shift;
            ;;
            --branch|-b)
                BRANCH=$2;
                shift;
            ;;
            --download-archive)
                DOWNLOAD_ARCHIVE=$2;
                shift;
            ;;
            --use-shallow-clone)
                SHALLOW_CLONE=$2;
                shift;
            ;;
            --db-host)
                DB_HOST=$2;
                shift;
            ;;
            --db-user)
                DB_USER=$2;
                shift;
            ;;
            --db-pass)
                DB_PASSWORD=$2;
                shift;
            ;;
            -h|--help|help)
                print_usage;
                exit 0;
            ;;
            *)
                echo "Unknown option global option /command $key";
                exit 1;
            ;;
        esac
        shift
    done
}

function config_dirs {
    # Directory and file paths
    INSTALL_DIR=${INSTALL_DIR:-$WORKDIR/odoo-$BRANCH};
    BASE_DIR=$INSTALL_DIR;
    CONF_DIR=$BASE_DIR/conf;
    ODOO_CONF_FILE=$CONF_DIR/odoo.conf;
    ODOO_TEST_CONF_FILE=$CONF_DIR/odoo.test.conf;
    LOG_DIR=$BASE_DIR/logs;
    LIBS_DIR=$BASE_DIR/libs;
    DOWNLOADS_DIR=$BASE_DIR/downloads;
    CUSTOM_ADDONS_DIR=$BASE_DIR/custom_addons;
    DATA_DIR=$BASE_DIR/data_dir;
    BIN_DIR=$BASE_DIR/bin;
    VENV_DIR=$BASE_DIR/venv;
    PID_FILE=$BASE_DIR/odoo.pid;
    ODOO_PATH=$BASE_DIR/odoo;
    ADDONS_PATH="$ODOO_PATH/openerp/addons,$ODOO_PATH/addons,$CUSTOM_ADDONS_DIR";
}

function download_odoo {
   local ODOO_ARCHIVE=$DOWNLOADS_DIR/odoo.$BRANCH.tar.gz
   if [ ! -f $ODOO_ARCHIVE ]; then
       wget -q -O $ODOO_ARCHIVE https://github.com/odoo/odoo/archive/$BRANCH.tar.gz;
   fi
   tar -zxf $ODOO_ARCHIVE;
   mv odoo-$BRANCH $ODOO_PATH;
}

function clone_odoo {
    if [ "$SHALLOW_CLONE" == "on" ]; then
        local DEPTH="--depth=1";
    else
        local DEPTH="";
    fi

    git clone --branch $BRANCH --single-branch $DEPTH https://github.com/odoo/odoo.git $ODOO_PATH;

}

function install_odoo {
    cd "$INSTALL_DIR";
    # if not installed odoo, install it
    if [ ! -d $BASE_DIR/odoo ]; then
        if [ "$DOWNLOAD_ARCHIVE" == "on" ]; then
            download_odoo;
        else
            clone_odoo;
        fi

    fi

    # install into virtualenv odoo and its dependencies
    if [ ! -d $VENV_DIR ]; then
        virtualenv  $VENV_DIR;
    fi
    source $VENV_DIR/bin/activate;
    pip install --upgrade pip setuptools;  # required to make odoo.py work correctly
    if ! python -c "import pychart"; then
        pip install http://download.gna.org/pychart/PyChart-1.39.tar.gz;
    fi
    pip install --allow-external=PIL \
                --allow-unverified=PIL \
                -e $ODOO_PATH;
    deactivate;
}

function print_helper_config {
    echo "ODOO_BRANCH=$BRANCH;";
    echo "PROJECT_ROOT_DIR=$INSTALL_DIR;";
    echo "CONF_DIR=$CONF_DIR;";
    echo "LOG_DIR=$LOG_DIR;";
    echo "LIBS_DIR=$LIBS_DIR;";
    echo "DOWNLOADS_DIR=$DOWNLOADS_DIR;";
    echo "ADDONS_DIR=$CUSTOM_ADDONS_DIR;";
    echo "DATA_DIR=$DATA_DIR;";
    echo "BIN_DIR=$BIN_DIR;";
    echo "VENV_DIR=$VENV_DIR;";
    echo "ODOO_PATH=$ODOO_PATH;";
    echo "ODOO_CONF_FILE=$ODOO_CONF_FILE;";
    echo "ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;";
}

# Install process
parse_options $@;
config_dirs;

create_dirs $INSTALL_DIR \
    $CUSTOM_ADDONS_DIR \
    $CONF_DIR \
    $LOG_DIR \
    $LIBS_DIR \
    $DOWNLOADS_DIR \
    $BIN_DIR;
 
install_odoo; 

echo "`print_helper_config`" > $BASE_DIR/$CONF_FILE_NAME;
 
# Generate configuration
cat > $ODOO_CONF_FILE << EOF
[options]
addons_path = $ADDONS_PATH
admin_passwd = admin
auto_reload = False
csv_internal_sep = ,
data_dir = $DATA_DIR
db_host = $DB_HOST
db_maxconn = 64
;db_name = odoo
db_user = $DB_USER
db_password = $DB_PASSWORD
db_port = False
db_template = template1
dbfilter = .*
debug_mode = False
demo = {}
email_from = False
import_partial = 
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
list_db = True
log_db = False
log_handler = [':INFO']
log_level = info
logfile = $LOG_DIR/odoo.log
logrotate = False
longpolling_port = 8072
max_cron_threads = 2
osv_memory_age_limit = 1.0
osv_memory_count_limit = False
pg_path = None
pidfile = $PID_FILE
proxy_mode = False
reportgz = False
secure_cert_file = server.cert
secure_pkey_file = server.pkey
server_wide_modules = None
smtp_password = False
smtp_port = 25
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_commit = False
test_enable = False
test_file = False
test_report_directory = False
timezone = False
translate_modules = ['all']
unaccent = False
without_demo = False
workers = 1
xmlrpc = True
xmlrpc_interface = 
xmlrpc_port = 8069
xmlrpcs = True
xmlrpcs_interface = 
xmlrpcs_port = 8071
EOF
#---------------------------------------------
 
# Generate test configuration configuration
cat > $ODOO_TEST_CONF_FILE << EOF
[options]
addons_path = $ADDONS_PATH
admin_passwd = admin
auto_reload = False
csv_internal_sep = ,
data_dir = $BASE_DIR/data_dir
db_host = $DB_HOST
db_maxconn = 64
db_name = $DB_USER-odoo-test
db_user = $DB_USER
db_password = $DB_PASSWORD
db_port = False
db_template = template1
dbfilter = $DB_USER-odoo-test
debug_mode = False
demo = {}
email_from = False
import_partial = 
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
list_db = True
log_db = False
log_handler = [':INFO']
log_level = test
logfile = False
logrotate = False
longpolling_port = 8072
max_cron_threads = 2
osv_memory_age_limit = 1.0
osv_memory_count_limit = False
pg_path = None
pidfile = $BASE_DIR/odoo-test.pid
proxy_mode = False
reportgz = False
;secure_cert_file = server.cert
;secure_pkey_file = server.pkey
server_wide_modules = None
smtp_password = False
smtp_port = 25
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_commit = False
test_enable = False
test_file = False
test_report_directory = False
timezone = False
translate_modules = ['all']
unaccent = False
without_demo = False
workers = 1
xmlrpc = False
xmlrpc_interface = 
xmlrpc_port = 8269
xmlrpcs = False
xmlrpcs_interface = 
xmlrpcs_port = 8271
 
EOF
 
#---------------------------------------------

# Generate new module script
cat > $BIN_DIR/new_module.bash <<EOF
#!/bin/bash

#
# Usage:
#    new_module.bash <module_name> [root]
# Where 'root' arg is root directory to place module in. By default it is 'custom_addons'
#

# Guess directory script is placed in
F=\`readlink -f \$0\`
source $BASE_DIR/$CONF_FILE_NAME;
BASEDIR=\$PROJECT_ROOT_DIR;
CUSTOM_ADDONS_DIR=\$ADDONS_DIR
 
set -e;

function usage {
    echo "Usage:";
    echo "    new_module.bash <module_name> [root]";
    echo "Where 'root' arg is root directory to place module in. By default it is 'custom_addons'";
}
 
function generate_oerp_py {
    MOD_PATH=\$1
    cat > \$MOD_PATH/__openerp__.py << EOFI
# -*- coding: utf-8 -*-
{
    'name': 'New OpenERP Module',
    'version': '0.0.1',
    'author': '`whoami`',
    'category': 'Added functionality',
    'description': """
        ---
    """,
    'website': '',
    'images': [],
    'depends' : [],
    'data': [],     # Place xml views here
    'demo': [],
    'installable': True,
    'auto_install': False,
}
EOFI
}
 
function generate_gitignore {
    MOD_PATH=\$1
 
    cat > \$MOD_PATH/.gitignore << EOFI
*.pyc
*.swp
*.idea/
*~
*.swo
*.pyo
EOFI
 
}
 
function create_module {
    NEW_MODULE_NAME=\$1
    NEW_MODULE_DIR=\$2

    if [ -z \$NEW_MODULE_DIR ]; then
        NEW_MODULE_DIR=\$CUSTOM_ADDONS_DIR;
    fi

    NEW_MODULE_PATH=\$NEW_MODULE_DIR/\$NEW_MODULE_NAME
 
    if [ -d "\$NEW_MODULE_PATH" ]; then
        echo "Module \$NEW_MODULE_NAME already exists in module path \$NEW_MODULE_PATH";
        exit -1;
    fi;
 
    mkdir \$NEW_MODULE_PATH;
    generate_oerp_py \$NEW_MODULE_PATH;
    generate_gitignore \$NEW_MODULE_PATH;
 
    mkdir \$NEW_MODULE_PATH/models;
    mkdir \$NEW_MODULE_PATH/views;
    mkdir \$NEW_MODULE_PATH/security;
    mkdir \$NEW_MODULE_PATH/reports;
 
    echo "import models" > \$NEW_MODULE_PATH/__init__.py;
    touch "\$NEW_MODULE_PATH/models/__init__.py";
 
 
}
 
if [ -z \$1 ]; then
    usage;
    exit 0;
fi

create_module \$1 \$2;
EOF
 
chmod a+x $BIN_DIR/new_module.bash;

#---------------------------------------------

echo "Edit configuration at $ODOO_CONF_FILE.conf";
echo "To create skeleton for new module use $BIN_DIR/new_module.bash script";
