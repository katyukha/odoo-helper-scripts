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


# tr_parse_addons <db> <addon1> <addon2> <addon3> ...
# tr_parse_addons <db> all
function tr_parse_addons {
    local db=$1; shift;
    if [ "$1" == "all" ]; then
        addons_get_installed_addons $db;
    else
        local addons="$1"; shift;
        while [[ $# -gt 0 ]]; do  # while there at least one argumet left
            addons="$addons,$1";
            shift;
        done
        echo "$addons";
    fi;
}


# tr_import_export_internal <db> <lang> <filename> <extra_options> <export|import> <addons>
# note, <extra_options> may be string with one space (empty)
function tr_import_export_internal {
    local db=$1;
    local lang=$2;
    local file_name=$3;
    local extra_opt=$4;
    local cmd=$5;
    shift; shift; shift; shift; shift;

    local addons_data=$(tr_parse_addons $db $@)
    local addons=;
    IFS=',' read -r -a addons <<< "$addons_data";
    for addon in ${addons[@]}; do
        echo -e "${BLUEC}Executing '$cmd' for (db='$db', lang='$lang').${NC} Processing addon: '$addon';";
        local addon_path=$(addons_get_addon_path $addon);
        local i18n_dir=$addon_path/i18n;
        if [ ! -d $i18n_dir ]; then
            mkdir -p $i18n_dir;
        fi
        odoo_py -d $db -l $lang $extra_opt --i18n-$cmd=$i18n_dir/$file_name.po --modules=$addon;
    done
}


function tr_export {
    local db=$1;
    local lang=$2;
    local file_name=$3;
    shift; shift; shift;

    tr_import_export_internal $db $lang $file_name " " export "$@";
}

function tr_import {
    # take care about 'overwrite' option
    if [ "$1" == "--overwrite" ]; then
        local opt_overwrite=" --i18n-overwrite ";
        shift;
    else
        local opt_overwrite="  ";
    fi

    local db=$1;
    local lang=$2;
    local file_name=$3;
    shift; shift; shift;

    tr_import_export_internal $db $lang $file_name "$opt_overwrite" import "$@";
}

function tr_load {
    local db=$1;
    local lang=$2;

    odoo_py -d $db --load-language=$lang --stop-after-init;
}

function tr_main {
    local usage="
    Usage 

        $SCRIPT_NAME tr export <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr export <db> <lang> <file_name> all
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> all
        $SCRIPT_NAME tr load <db> <lang>

    Note:
        <file_name> here is name of file to load lang from in i18n dir of addon.
        For example language 'uk_UA' is usualy placed in files named 'uk.po'
        So to deal with ukrainian translations commands should look like:

            $SCRIPT_NAME tr export <db> uk_UA uk <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr export <db> uk_UA uk all
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk all
            $SCRIPT_NAME tr load <db> uk_UA
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
