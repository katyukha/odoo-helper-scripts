if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
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
            if [ "$base_path" == /opt* ]; then
                with_sudo ln -s $oh_cmd /usr/local/bin/;
            elif [ "$base_path" == $HOME/* ]; then
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
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            update)
                shift;
                system_update_odoo_helper_scripts "$@";
                exit 0;
            ;;
            lib-path)
                shift;
                oh_get_lib_path "$@"
                exit 0;
            ;;
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            *)
                echo "Unknown option / command $key";
                exit 1;
            ;;
        esac
        shift
    done
}
