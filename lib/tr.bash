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
ohelper_require "db";
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# Parses database name and returns single database or all databases
# if dbname is __all__ then echoes all databases present on server
# else echoes database name
function tr_parse_db_name {
    local dbname=$1;
    if [ "$dbname" == "__all__" ]; then
        odoo_db_list;
    else
        echo "$dbname";
    fi
}

# tr_parse_addons <db> <addon1> <addon2> <addon3> ...
# tr_parse_addons <db> all
function tr_parse_addons {
    local db=$1; shift;
    if [ "$1" == "all" ]; then
        addons_get_installed_addons $db;
    else
        local installed_addons="$(addons_get_installed_addons $db)"
        local addons=;
        while [[ $# -gt 0 ]]; do  # while there at least one argumet left
            if [[ "$1" =~ ^--dir=(.*)$ ]]; then
                addons="$addons $(join_by ' '  $(addons_list_in_directory_by_name ${BASH_REMATCH[1]}))";
            else
                addons="$addons $1";
            fi
            shift;
        done
        local todo_addons="$(join_by , $addons)";
        echo $(execv python -c "\"print(','.join(set('$todo_addons'.split(',')) & set('$installed_addons'.split(','))))\"");
    fi;
}


# tr_import_export_internal <db> <lang> <filename> <extra_options> <export|import> <addons>
# note, <extra_options> may be string with one space (empty)
function tr_import_export_internal {
    if [[ $# -lt 6 ]]; then
        echoe -e "${REDC}ERROR:${NC} No all arguments passed to translations export/import";
        return 1;
    fi

    local db=$1;
    local lang=$2;
    local file_name=$3;
    local extra_opt=$4;
    local cmd=$5;
    shift; shift; shift; shift; shift;

    if ! odoo_db_exists -q $db; then
        echoe -e "${REDC}ERROR:${NC} Database '$db' does not exists!";
        return 2;
    fi

    local addons_data=$(tr_parse_addons $db $@)
    local addons=;
    IFS=',' read -r -a addons <<< "$addons_data";
    for addon in ${addons[@]}; do
        echoe -e "${BLUEC}Executing ${YELLOWC}$cmd${BLUEC} for (db=${YELLOWC}$db${BLUEC}, lang=${YELLOWC}$lang${BLUEC}).${NC} Processing addon: ${YELLOWC}$addon${NC};";
        local addon_path=$(addons_get_addon_path $addon);
        local i18n_dir=$addon_path/i18n;
        local i18n_file=$i18n_dir/$file_name.po

        # if export and there is no i18n dir, create it
        if [ "$cmd" == "export" ] && [ ! -d $i18n_dir ]; then
            mkdir -p $i18n_dir;
        fi

        # if import and not translation file skip this addon
        if [ "$cmd" == "import" ] && [ ! -f $i18n_file ]; then
            continue
        fi

        # do the work
        server_run -d $db -l $lang $extra_opt --i18n-$cmd=$i18n_file --modules=$addon;
    done
}

function tr_export {
    local usage="
    Usage

        $SCRIPT_NAME tr export <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr export <db> <lang> <file_name> all

    Export translations to specified files for specified lang from specified db
    This script exports trnaslations for addons and usualy used to update *.po files
    and add there new translation terms

    Options:

        --help         - show this help message

    Arguments:

        db        - name of database to export translations from.
        lang      - language to export translations for.
                    Usualy it looks like en_UA or uk_UA or ru_RU, etc
        file name - name of trnaslation files to export translations to.
                    Odoo have two types of translation file name.
                    One is named like short lang code, and other as full lang code.
                    For example: uk.po and uk_UA.po
                    Full code is prioritized.
        addonN    - name of addon to export transaltions for.
                    it is possible to specify 'all' name of addon, in this case
                    translations will be updated for all installed addons.
    ";
    if [[ "$1" =~ -h|--help|help ]]; then
        echo "$usage";
        exit 0;
    fi

    local db=$1;
    local lang=$2;
    local file_name=$3;
    shift; shift; shift;

    tr_import_export_internal $db $lang $file_name " " export "$@";
}

function tr_import {
    local usage="
    Usage

        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> all
        $SCRIPT_NAME tr import [--overwrite] __all__ <lang> <file_name> <addon1> [addon2] [addon3]...

    Import translations from specified files for specified lang to specified db
    This script imports trnaslations from addons and usualy used to update translations
    in databases when there some *.po files have changed.

    Options:

        --overwrite    - if set, the existing translations will be overridden
        --help         - show this help message

    Arguments:

        db        - name of database to import translations in.
                    if set to __all__, then translations will be imported to all databases
                    available for this odoo instance
        lang      - language to import translations for.
                    Usualy it looks like en_UA or uk_UA or ru_RU, etc
        file name - name of trnaslation files to import translations from.
                    Odoo have two types of translation file name.
                    One is named like short lang code, and other as full lang code.
                    For example: uk.po and uk_UA.po
                    Full code is prioritized.
        addonN    - name of addon to import transaltions from.
                    it is possible to specify 'all' name of addon, in this case
                    translations will be updated for all installed addons.
    ";
    
    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            --overwrite)
                local opt_overwrite=" --i18n-overwrite ";
                shift;
            ;;
            *)
                break;
            ;;
        esac
    done
    if [[ "$1" =~ -h|--help|help ]]; then
        echo "$usage";
        exit 0;
    fi

    local db=$1;
    local lang=$2;
    local file_name=$3;
    shift; shift; shift;

    for idb in $(tr_parse_db_name $db); do
        tr_import_export_internal $idb $lang $file_name "$opt_overwrite" import "$@";
    done
}

function tr_load {
    local usage="
    Usage

        $SCRIPT_NAME tr load [optiona]

    Load language to database.

    Options:

        --lang         - language to load.
                         Usualy it looks like en_UA or uk_UA or ru_RU, etc
        --db           - name of database to load language for.
        --all-db       - load language to all databases
        --help         - show this help message

    ";

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --lang)
                local lang=$2;
                shift;
            ;;
            --db)
                local db=$2;
                shift;
            ;;
            --all-db)
                local db=__all__;
            ;;
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    if [ -z $db ] || [ -z $lang ]; then
        echo -e "${REDC}ERROR:${NC} No database or language specified!";
        return 1;
    fi

    for idb in $(tr_parse_db_name $db); do
        server_run -d $idb --load-language=$lang --stop-after-init;
    done
}


