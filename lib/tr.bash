# Copyright © 2016-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>
#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# Translation wrappers


if [ -z "$ODOO_HELPER_LIB" ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z "$ODOO_HELPER_COMMON_IMPORTED" ]; then
    source "$ODOO_HELPER_LIB/common.bash";
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
# Prints comma-separated list of addons
function tr_parse_addons {
    local db=$1; shift;
    local todo_addons;
    local installed_addons;
    local installed_addons_cs;
    local addons_list;

    mapfile -t installed_addons < <(postgres_psql -d "$db" -tA -c "SELECT name FROM ir_module_module WHERE state = 'installed'");
    installed_addons_cs=$(join_by , "${installed_addons[@]}");
    if [ "$1" == "all" ]; then
        echo "$installed_addons_cs";
    else
        declare -a addons;
        while [[ $# -gt 0 ]]; do  # while there at least one argumet left
            if [[ "$1" =~ ^--dir=(.*)$ ]]; then
                mapfile -t addons_list < <(addons_list_in_directory --installable --by-name "${BASH_REMATCH[1]}");
                addons+=( "${addons_list[@]}" );
            elif [[ "$1" =~ ^--dir-r=(.*)$ ]]; then
                mapfile -t addons_list < <(addons_list_in_directory --installable --recursive --by-name "${BASH_REMATCH[1]}");
                addons+=( "${addons_list[@]}" );
            else
                if addons_is_odoo_addon "$1"; then
                    addons+=( "$1" );
                else
                    echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${1}${NC} is not Odoo addon! Skipped...";
                fi
            fi
            shift;
        done
        todo_addons=$(join_by , "${addons[@]}");
        exec_py -c "print(','.join(set('$todo_addons'.split(',')) & set('$installed_addons_cs'.split(','))))";
    fi;
}


# tr_import_export_internal [options] <db> <lang> <filename> <export|import> <addons>
function tr_import_export_internal {
    local missing_only;
    local extra_opts=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --missing-only)
                local missing_only=1;
            ;;
            --pot-update)
                local pot_update=1;
            ;;
            --i18n-overwrite)
                local extra_opts+=( --i18n-overwrite );
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    if [[ $# -lt 6 ]]; then
        echoe -e "${REDC}ERROR:${NC} No all arguments passed to translations export/import";
        return 1;
    fi

    local db=$1;
    local lang=$2;
    local file_name=$3;
    local cmd=$4;
    local addon_path;
    shift; shift; shift; shift; shift;

    if [ "$cmd" != "export" ] && [ "$cmd" != "import" ]; then
        echoe -e "${REDC}ERROR${NC}: Unknown command '${YELLOWC}${cmd}${NC}'!";
        return 3
    fi

    if ! odoo_db_exists -q "$db"; then
        echoe -e "${REDC}ERROR:${NC} Database '$db' does not exists!";
        return 2;
    fi

    local addons;
    local addons_data;
    addons_data=$(tr_parse_addons "$db" "$@")
    IFS=',' read -r -a addons <<< "$addons_data";
    for addon in "${addons[@]}"; do
        echoe -e "${BLUEC}Executing ${YELLOWC}$cmd${BLUEC} for (db=${YELLOWC}$db${BLUEC}, lang=${YELLOWC}$lang${BLUEC}).${NC} Processing addon: ${YELLOWC}$addon${NC};";
        addon_path=$(addons_get_addon_path "$addon");
        local i18n_dir="$addon_path/i18n";
        local i18n_file="$i18n_dir/$file_name.po";
        local i18n_pot_file="$i18n_dir/$addon.pot";

        # if export and there is no i18n dir, create it
        if [ "$cmd" == "export" ] && [ ! -d "$i18n_dir" ]; then
            mkdir -p "$i18n_dir";
        fi

        # if import and not translation file skip this addon
        if [ "$cmd" == "import" ] && [ ! -f "$i18n_file" ]; then
            echoe -e "${YELLOWC}WARNING${NC}: translation file ${BLUEC}${i18n_file}${NC} does not exists. Skipping translation ${BLUEC}${lang}${NC} import for module ${BLUEC}${addon}${NC}";
            continue;
        fi

        # do not export overwrite translations if export and missing_only and file already exists
        if [ "$cmd" == "export" ] && [ -n "$missing_only" ] && [ -f "$i18n_file" ] && [ -n "$pot_update" ] && [ -f "$i18n_pot_file" ]; then
            echoe -e "${BLUEC}INFO${NC}: translation file ${BLUEC}${i18n_file}${NC} already exists. Updating translations based on .pot file.";
            execv msgmerge --quiet -N -U "$i18n_file" "$i18n_pot_file";
            continue;
        elif [ "$cmd" == "export" ] && [ -n "$missing_only" ] && [ -f "$i18n_file" ]; then
            echoe -e "${YELLOWC}WARNING${NC}: translation file ${BLUEC}${i18n_file}${NC} already exists and ${BLUEC}--missing-only${NC} option enabled. Skipping translation ${BLUEC}${lang}${NC} export for module ${BLUEC}${addon}${NC}";
            continue;
        fi

        # do the work
        server_run -- -d "$db" -l "$lang" "${extra_opts[@]}" "--i18n-$cmd=$i18n_file" "--modules=$addon" --stop-after-init --pidfile=/dev/null;
    done
}


# tr_generate_pot <db> <addon1> [addon2] [addonN]
function tr_generate_pot {
    local usage="
        Usage

            $SCRIPT_NAME tr generate-pot [options] <db> <addon1> [addon2] [addon3]...
            $SCRIPT_NAME tr generate-pot [options] <db>

        Regenerate .pot files for specified modules

        Options:
            --remove-dates  - remove dates from .pot files
            --help          - show this help message

        Arguments:

            db        - name of database to regenerate translations.
            addonN    - name of addon to regenerate transaltions for.
    ";
    local extra_opts=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --remove-dates)
                extra_opts+=( --remove-dates );
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

    if [[ $# -lt 2 ]]; then
        echoe -e "${REDC}ERROR:${NC} No all arguments passed to generation of POT files";
        return 1;
    fi

    local db=$1;
    shift;

    if ! odoo_db_exists -q "$db"; then
        echoe -e "${REDC}ERROR:${NC} Database '$db' does not exists!";
        return 2;
    fi

    local addons;
    local addons_data;
    addons_data=$(tr_parse_addons "$db" "$@")
    IFS=',' read -r -a addons <<< "$addons_data";
    for addon in "${addons[@]}"; do
        echoe -e "${BLUEC}Executing ${YELLOWC}generate .pot file${BLUEC} for (db=${YELLOWC}$db${BLUEC}).${NC} Processing addon: ${YELLOWC}$addon${NC};";
        if ! exec_lodoo_u --conf="$ODOO_CONF_FILE" tr-generate-pot-file "${extra_opts[@]}" "$db" "$addon"; then
            echoe -e "${REDC}ERROR${NC}: Cannot generate pot file!";
            return 1;
        else
            echoe -e "${GREENC}OK${NC}: .pot file for module ${YELLOWC}${addon}${NC} generated!";
        fi
    done
}

function tr_export {
    local usage="
    Usage

        $SCRIPT_NAME tr export [options] <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr export [options] <db> <lang> <file_name> all

    Export translations to specified files for specified lang from specified db
    This script exports trnaslations for addons and usualy used to update *.po files
    and add there new translation terms

    Options:

        --missing-only  - export only missing translations
                          (do not overwrite files)
        --pot-update    - if translation already exists and --missing-only enabled
                          then instead of regenerating translation only update
                          translations of based on .pot file.
        --help          - show this help message

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
    local extra_opts=();
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --missing-only)
                extra_opts+=( "--missing-only" );
            ;;
            --pot-update)
                extra_opts+=( "--pot-update" );
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

    local db=$1;
    local lang=$2;
    local file_name=$3;
    shift; shift; shift;

    tr_import_export_internal "${extra_opts[@]}" "$db" "$lang" "$file_name" export "$@";
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

    local extra_opts=( );
    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --overwrite)
                extra_opts+=( --i18n-overwrite );
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

    for idb in $(tr_parse_db_name "$db"); do
        tr_import_export_internal "${extra_opts[@]}" "$idb" "$lang" "$file_name" import "$@";
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

    if [ -z "$db" ] || [ -z "$lang" ]; then
        echo -e "${REDC}ERROR:${NC} No database or language specified!";
        return 1;
    fi

    for idb in $(tr_parse_db_name "$db"); do
        server_run -- -d "$idb" --load-language="$lang" --stop-after-init --pidfile=/dev/null;
    done
}


