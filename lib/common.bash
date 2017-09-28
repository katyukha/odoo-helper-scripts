
set -e; # fail on errors

# Odoo-helper mark that common module is imported
ODOO_HELPER_COMMON_IMPORTED=1;

declare -A ODOO_HELPER_IMPORTED_MODULES;
ODOO_HELPER_IMPORTED_MODULES[common]=1

# Define version number
ODOO_HELPER_VERSION="0.1.2-dev";
ODOO_HELPER_CONFIG_VERSION="1";

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
        echo -e "It could be installed by installing package *expect-dev*";
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

# Exec command with specified odoo config
# This function automaticaly set's and unsets Odoo configuration variables
#
# exec_conf <conf> <cmd> <cmd args>
function exec_conf {
    local conf=$1; shift;
    OPENERP_SERVER="$conf" ODOO_RC="$conf" $@;
}

# Exec pip for this project. Also adds OCA wheelhouse to pip FINDLINKS list
function exec_pip {
    local extra_index="$PIP_EXTRA_INDEX_URL https://wheelhouse.odoo-community.org/oca-simple";
    PIP_EXTRA_INDEX_URL=$extra_index execv pip $@;
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
            echo "$(execv command -v $test_cmd)";
            return 0;
        fi;
    done
    return 1;
}


# echov $@
# echo if verbose is on
function echov {
    if [ ! -z "$VERBOSE" ]; then
        echoe $@;
    fi
}

# echoe $@
# echo to STDERR
function echoe {
    >&2 echo $@;
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
    < /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-8};
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

# is_odoo_module <module_path>
function is_odoo_module {
    if [ ! -d $1 ]; then
       return 1;
    elif [ -f "$1/__manifest__.py" ]; then
        # Odoo 10.0+
        return 0;
    elif [ -f "$1/__openerp__.py" ]; then
        # Odoo 6.0 - 9.0
        return 0;
    else
        return 1;
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

# Run python code
#
# run_python_cmd <code>
function run_python_cmd {
    local python_cmd="import sys; sys.path.append('$ODOO_HELPER_LIB/pylib');";
    python_cmd="$python_cmd $1";
    execu python -c "\"$python_cmd\"";
}
