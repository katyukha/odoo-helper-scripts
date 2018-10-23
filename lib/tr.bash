# Copyright © 2016-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# Translation wrappers


if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
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
                addons="$addons $(join_by ' '  $(addons_list_in_directory --installable --by-name ${BASH_REMATCH[1]}))";
            elif [[ "$1" =~ ^--dir-r=(.*)$ ]]; then
                addons="$addons $(join_by ' '  $(addons_list_in_directory --installable --recursive --by-name ${BASH_REMATCH[1]}))";
            else
                if addons_is_odoo_addon "$1"; then
                    addons="$addons $1";
                else
                    echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${1}${NC} is not Odoo addon! Skipped...";
                fi
            fi
            shift;
        done
        local todo_addons="$(join_by , $addons)";
        echo $(run_python_cmd "print(','.join(set('$todo_addons'.split(',')) & set('$installed_addons'.split(','))))");
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
        server_run -- -d $db -l $lang $extra_opt --i18n-$cmd=$i18n_file --modules=$addon;
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
        return 0;
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
                return 0;
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
        return 0;
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
                return 0;
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
        server_run -- -d $idb --load-language=$lang --stop-after-init;
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
        --dir  <addons path>  - look for addons at specified directory
        --dir-r <addons path> - look for addons at specified directory and its subdirectories

    Examples

        $SCRIPT_NAME tr regenerate --lang uk_UA --file uk project product
        $SCRIPT_NAME tr regenerate --lang ru_RU --file ru project product

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
                return 0;
            ;;
            --lang)
                lang=$2;
                shift;
            ;;
            --file)
                file_name=$2;
                shift;
            ;;
            --dir)
                addons="$addons $(addons_list_in_directory --by-name --installable $2)";
                shift;
            ;;
            --dir-r)
                addons="$addons $(addons_list_in_directory --by-name --installable --recursive $2)";
                shift;
            ;;
            *)
                addons="$addons $key";
            ;;
        esac
        shift
    done

    if [ -z "$lang" ]; then
        echoe -e "${REDC}ERROR${NC}: argument 'lang' is required!";
        return 1;
    fi

    if [ -z "$file_name" ]; then
        echoe -e "${REDC}ERROR${NC}: argument 'file' is required!";
        return 2;
    fi

    # Create temporary database
    local tmp_db_name="test-tr-$(random_string 24)";
    odoo_db_create --lang $lang --demo $tmp_db_name;
    
    # install addons
    if addons_install_update "install" --no-restart -d $tmp_db_name $addons; then
        # export translations
        tr_export $tmp_db_name $lang $file_name $addons;
    fi

    # Drop temporary database
    odoo_db_drop $tmp_db_name;

}

# Compute and print translation rate
function tr_translation_rate {
    local lang=;
    local min_total_rate="None";
    local min_addon_rate="None";
    local addons="";
    local res=0;

    local usage="
    Usage

        $SCRIPT_NAME tr rate --lang <lang> <addon1> [addon2] [addon3] ...

    Options

        --lang <lang code>       - language code to regenerate translations for
        --min-total-rate <rate>  - minimal translation rate to pass. (optional)
        --min-addon-rate <rate>  - minimal translation rate per addon. (optional)
        --dir  <addons path>     - look for addons at specified directory
        --dir-r <addons path> - look for addons at specified directory and its subdirectories

    compute translation rate for specified langauage and addons
    ";

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --lang)
                lang=$2;
                shift;
            ;;
            --min-total-rate)
                min_total_rate=$2;
                shift;
            ;;
            --min-addon-rate)
                min_addon_rate=$2;
                shift;
            ;;
            --dir)
                addons="$addons $(addons_list_in_directory --by-name --installable $2)";
                shift;
            ;;
            --dir-r)
                addons="$addons $(addons_list_in_directory --by-name --installable --recursive $2)";
                shift;
            ;;
            *)
                addons="$addons $key";
            ;;
        esac
        shift
    done

    # Create temporary database
    local tmp_db_name="test-tr-$(random_string 24)";
    odoo_db_create --lang $lang --demo $tmp_db_name;

    local addons_cs=$(join_by , $addons);  # coma-separated
    # install addons
    if addons_install_update "install" --no-restart -d $tmp_db_name $addons; then
        # export translations to dev-null, to create records in 'ir.translation'
        local trans_tmp_dir=$ODOO_PATH/addons/tmp;
        mkdir -p $trans_tmp_dir;
        local trans_file=$trans_tmp_dir/x-odoo-trans-${tmp_db_name}.po;
        if server_run -- -d $tmp_db_name -l $lang --i18n-export=$trans_file --modules=$addons_cs; then
            if ! server_run -- -d $tmp_db_name -l $lang --i18n-import=$trans_file --modules=$addons_cs; then
                echoe -e "${REDC}ERROR${NC}: cannot import generated translations";
                rm $trans_file;
                res=11;
            else
                rm $trans_file;

                # Compute translation rate and print it
                local python_cmd="import lodoo; db=lodoo.LocalClient(['-c', '$ODOO_CONF_FILE'])['$tmp_db_name'];";
                python_cmd="$python_cmd trans_rate = db.compute_translation_rate('$lang', '$addons_cs'.split(','));";
                python_cmd="$python_cmd db.print_translation_rate(trans_rate);";
                python_cmd="$python_cmd exit_code = db.assert_translation_rate(trans_rate, min_total_rate=$min_total_rate, min_addon_rate=$min_addon_rate);";
                python_cmd="$python_cmd exit(exit_code);";

                if ! run_python_cmd "$python_cmd"; then
                    res=1;
                fi
            fi
        else
            echoe -e "${REDC}ERROR${NC}: Cannot export translations!";
            res=12;
        fi
    else
        echoe -e "${REDC}ERROR${NC}: Cannot install addons: $addons";
        res=13;
    fi

    # Drop temporary database
    odoo_db_drop $tmp_db_name;

    return $res;
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
        $SCRIPT_NAME tr rate --help

    Note:
        <file_name> here is name of file to load lang from in i18n dir of addon.
        For example language 'uk_UA' is usualy placed in files named 'uk.po'
        So to deal with ukrainian translations commands should look like:

            $SCRIPT_NAME tr export <db> uk_UA uk <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr export <db> uk_UA uk all
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk --dir=/addons/dir --dir-r=/addons/dir2 [addon3]...
            $SCRIPT_NAME tr import [--overwrite] <db> uk_UA uk all

    Note2:
        Also it is possible to call *tr import* and *tr load* commands
        for all databases this server manages. if db name passed as arg is __all__

        For example:
            $SCRIPT_NAME tr import [--overwrite] __all__ <lang> <file_name> <addon1> [addon2] [addon3]...
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            export)
                shift;
                tr_export "$@";
                return;
            ;;
            import)
                shift;
                tr_import "$@";
                return;
            ;;
            load)
                shift;
                tr_load "$@";
                return;
            ;;
            regenerate)
                shift;
                tr_regenerate $@;
                return;
            ;;
            rate)
                shift;
                tr_translation_rate $@;
                return $?;
            ;;
            *)
                echo "Unknown option / command $key";
                return 1;
            ;;
        esac
        shift
    done
}
