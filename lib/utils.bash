# Copyright © 2017-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# Odoo Helper Scripts: Utility functions

if [ -z "$ODOO_HELPER_LIB" ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z "$ODOO_HELPER_COMMON_IMPORTED" ]; then
    source "$ODOO_HELPER_LIB/common.bash";
fi


set -e; # fail on errors

ohelper_require "odoo";

# Simple function to exec command in virtual environment if required
function execv {
    if [ -n "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
        source "$VENV_DIR/bin/activate";
    fi

    # Eval command and save result
    if "$@"; then
        local res=$?;
    else
        local res=$?;
    fi

    # deactivate virtual environment
    if [ -n "$VENV_DIR" ] && [ -n "$VIRTUAL_ENV" ]; then
        deactivate;
    fi

    return $res

}

# simply pass all args to exec or unbuffer
# depending on 'USE_UNBUFFER variable
# Also take in account virtualenv
function execu {
    # Check unbuffer option
    if [ -n "$USE_UNBUFFER" ] && ! command -v unbuffer >/dev/null 2>&1; then
        echoe -e "${REDC}Command 'unbuffer' not found. Install it to use --use-unbuffer option";
        echoe -e "It could be installed via package *expect-dev*";
        echoe -e "Or by command *odoo-helper install bin-tools*";
        echoe -e "Using standard behavior${NC}";
        USE_UNBUFFER=;
    fi

    # Decide wether to use unbuffer or not
    if [ -n "$USE_UNBUFFER" ]; then
        local unbuffer_opt="unbuffer";
    else
        local unbuffer_opt="";
    fi

    execv "$unbuffer_opt" "$@";
}

# Exec command with specified odoo config
# This function automaticaly set's and unsets Odoo configuration variables
#
# exec_conf <conf> <cmd> <cmd args>
function exec_conf {
    local conf=$1; shift;
    OPENERP_SERVER="$conf" ODOO_RC="$conf" "$@";
}

# Exec pip for this project. Also adds OCA wheelhouse to pip FINDLINKS list
function exec_pip {
    exec_py -m pip "$@";
}

# Exec npm for this project
function exec_npm {
    execu npm "$@";
}


# Simple function to create directories passed as arguments
# create_dirs [dir1] [dir2] ... [dir_n]
function create_dirs {
    for dir in "$@"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir";
        fi
    done;
}


# Simple function to check if at least one command exists.
# Returns first existing command
function check_command {
    for test_cmd in "$@"; do
        if execv command -v $test_cmd >/dev/null 2>&1; then
            execv command -v "$test_cmd";
            return 0;
        fi;
    done
    return 1;
}


# echov $@
# echo if verbose is on
function echov {
    if [ -n "$VERBOSE" ]; then
        echoe "$@";
    fi
}

# echoe $@
# echo to STDERR
function echoe {
    >&2 echo "$@";
}

# check if process is running
# is_process_running <pid>
function is_process_running {
    kill -0 "$1" >/dev/null 2>&1;
    return "$?";
}

# random_string [length]
# default length = 8
function random_string {
    < /dev/urandom tr -dc A-Za-z0-9 | head -c"${1:-8}";
}

# search_file_up <start path> <file name>
# Try to find file in start_path, if found, print path, if not found,
# then try to find it in parent directory recursively
function search_file_up {
    local search_path;
    search_path=$(readlink -f "$1");
    while [[ "$search_path" != "/" ]];
    do
        if [ -e "$search_path/$2" ]; then
            echo "$search_path/$2";
            return 0;
        elif [ -n "$search_path" ] && [ "$search_path" != "/" ]; then
            search_path=$(dirname "$search_path");
        else
            break;
        fi
    done
}

# Try to find file in one of directories specified
# search_file_in <file_name> <dir1> [dir2] [dir3] ...
function search_file_in {
    local search_path;
    local file_name=$1;
    shift;  # skip first argument
    while [[ $# -gt 0 ]]  # while there at least one argumet left
    do
        search_path=$(readlink -f "$1");
        if [ -e "$search_path/$file_name" ]; then
            echo "$search_path/$file_name";
            return 0;
        fi
        shift
    done
}

# is_odoo_module <module_path>
function is_odoo_module {
    if [ ! -d "$1" ]; then
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
    if [[ "$UID" != 0 ]]; then
        sudo -E "$@";
    else
        "$@";
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

# Trim leading and trailing whitespaces
# https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable#answer-3352015
function trim {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Exec python
#
function exec_py {
    local python_exec;
    python_exec=$(odoo_get_python_interpreter);
    execv "$python_exec" "$@";
}

# Exec python with server user (if provided)
function exec_py_u {
    local python_exec;
    local current_user;
    python_exec=$(odoo_get_python_interpreter);
    current_user=$(whoami);
    if [ -n "$SERVER_RUN_USER" ] && [ "$SERVER_RUN_USER" != "$current_user" ]; then
        execv sudo -u "$SERVER_RUN_USER" -H -E "$python_exec" "$@";
    else
        execv "$python_exec" "$@";
    fi

}

# Shortcut to exec lodoo command
function exec_lodoo {
    exec_py "${ODOO_HELPER_LIB}/pylib/lodoo.py" "$@";
}
function exec_lodoo_u {
    exec_py_u "${ODOO_HELPER_LIB}/pylib/lodoo.py" "$@";
}


function run_python_cmd_prepare {
    local cmd="
import sys

sys.path.append('$ODOO_HELPER_LIB/pylib')

try:
    $1
except SystemExit:
    raise
except Exception:
    import traceback
    traceback.print_exc(file=sys.stderr)
    sys.exit(1)
";
    echo "$cmd";
}

# Run python code
#
# run_python_cmd <code>
function run_python_cmd {
    local python_cmdl
    python_cmd=$(run_python_cmd_prepare "$1");
    exec_py -c "\"$python_cmd\"";
}

# Run python code as server user (if provided)
#
# run_python_cmd <code>
function run_python_cmd_u {
    local python_cmd;
    python_cmd=$(run_python_cmd_prepare "$@");
    exec_py_u -c "\"$python_cmd\"";
}


# Check that version1 is greater or equal than version2
#
# version_cmp_gte <version1> <version2>
function version_cmp_gte {
    exec_py -c "\"from pkg_resources import parse_version as V; exit(not bool(V('$1') >= V('$2')));\"";
}