# Regenerate translations
function tr_regenerate {
    local lang;
    local file_name;
    local gen_pot;
    local tmp_db_name;
    declare -a addons;
    declare -a addons_list;

    local usage="
    Usage

        $SCRIPT_NAME tr regenerate --lang <lang> --file <file> <addon1> [addon2] [addon3] ...

    Options

        --lang <lang code>               - language code to regenerate translations for
        --file <filename>                - name of po file in i18n dir of addons to generate (without extension)
        --lang-file <lang_code:filename> - lang code and lang file. could be specified multiple times
        --pot                            - generate .pot file for translations
        --pot-remove-dates               - remove dates from generated .pot
        --pot-update                     - update translations based on regenerated .pot file
        --dir  <addons path>             - look for addons at specified directory
        --dir-r <addons path>            - look for addons at specified directory and its subdirectories
        --missing-only                   - regenerate only missing translation files.
                                           Do not overwrite existing translations.
                                           But does not affect the generation of .pot files
                                           (.pot file will be overwritten still)

    Examples

        $SCRIPT_NAME tr regenerate --lang uk_UA --file uk project product
        $SCRIPT_NAME tr regenerate --lang ru_RU --file ru project product
        $SCRIPT_NAME tr regenerate --lang-file uk_UA:uk --lang-file ru_RU:ru project product

    this command automaticaly creates new temporary database with specified lang
    and demo_data, installs there specified list of addons
    end exports translations for specified addons
    ";

    local langs_arr=();
    local export_extra_opts=();
    local pot_extra_opts=();

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --lang)
                if [ -n "$lang" ]; then
                    echoe -e "${REDC}ERROR${NC}: ${YELLOWC}--lang${NC} specified multiple times.";
                    return 4;
                fi
                lang=$2;
                shift;
            ;;
            --pot)
                gen_pot=1;
            ;;
            --pot-remove-dates)
                pot_extra_opts+=( "--remove-dates" );
            ;;
            --file)
                if [ -n "$file_name" ]; then
                    echoe -e "${REDC}ERROR${NC}: ${YELLOWC}--file${NC} specified multiple times.";
                    return 3;
                fi
                file_name=$2;
                shift;
            ;;
            --lang-file)
                langs_arr+=( "$2" )
                shift;
            ;;
            --dir)
                mapfile -t addons_list < <(addons_list_in_directory --installable --by-name "$2");
                addons+=( "${addons_list[@]}" );
                shift;
            ;;
            --dir-r)
                mapfile -t addons_list < <(addons_list_in_directory --installable --by-name --recursive "$2");
                addons+=( "${addons_list[@]}" );
                shift;
            ;;
            --missing-only)
                export_extra_opts+=( "--missing-only" );
            ;;
            --pot-update)
                export_extra_opts+=( "--pot-update" );
            ;;
            *)
                addons+=( "$key" );
            ;;
        esac
        shift
    done

    if [ -z "$gen_pot" ] && [ -z "$lang" ] && [ -z "${langs_arr[*]}" ]; then
        echoe -e "${REDC}ERROR${NC}: argument '--lang' or '--lang-file' is required!";
        return 1;
    fi

    if [ -z "$gen_pot" ] && [ -z "$file_name" ] && [ -z "${langs_arr[*]}" ]; then
        echoe -e "${REDC}ERROR${NC}: argument '--file' or '--lang-file' is required!";
        return 2;
    fi

    if [ -n "$lang" ] && [ -n "$file_name" ] && [ -z "${langs_arr[*]}" ]; then
        langs_arr+=( "$lang:$file_name" );
    fi

    # Create temporary database
    tmp_db_name="test-tr-$(random_string 24)";
    odoo_db_create --lang "$lang" --demo "$tmp_db_name";
    
    # install addons
    local res=0;
    if addons_install_update "install" --show-log-on-error --no-restart -d "$tmp_db_name" "${addons[@]}"; then
        if [ -n "$gen_pot" ]; then
            if ! tr_generate_pot "${pot_extra_opts[@]}" "$tmp_db_name" "${addons[@]}"; then
                res=1;
            fi
        fi
        if [ -n "${langs_arr[*]}" ]; then
            for langf in "${langs_arr[@]}"; do
                local lang_code;
                local lang_file;
                IFS=':' read -r lang_code lang_file <<< "$langf"
                if [ -z "${lang_code}" ] || [ -z "$lang_file" ]; then
                    echoe -e "${REDC}ERROR${NC}: Cannot parse ${YELLOWC}${langf}${NC}!";
                    res=1;
                    break;
                fi

                # export translations
                if ! tr_export "${export_extra_opts[@]}" "$tmp_db_name" "${lang_code}" "${lang_file}" "${addons[@]}"; then
                    res=1;
                    break
                fi
            done
        fi
    else
        echoe -e "${REDC}ERROR${NC}: Cannot install addons ${YELLOWC}${addons[*]}${NC}!";
        res=1;
    fi

    # Drop temporary database
    odoo_db_drop "$tmp_db_name";

    if [ ! "$res" -eq 0 ]; then
        return 3;
    fi
}

