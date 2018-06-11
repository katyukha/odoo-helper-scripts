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


# system entry point
function system_entry_point {
    local usage="Usage:

        $SCRIPT_NAME system update [branch]      - update odoo-helper-scripts (to specified branch / commit)
        $SCRIPT_NAME system lib-path <lib name>  - print path to lib with specified name
        $SCRIPT_NAME system --help              - show this help message

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
