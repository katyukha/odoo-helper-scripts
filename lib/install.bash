if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------
ohelper_require "postgres";


set -e; # fail on errors

# Set-up defaul values for environment variables
function install_preconfigure_env {
    ODOO_REPO=${ODOO_REPO:-https://github.com/odoo/odoo.git};
    ODOO_BRANCH=${ODOO_BRANCH:-9.0};
    SHALLOW_CLONE=${ODOO_SHALLOW_CLONE:-off};
    DOWNLOAD_ARCHIVE=${ODOO_DOWNLOAD_ARCHIVE:-on};
    DB_USER=${ODOO_DBUSER:-odoo};
    DB_PASSWORD=${ODOO_DBPASSWORD:-odoo};
    DB_HOST=${ODOO_DBHOST:-localhost};
}

# create directory tree for project
function install_create_project_dir_tree {
    # create dirs is imported from common module
    create_dirs $PROJECT_ROOT_DIR \
        $ADDONS_DIR \
        $CONF_DIR \
        $LOG_DIR \
        $LIBS_DIR \
        $DOWNLOADS_DIR \
        $BACKUP_DIR \
        $REPOSITORIES_DIR \
        $BIN_DIR \
        $DATA_DIR;
}

# install_clone_odoo [path [branch [repo]]]
function install_clone_odoo {
    local odoo_path=${1:-$ODOO_PATH};
    local odoo_branch=${2:-$ODOO_BRANCH};
    local odoo_repo=${3:-${ODOO_REPO:-https://github.com/odoo/odoo.git}};

    if [ "$SHALLOW_CLONE" == "on" ]; then
        local DEPTH="--depth=1";
    else
        local DEPTH="";
    fi

    if [ ! -z $odoo_branch ]; then
        local branch_opt=" --branch $odoo_branch --single-branch";
    fi

    git clone $branch_opt $DEPTH $odoo_repo $odoo_path;

}

# install_sys_deps_internal dep_1 dep_2 ... dep_n
function install_sys_deps_internal {
    # Odoo's debian/contol file usualy contains this in 'Depends' section 
    # so we need to skip it before running apt-get
    if [ "$1" == '${misc:Depends}' ]; then
        shift;
    fi
    echo "Installing system dependencies: $@";
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-y";
    fi
    sudo apt-get install $opt_apt_always_yes "$@";
}

# Get dependencies from odoo's debian/control file
function install_sys_deps {
    local control_file=$ODOO_PATH/debian/control;
    local perl_expr='next if /^#/; $p=(s/^Depends:\s*/ / or (/^ / and $p)); s/,|\n|\([^)]+\)//mg; print if $p';

    # If odoo not installed, then fetch this file from odoo repository
    if [ ! -f "$control_file" ]; then
        if [ ! -z $ODOO_REPO ] && [[ $ODOO_REPO == "https://github.com"* ]]; then
            # Odoo repo is github, so we can get control file easily
            # NOTE: Experimental code
            local gh_repo=${ODOO_REPO##https://github.com};
            gh_repo=${gh_repo%.git};
            local control_url="raw.githubusercontent.com/$gh_repo/$ODOO_BRANCH/debian/control";
            control_url=${control_url/\/\//\/};  # replace '//' on '/'
            control_url=https://${control_url/\/\//\/};  # repeat replace '//' on '/'
            local tmp_control=$(mktemp);
            wget $control_url -O $tmp_control;
            control_file=$tmp_control; 
        else
            echo -e "${YELLOWC}Warning, cannot get debian/control file automaticaly.${NC}";
        fi
    fi

    # Parse control file and install system dependencies
    if [ -f "$control_file" ]; then
        local sys_deps=$(perl -ne 'next if /^#/; $p=(s/^Depends:\s*/ / or (/^ / and $p)); s/,|\n|\([^)]+\)//mg; print if $p' < $control_file);
        echo -e "${BLUEC}Sys deps to be installed:${NC} $sys_deps";
        install_sys_deps_internal $sys_deps;
    else
        echo -e "${REDC}ERROR! Cannot find debian/control file${NC}";
    fi
   
    # Remove temp file if it was created 
    if [ ! -z $tmp_control ]; then
        rm $tmp_control;
    fi
}

function install_and_configure_postgresql {
    # Check if postgres is installed on this machine. If not, install it
    if ! postgres_is_installed; then
        postgres_install_postgresql;
    else
        echov "It seems that postgresql is already installed, so not installing it, just configuring...";
    fi

    postgres_user_create $DB_USER $DB_PASSWORD;
    echov "Postgres seems to be installed and db user seems created.";
}


# install_system_prerequirements [install extra utils (1)]
function install_system_prerequirements {
    local install_extra_utils=${1:-$INSTALL_EXTRA_UTILS};
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-y";
    fi

    echo "Updating package list..."
    sudo apt-get update || true;

    echo "Installing system preprequirements...";
    local to_install="git wget python-setuptools perl g++ libpq-dev python-dev";
    if [ ! -z $install_extra_utils ]; then
        to_install="$to_install expect-dev";
    fi;
    sudo apt-get install $opt_apt_always_yes $to_install;

    # Install wkhtmltopdf
    wget http://download.gna.org/wkhtmltopdf/0.12/0.12.2.1/wkhtmltox-0.12.2.1_linux-trusty-amd64.deb -O /tmp/wkhtmltox.deb
    sudo dpkg --force-depends -i /tmp/wkhtmltox.deb  # install ignoring dependencies
    sudo apt-get -f install $opt_apt_always_yes;   # fix broken packages

    sudo easy_install pip;
    sudo pip install --upgrade pip virtualenv;
}


# Install virtual environment, and preinstall some packages
# install_virtual_env [path]
function install_virtual_env {
    local venv_path=${1:-$VENV_DIR};
    if [ ! -z $venv_path ] &&[ ! -d $venv_path ]; then
        if [ ! -z $USE_SYSTEM_SITE_PACKAGES ]; then
            local venv_opts=" --system-site-packages ";
        else
            local venv_opts="";
        fi
        virtualenv $venv_opts $venv_path;
    fi
}

# install_python_prerequirements [install extra utils (1)]
function install_python_prerequirements {
    local install_extra_utils=${1:-$INSTALL_EXTRA_UTILS};
    # required to make odoo.py work correctly when setuptools too old
    execu easy_install --upgrade setuptools;
    execu pip install --upgrade pip;  

    if ! execu python -c 'import pychart'; then
        execu pip install http://download.gna.org/pychart/PyChart-1.39.tar.gz;
    fi

    if [ ! -z $install_extra_utils ]; then
        execu pip install --upgrade erppeek setproctitle python-slugify watchdog;
    fi

    # Install PIL only for odoo versions that have no requirements txt (<8.0)
    if [ ! -f "$ODOO_PATH/requirements.txt" ]; then
        execu pip install http://effbot.org/media/downloads/PIL-1.1.7.tar.gz;
    fi
}

# Generate configuration file fo odoo
# this function looks into ODOO_CONF_OPTIONS anvironment variable,
# which should be associative array with options to be written to file
# install_generate_odoo_conf <file_path>
function install_generate_odoo_conf {
    local conf_file=$1;

    # default addonspath
    local addons_path="$ODOO_PATH/openerp/addons,$ODOO_PATH/addons,$ADDONS_DIR";

    # default values
    ODOO_CONF_OPTIONS[addons_path]="${ODOO_CONF_OPTIONS['addons_path']:-$addons_path}";
    ODOO_CONF_OPTIONS[admin_passwd]="${ODOO_CONF_OPTIONS['admin_passwd']:-admin}";
    ODOO_CONF_OPTIONS[data_dir]="${ODOO_CONF_OPTIONS['data_dir']:-$DATA_DIR}";
    ODOO_CONF_OPTIONS[logfile]="${ODOO_CONF_OPTIONS['logfile']:-$LOG_FILE}";
    ODOO_CONF_OPTIONS[pidfile]="${ODOO_CONF_OPTIONS['pidfile']:-$ODOO_PID_FILE}";
    ODOO_CONF_OPTIONS[db_host]="${ODOO_CONF_OPTIONS['db_host']:-False}";
    ODOO_CONF_OPTIONS[db_port]="${ODOO_CONF_OPTIONS['db_port']:-False}";
    ODOO_CONF_OPTIONS[db_user]="${ODOO_CONF_OPTIONS['db_user']:-odoo}";
    ODOO_CONF_OPTIONS[db_password]="${ODOO_CONF_OPTIONS['db_password']:-False}";

    local conf_file_data="[options]";
    for key in ${!ODOO_CONF_OPTIONS[@]}; do
        conf_file_data="$conf_file_data\n$key = ${ODOO_CONF_OPTIONS[$key]}";
    done

    echo -e "$conf_file_data" > $conf_file;
}


# Workaround for situation when setup does not install openerp-gevent script.
function odoo_gevent_install_workaround {
    if [ -f "$ODOO_PATH/openerp-gevent" ] && grep -q -e "scripts=\['openerp-server', 'odoo.py'\]," "$ODOO_PATH/setup.py";
    then
        echov -e "${YELLOWC}There is openerp-gevent in used in odoo, but it is not specified in setup.py${NC}"
        echov -e "${YELLOWC}Fix will be applied${NC}"
        cp $ODOO_PATH/setup.py $ODOO_PATH/setup.py.backup
        sed -i -r "s/scripts=\['openerp-server', 'odoo.py'\],/scripts=\['openerp-server', 'openerp-gevent', 'odoo.py'\],/" \
            $ODOO_PATH/setup.py;

        odoo_gevent_fix_applied=1;
    fi
}

function odoo_gevent_install_workaround_cleanup {
    if [ ! -z $odoo_gevent_fix_applied ]; then
        mv -f $ODOO_PATH/setup.py.backup $ODOO_PATH/setup.py
        unset odoo_gevent_fix_applied;
    fi
}

function odoo_run_setup_py {
    # Workaround for situation when setup does not install openerp-gevent script.
    odoo_gevent_install_workaround;

    # Install odoo
    (cd $ODOO_PATH && execu python setup.py develop);

     
    # Workaround for situation when setup does not install openerp-gevent script.
    # (Restore modified setup.py)
    odoo_gevent_install_workaround_cleanup;
}


