# Translation wrappers


if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

ohelper_require "addons";
ohelper_require "server";
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


function tr_export {
    local db=$1;
    local lang=$2;
    shift; shift;

    
    while [[ $# -gt 0 ]]  # while there at least one argumet left
    do
        local addon=$1;
        local addon_path=$(addons_get_addon_path $addon);
        local i18n_dir=$addon_path/i18n;
        if [ ! -d $i18n_dir ]; then
            mkdir -p $i18n_dir;
        fi
        odoo_py -d $db -l $lang --i18n-export=$i18n_dir/$lang.po --modules=$addon;
        shift
    done
}

function tr_import {
    # take care about 'overwrite' option
    if [ "$1" == "--overwrite" ]; then
        local opt_overwrite=" --i18n-overwrite ";
        shift;
    fi

    local db=$1;
    local lang=$2;
    shift; shift;

    
    while [[ $# -gt 0 ]]  # while there at least one argumet left
    do
        local addon=$1;
        local addon_path=$(addons_get_addon_path $addon);
        odoo_py -d $db -l $lang $opt_overwrite --i18n-import=$addon_path/i18n/$lang.po --modules=$addon;
        shift
    done
}

function tr_load {
    local db=$1;
    local lang=$2;

    odoo_py -d $db --load-language=$lang --stop-after-init;
}

function tr_main {
    local usage="
    Usage 

        $SCRIPT_NAME tr export <db> <lang> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr load <db> <lang>
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            export)
                shift;
                tr_export "$@";
                exit;
            ;;
            import)
                shift;
                tr_import "$@";
                exit;
            ;;
            load)
                shift;
                tr_load "$@";
                exit;
            ;;
            *)
                echo "Unknown option / command $key";
                exit 1;
            ;;
        esac
        shift
    done
}