# Compute and print translation rate
function tr_translation_rate {
    local lang=;
    local min_total_rate="None";
    local min_addon_rate="None";
    local addons_cs;
    local tmp_db_name;
    local res=0;
    declare -a addons;
    declare -a addons_list;
    local check_tr_rate_opts=( );
    if [ "$OH_COLORS_ENABLED" -eq 1 ]; then
        check_tr_rate_opts+=( --colors );
    fi

    local usage="
    Usage

        $SCRIPT_NAME tr rate --lang <lang> <addon1> [addon2] [addon3] ...

    Options

        --lang <lang code>       - language code to regenerate translations for
        --min-total-rate <rate>  - minimal translation rate to pass. (optional)
        --min-addon-rate <rate>  - minimal translation rate per addon. (optional)
        --dir <addons path>      - look for addons at specified directory
        --dir-r <addons path>    - look for addons at specified directory and its subdirectories

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
                check_tr_rate_opts+=( --min-total-rate="$2" );
                shift;
            ;;
            --min-addon-rate)
                check_tr_rate_opts+=( --min-addon-rate="$2" );
                shift;
            ;;
            --dir)
                mapfile -t addons_list < <(addons_list_in_directory --installable --by-name "$2");
                addons+=( "${addons_list[@]}" );
                shift;
            ;;
            --dir-r)
                mapfile -t addons_list < <(addons_list_in_directory --installable --by-name --recursive "$2");
                addons+=( "${addons_list[@]}" );
                shift;
            ;;
            *)
                addons+=( "$key" );
            ;;
        esac
        shift
    done

    # Create temporary database
    tmp_db_name="test-tr-$(random_string 24)";
    odoo_db_create --lang "$lang" --demo "$tmp_db_name";

    addons_cs=$(join_by , "${addons[@]}");  # coma-separated
    # install addons
    if addons_install_update install --no-restart -d "$tmp_db_name" "${addons[@]}"; then
        # export translations to dev-null, to create records in 'ir.translation'
        local trans_tmp_dir="$ODOO_PATH/addons/tmp";
        mkdir -p "$trans_tmp_dir";
        local trans_file="$trans_tmp_dir/x-odoo-trans-${tmp_db_name}.po";
        if server_run -- -d "$tmp_db_name" -l "$lang" --i18n-export="$trans_file" --modules="$addons_cs" --stop-after-init --pidfile=/dev/null; then
            if ! server_run -- -d "$tmp_db_name" -l "$lang" --i18n-import="$trans_file" --modules="$addons_cs" --stop-after-init --pidfile=/dev/null; then
                echoe -e "${REDC}ERROR${NC}: cannot import generated translations";
                rm "$trans_file";
                res=11;
            else
                rm "$trans_file";

                # Compute translation rate and print it
                if ! exec_lodoo_u --conf="$ODOO_CONF_FILE" tr-check-translation-rate --lang="$lang" "${check_tr_rate_opts[@]}" "$tmp_db_name" "$addons_cs"; then
                    res=1;
                fi
            fi
        else
            echoe -e "${REDC}ERROR${NC}: Cannot export translations!";
            res=12;
        fi
    else
        echoe -e "${REDC}ERROR${NC}: Cannot install addons: ${addons[*]}";
        res=13;
    fi

    # Drop temporary database
    odoo_db_drop "$tmp_db_name";

    return $res;
}

function tr_main {
    local usage="
    Manage translations

    Usage

        $SCRIPT_NAME tr export <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr export <db> <lang> <file_name> all
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> <addon1> [addon2] [addon3]...
        $SCRIPT_NAME tr import [--overwrite] <db> <lang> <file_name> all
        $SCRIPT_NAME tr load --help
        $SCRIPT_NAME tr generate-pot --help
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
                tr_regenerate "$@";
                return;
            ;;
            generate-pot)
                shift;
                tr_generate_pot "$@";
                return;
            ;;
            rate)
                shift;
                tr_translation_rate "$@";
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
