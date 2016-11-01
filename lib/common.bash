
set -e; # fail on errors

# Odoo-helper mark that common module is imported
ODOO_HELPER_COMMON_IMPORTED=1;

declare -A ODOO_HELPER_IMPORTED_MODULES;
ODOO_HELPER_IMPORTED_MODULES[common]=1

# Define version number
ODOO_HELPER_VERSION="0.0.10"

# if odoo-helper root conf is not loaded yet, try to load it
# This is useful when this lib is used by external utils,
# making possible to write things like:
#   source $(odoo-helper system lib-path common);
#   oh_require 'server'
#   ...

if [ -z $ODOO_HELPER_ROOT ]; then
    if [ -f "/etc/odoo-helper.conf" ]; then
        source "/etc/odoo-helper.conf";
    fi
    if [ -f "$HOME/odoo-helper.conf" ]; then
        source "$HOME/odoo-helper.conf";
    fi

    if [ -z $ODOO_HELPER_ROOT ]; then
        echo "Odoo-helper-scripts seems not been installed correctly.";
        echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
        exit 1;
    fi
fi

# predefined filenames
CONF_FILE_NAME="odoo-helper.conf";

# Color related definitions
function allow_colors {
    NC='\e[0m';
    REDC='\e[31m';
    GREENC='\e[32m';
    YELLOWC='\e[33m';
    BLUEC='\e[34m';
    LBLUEC='\e[94m';
}

# could be used to hide colors in output
function deny_colors {
    NC='';
    REDC='';
    GREENC='';
    YELLOWC='';
    BLUEC='';
    LBLUEC='';
}

# Allow colors by default
allow_colors;
# -------------------------

# Get path to specified bash lib
# oh_get_lib_path <lib name>
function oh_get_lib_path {
    local mod_name=$1;
    echo "$ODOO_HELPER_LIB/$mod_name.bash";
}

# Simplify import controll
# oh_require <module_name>
function ohelper_require {
    local mod_name=$1;
    if [ -z ${ODOO_HELPER_IMPORTED_MODULES[$mod_name]} ]; then
        ODOO_HELPER_IMPORTED_MODULES[$mod_name]=1;
        source $(oh_get_lib_path $mod_name);
    fi
}


# Simple function to exec command in virtual environment if required
function execv {
    if [ ! -z $VENV_DIR ]; then
        source $VENV_DIR/bin/activate;
    fi

    # Eval command and save result
    if eval "$@"; then
        local res=$?;
    else
        local res=$?;
    fi

    # deactivate virtual environment
    if [ ! -z $VENV_DIR ] && [ ! -z $VIRTUAL_ENV ]; then
        deactivate;
    fi

    return $res

}
# simply pass all args to exec or unbuffer
# depending on 'USE_UNBUFFER variable
# Also take in account virtualenv
function execu {
    # Check unbuffer option
    if [ ! -z $USE_UNBUFFER ] && ! command -v unbuffer >/dev/null 2>&1; then
        echo -e "${REDC}Command 'unbuffer' not found. Install it to use --use-unbuffer option";
        echo -e "It could be installed by installing package expect-dev";
        echo -e "Using standard behavior${NC}";
        USE_UNBUFFER=;
    fi

    # Decide wether to use unbuffer or not
    if [ ! -z $USE_UNBUFFER ]; then
        local unbuffer_opt="unbuffer";
    else
        local unbuffer_opt="";
    fi

    execv "$unbuffer_opt $@";
}


# Simple function to create directories passed as arguments
# create_dirs [dir1] [dir2] ... [dir_n]
function create_dirs {
    for dir in $@; do
        if [ ! -d $dir ]; then
            mkdir -p "$dir";
        fi
    done;
}


# Simple function to check if at least one command exists.
# Returns first existing command
function check_command {
    for test_cmd in $@; do
        if execv "command -v $test_cmd >/dev/null 2>&1"; then
            echo "$test_cmd";
            return 0;
        fi;
    done
    return 1;
}


# echov $@
# echo if verbose is on
function echov {
    if [ ! -z "$VERBOSE" ]; then
        echo "$@";
    fi
}

# check if process is running
# is_process_running <pid>
function is_process_running {
    kill -0 $1 >/dev/null 2>&1;
    return $?;
}

# random_string [length]
# default length = 8
function random_string {
    < /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-8};
}

# search_file_up <start path> <file name>
# Try to find file in start_path, if found, print path, if not found,
# then try to find it in parent directory recursively
function search_file_up {
    local path=$1;
    while [[ "$path" != "/" ]];
    do
        if [ -e "$path/$2" ]; then
            echo "$path/$2";
            return 0;
        fi
        path=`dirname $path`;
    done
}

