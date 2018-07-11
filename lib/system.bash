# Copyright © 2017-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------
#ohelper_require "postgres";


set -e; # fail on errors

# update odoo-helper-scripts
function system_update_odoo_helper_scripts {
    local scripts_branch=$1;

    if ! git_is_git_repo "$ODOO_HELPER_ROOT"; then
        echoe -e "${REDC}ERROR${NC} this action is not available for non-git installs";
        return 1
    fi

    # update
    local cdir=$(pwd);
    cd $ODOO_HELPER_ROOT;
    if [ -z $scripts_branch ]; then
        # TODO: if there is no configured branch to pull from, git shows
        #       message, that it does not know from where to pull
        git pull;
    else
        git fetch -q origin;
        if ! git checkout -q origin/$scripts_branch; then
            git checkout -q $scripts_branch;
        fi
    fi

    # update odoo-helper bin links
    local base_path=$(dirname $ODOO_HELPER_ROOT);
    for oh_cmd in $ODOO_HELPER_BIN/*; do
        if ! command -v $(basename $oh_cmd) >/dev/null 2>&1; then
            if [[ "$base_path" == /opt* ]]; then
                with_sudo ln -s $oh_cmd /usr/local/bin/;
            elif [[ "$base_path" == $HOME/* ]]; then
                ln -s $oh_cmd $HOME/bin;
            fi
        fi
    done
    cd $cdir;
}

# Check if specified directory or current directory is odoo-hleper project
function system_is_odoo_helper_project {
    local dir_name="$(readlink -f ${1:-$(pwd)})";
    local save_dir=$(pwd);

    if [ ! -d "$dir_name" ]; then
        echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${dir_name}${NC} does not exists or is not a directory!";
        return 2;
    fi

    cd $dir_name;
    config_load_project 2>/dev/null;
    cd $save_dir;
    if [ -z $PROJECT_ROOT_DIR ]; then
        return 1;
    else
        return 0;
    fi
}

# Return odoo-helper path to virtualenv directory
function system_get_venv_dir {
    local dir_name="$(readlink -f ${1:-$(pwd)})";
    local save_dir=$(pwd);

    if [ ! -d "$dir_name" ]; then
        echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${dir_name}${NC} does not exists or is not a directory!";
        return 2;
    fi

    cd $dir_name;
    config_load_project 2>/dev/null;
    cd $save_dir;
    if [ ! -z $PROJECT_ROOT_DIR ]; then
        echo "${VENV_DIR}";
    else
        echoe -e "${REDC}ERROR${NC}: directory ${YELLOWC}${dir_name}${NC} is not under odoo-helper project";
        return 1;
    fi
}


# system entry point
function system_entry_point {
    local usage="Usage:

        $SCRIPT_NAME system update [branch]        - update odoo-helper-scripts (to specified branch / commit)
        $SCRIPT_NAME system lib-path <lib name>    - print path to lib with specified name
        $SCRIPT_NAME system is-project [path]      - check if specified dir is odoo-helper project
                                                     if dirname is not specified then current dir checked
        $SCRIPT_NAME system get-venv-dir [path]    - if path is part of odoo-helper project than print path
                                                     to virtualenv directory for this project.
                                                     if path is not specified, then current working directory
                                                     is used instead
        $SCRIPT_NAME system --help                 - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            update)
                shift;
                system_update_odoo_helper_scripts "$@";
                return;
            ;;
            lib-path)
                shift;
                oh_get_lib_path "$@"
                return;
            ;;
            is-project)
                shift;
                system_is_odoo_helper_project $@;
                return
            ;;
            get-venv-dir)
                shift;
                system_get_venv_dir $@;
                return;
            ;;
            -h|--help|help)
                echo "$usage";
                return;
            ;;
            *)
                echo "Unknown option / command $key";
                return 1;
            ;;
        esac
        shift
    done
}