# Regenerate translations
function tr_regenerate {
    local lang=;
    local file_name=;
    local addons="";

    local usage="
    Usage

        $SCRIPT_NAME tr regenerate --lang <lang> --file <file> <addon1> [addon2] [addon3] ...

    Options

        --lang <lang code>    - language code to regenerate translations for
        --file <filename>     - name of po file in i18n dir of addons to generate

    this command automaticaly creates new temporary database with specified lang
    and demo_data, installs there specified list of addons
    end exports translations for specified addons
    ";

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            --lang)
                lang=$2;
                shift;
            ;;
            --file)
                file_name=$2;
                shift;
            ;;
            *)
                addons="$addons $key";
            ;;
        esac
        shift
    done

    # Create temporary database
    local tmp_db_name=$(random_string 24);
    odoo_db_create --lang $lang --demo $tmp_db_name;
    
    # install addons
    if addons_install_update "install" --no-restart -d $tmp_db_name $addons; then
        # export translations
        tr_export $tmp_db_name $lang $file_name $addons;
    fi

    # Drop temporary database
    odoo_db_drop $tmp_db_name;

}

function tr_main {
    local usage="
    Usage

        $SCRIPT_NAME tr export <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr export <db> <lang> <file_name> all
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> all
        $SCRIPT_NAME tr load --help
        $SCRIPT_NAME tr regenerate --help

    Note:
        <file_name> here is name of file to load lang from in i18n dir of addon.
        For example language 'uk_UA' is usualy placed in files named 'uk.po'
        So to deal with ukrainian translations commands should look like:

            $SCRIPT_NAME tr export <db> uk_UA uk <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr export <db> uk_UA uk all
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk --dir=/addons/dir --dir=/addons/dir2 [addon3]...
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk all

    Note2:
        Also it is possible to call *tr import* and *tr load* commands
        for all databases this server manages. if db name passed as arg is __all__

        For example:
            $SCRIPT_NAME tr import [--overwrite] __all__ <lang> <file_name> <addon1> [addon2] [addon3]...
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
            regenerate)
                shift;
                tr_regenerate $@;
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