# Try to find file in one of directories specified
# search_file_in <file_name> <dir1> [dir2] [dir3] ...
function search_file_in {
    local file_name=$1;
    shift;  # skip first argument

    while [[ $# -gt 0 ]]  # while there at least one argumet left
    do
        local path=$(readlink -f $1);
        if [ -e "$path/$file_name" ]; then
            echo "$path/$file_name";
            return 0;
        fi
        shift
    done
}

# function to print odoo-helper config
function print_helper_config {
    echo "ODOO_BRANCH=$ODOO_BRANCH;";
    echo "PROJECT_ROOT_DIR=$PROJECT_ROOT_DIR;";
    echo "CONF_DIR=$CONF_DIR;";
    echo "LOG_DIR=$LOG_DIR;";
    echo "LOG_FILE=$LOG_FILE;";
    echo "LIBS_DIR=$LIBS_DIR;";
    echo "DOWNLOADS_DIR=$DOWNLOADS_DIR;";
    echo "ADDONS_DIR=$ADDONS_DIR;";
    echo "DATA_DIR=$DATA_DIR;";
    echo "BIN_DIR=$BIN_DIR;";
    echo "VENV_DIR=$VENV_DIR;";
    echo "ODOO_PATH=$ODOO_PATH;";
    echo "ODOO_CONF_FILE=$ODOO_CONF_FILE;";
    echo "ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;";
    echo "ODOO_PID_FILE=$ODOO_PID_FILE;";
    echo "BACKUP_DIR=$BACKUP_DIR;";
    echo "REPOSITORIES_DIR=$REPOSITORIES_DIR;";
    echo "INIT_SCRIPT=$INIT_SCRIPT;";
}


# Function to configure default variables
function config_default_vars {
    if [ -z $PROJECT_ROOT_DIR ]; then
        echo -e "${REDC}There is no PROJECT_ROOT_DIR set!${NC}";
        return 1;
    fi
    CONF_DIR=${CONF_DIR:-$PROJECT_ROOT_DIR/conf};
    ODOO_CONF_FILE=${ODOO_CONF_FILE:-$CONF_DIR/odoo.conf};
    ODOO_TEST_CONF_FILE=${ODOO_TEST_CONF_FILE:-$CONF_DIR/odoo.test.conf};
    LOG_DIR=${LOG_DIR:-$PROJECT_ROOT_DIR/logs};
    LOG_FILE=${LOG_FILE:-$LOG_DIR/odoo.log};
    LIBS_DIR=${LIBS_DIR:-$PROJECT_ROOT_DIR/libs};
    DOWNLOADS_DIR=${DOWNLOADS_DIR:-$PROJECT_ROOT_DIR/downloads};
    ADDONS_DIR=${ADDONS_DIR:-$PROJECT_ROOT_DIR/custom_addons};
    DATA_DIR=${DATA_DIR:-$PROJECT_ROOT_DIR/data};
    BIN_DIR=${BIN_DIR:-$PROJECT_ROOT_DIR/bin};
    VENV_DIR=${VENV_DIR:-$PROJECT_ROOT_DIR/venv};
    ODOO_PID_FILE=${ODOO_PID_FILE:-$PROJECT_ROOT_DIR/odoo.pid};
    ODOO_PATH=${ODOO_PATH:-$PROJECT_ROOT_DIR/odoo};
    BACKUP_DIR=${BACKUP_DIR:-$PROJECT_ROOT_DIR/backups};
    REPOSITORIES_DIR=${REPOSITORIES_DIR:-$PROJECT_ROOT_DIR/repositories};
    INIT_SCRIPT=$INIT_SCRIPT;
}


# is_odoo_module <module_path>
function is_odoo_module {
    if [ ! -d $1 ]; then
       return 1;
    elif [ -f "$1/__openerp__.py" ] || [ -f "$1/__odoo__.py" ] || [ -f "$1/__terp__.py" ]; then
        return 0;
    else
        return 1;
    fi
}


# Load project configuration. No args prowided
function load_project_conf {
    local project_conf=`search_file_up $WORKDIR $CONF_FILE_NAME`;
    if [ -f "$project_conf" ] && [ ! "$project_conf" == "$HOME/odoo-helper.conf" ]; then
        echov -e "${LBLUEC}Loading conf${NC}: $project_conf";
        source $project_conf;
    fi

    if [ -z $PROJECT_ROOT_DIR ]; then
        echo -e "${REDC}WARNING: no project config file found${NC}";
    fi
}

# with_sudo <args>
# Run command with sudo if required
function with_sudo {
    if [[ $UID != 0 ]]; then
        sudo $@;
    else
        $@
    fi
}

# Join arguments useing arg $1 as separator
# join_by , a "b c" d -> a,b c,d
# origin: http://stackoverflow.com/questions/1527049/bash-join-elements-of-an-array#answer-17841619
function join_by {
    local IFS="$1";
    shift;
    echo "$*";
}
