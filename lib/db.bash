# Copyright © 2015-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

if [ -z "$ODOO_HELPER_LIB" ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z "$ODOO_HELPER_COMMON_IMPORTED" ]; then
    source "$ODOO_HELPER_LIB/common.bash";
fi

# ----------------------------------------------------------------------------------------

set -e; # fail on errors

#-----------------------------------------------------------------------------------------
# functions prefix: odoo_db_*
#-----------------------------------------------------------------------------------------

# odoo_db_create [options] <name> [odoo_conf_file]
function odoo_db_create {
    local usage="
    Creates new database

    Usage:

        $SCRIPT_NAME db create [options]  <name> [odoo_conf_file]

    Arguments:
       <name>                - name of new database

    Options:
       --name <name>         - name of new database
       --demo                - load demo-data (default: no demo-data)
       --lang <lang>         - specified language for this db.
                               <lang> is language code like 'en_US'...
       --password <pass>     - Password for admin user. default: admin
       --country <code>      - Country code to select country for this DB.
                               Accountinug configuration will be detected
                               automatically.
                               Only supported on Odoo 9.0+
       --recreate            - if database with such name exists,
                               then drop it first
       --if-not-exists       - create database if it is not exists yet
       --tdb                 - create test database with standard name
                               and with demo data
       -i|--install <addon>  - Install specified addon to created db.
                               Could be specified multiple times
       --install-dir <dir>   - Install all addons in spcified directory.
       --help                - display this help message
    ";

    # Parse options
    local db_recreate=;
    local db_name=;
    local db_create_if_not_exists=;
    local db_install_addons=( );
    local db_create_opts=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --name)
                db_name="$2";
                shift;
            ;;
            --demo)
                db_create_opts+=( "--demo" )
            ;;
            --lang)
                db_create_opts+=( "--lang" "$2" );
                shift;
            ;;
            --password)
                db_create_opts+=( "--password" "$2" );
                shift;
            ;;
            --country)
                db_create_opts+=( "--country" "$2" );
                shift;
            ;;
            --tdb)
                local test_db;
                test_db=$(odoo_conf_get_test_db)
                if [ -n "$test_db" ]; then
                    db_name="$test_db";
                    db_create_opts+=( "--demo" );
                fi
            ;;
            --recreate)
                db_recreate=1;
            ;;
            --if-not-exists)
                db_create_if_not_exists=1;
            ;;
            -i|--install)
                # To be consistent with *odoo-helper test* command
                if ! addons_is_odoo_addon "$2"; then
                    echoe -e "${REDC}ERROR${NC}: Cannot install ${YELLOWC}${2}${NC} - it is not Odoo addon!";
                    return 1;
                fi
                db_install_addons+=( "$2" );
                shift;
            ;;
            --install-dir)
                local addons_list;
                mapfile -t addons_list < <(addons_list_in_directory --recursive --installable --by-name "$2" | sed '/^$/d');
                db_install_addons+=( "${addons_list[@]}" );
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    if [ -z "$db_name" ]; then
        db_name=$1;
        shift;
    fi

    local conf_file=${1:-$ODOO_CONF_FILE};

    if [ -z "$db_name" ]; then
        echoe -e "${REDC}ERROR${NC}: dbname not specified!!!";
        return 1;
    fi

    echov -e "${BLUEC}Creating odoo database ${YELLOWC}$db_name${BLUEC} using conf file ${YELLOWC}$conf_file${NC}";

    if odoo_db_exists -q "$db_name" "$conf_file"; then
        if [ -n "$db_recreate" ]; then
            echoe -e "${YELLOWC}WARNING${NC}: dropting existing database ${YELLOWC}${db_name}${NC}";
            odoo_db_drop --conf "$conf_file" "$db_name";
        elif [ -n "$db_create_if_not_exists" ]; then
            echoe -e "${BLUEC}INFO${NC}: Db already exists. do nothing...";
            return 0;
        else
            echoe -e "${REDC}ERROR${NC}: database ${YELLOWC}${db_name}${NC} already exists!";
            return 2;
        fi
    fi

    if ! exec_lodoo_u --conf="$conf_file" db-create "${db_create_opts[@]}" "$db_name"; then
        echoe -e "${REDC}ERROR${NC}: Cannot create database ${YELLOWC}$db_name${NC}!";
        return 1;
    else
        echoe -e "${GREENC}OK${NC}: Database ${YELLOWC}$db_name${NC} created successfuly!";

        if [ ${#db_install_addons[@]} -gt 0 ]; then
            echoe -e "${BLUEC}Installing addons: ${YELLOWC}${db_install_addons[*]}${BLUEC}...${NC}";
            addons_install_update 'install' --db "$db_name" --no-restart "${db_install_addons[@]}";
        fi
        return 0;
    fi
}

# odoo_db_drop [options] <name> [name2]..[nameN]
function odoo_db_drop {
    local usage="
    Drop database

    Usage:

        $SCRIPT_NAME db drop [options] <dbname> [conf file] - drop database
        $SCRIPT_NAME db drop --help                         - show this help message

    Options:

        -q|--quite        - do not show messages
        -c|--conf <path>  - path to config file to use. Default: $ODOO_CONF_FILE
        -h|--help         - show this help message.

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local conf_file=$ODOO_CONF_FILE;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -q|--quite)
                local opt_quite=1;
            ;;
            -c|--conf)
                conf_file=$2;
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    for db_name in "$@"; do
        if ! odoo_db_exists -q "$db_name"; then
            if [ -z "$opt_quite" ]; then
                echoe -e "${REDC}ERROR${NC}: Cannot drop database ${YELLOWC}${db_name}${NC}! Database does not exists!";
            fi
            return 1;
        fi

        echov -e "${LBLUEC}Dropping database ${YELLOWC}${dbname}${LBLUEC} using conf file ${YELLOWC}${conf_file}${NC}";
        if ! exec_lodoo_u --conf="$conf_file" db-drop "$db_name"; then
            if [ -z "$opt_quite" ]; then
                echoe -e "${REDC}ERROR${NC}: Cannot drop database ${YELLOWC}$db_name${NC}!";
            fi
            return 1;
        else
            if [ -z "$opt_quite" ]; then
                echoe -e "${GREENC}OK${NC}: Database ${YELLOWC}$db_name${NC} dropt successfuly!";
            fi
        fi
    done
}

# odoo_db_list [options] [odoo_conf_file]
function odoo_db_list {
    local usage="
    List available database

    Usage:

        $SCRIPT_NAME db list [options] [conf file] - show list of databases
        $SCRIPT_NAME db list --help                - show this help message
    ";

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    local conf_file=${1:-$ODOO_CONF_FILE};

    if ! exec_lodoo_u --conf="$conf_file" db-list; then
        echoe -e "${REDC}ERROR${NC}: Cannot get list of databases!";
        return 1;
    fi
    return 0;
}

# odoo_db_exists [options] <dbname> [odoo_conf_file]
function odoo_db_exists {
    local usage="
    Test if database exists

    Usage:

        $SCRIPT_NAME db exists [options] <dbname> [conf file] - test if db exists
        $SCRIPT_NAME db exists --help                         - show this help message

    Options:

        -q|--quite    do not show messages

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -q|--quite)
                local opt_quite=1;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    if exec_lodoo_u --conf="$conf_file" db-exists "$db_name"; then
        if [ -z "$opt_quite" ]; then
            echoe -e "Database named ${YELLOWC}$db_name${NC} exists!";
        fi
        return 0;
    else
        if [ -z "$opt_quite" ]; then
            echoe -e "Database ${YELLOWC}$db_name${NC} does not exists!";
        fi
        return 1;
    fi
}

# odoo_db_rename [options] <old_name> <new_name> [odoo_conf_file]
function odoo_db_rename {
    local usage="
    Rename database

    Usage:

        $SCRIPT_NAME db rename [options] <old_name> <new_name> [odoo_conf_file]

    Arguments:
        <old_name>    - name of existing database
        <new_name>    - new name of database

    Options:
       --help         - display this help message
    ";

    # Parse options
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    local old_db_name=$1;
    local new_db_name=$2;
    local conf_file=${3:-$ODOO_CONF_FILE};

    if ! odoo_db_exists -q "$old_db_name"; then
        if [ -z "$opt_quite" ]; then
            echoe -e "${REDC}ERROR${NC}: Cannot rename database ${YELLOWC}${old_db_name}${NC} -> ${YELLOWC}${new_db_name}${NC}! Database ${YELLOWC}${old_db_name}${NC} does not exists!";
        fi
        return 1;
    fi
    if odoo_db_exists -q "$new_db_name"; then
        if [ -z "$opt_quite" ]; then
            echoe -e "${REDC}ERROR${NC}: Cannot rename database ${YELLOWC}${old_db_name}${NC} -> ${YELLOWC}${new_db_name}${NC}! Database ${YELLOWC}${new_db_name}${NC} already exists!";
        fi
        return 2;
    fi

    # Filestore should be created by server user, so run resotore command as server user
    if exec_lodoo_u --conf="$conf_file" db-rename "$old_db_name" "$new_db_name"; then
        echoe -e "${GREENC}OK${NC}: Database ${YELLOWC}$old_db_name${NC} renamed to ${YELLOWC}$new_db_name${NC} successfuly!";
        return 0;
    else
        echoe -e "${REDC}ERROR${NC}: Cannot rename databse ${YELLOWC}$old_db_name${NC} to ${YELLOWC}$new_db_name${NC}!";
        return 1;
    fi
}

# odoo_db_copy <src_name> <new_name> [odoo_conf_file]
function odoo_db_copy {
    local usage="
    Copy database

    Usage:

        $SCRIPT_NAME db copy [options] <src_name> <new_name> [odoo_conf_file]

    Arguments:
        <src_name>    - name of existing database
        <new_name>    - new name of database

    Options:
       --help         - display this help message
    ";

    # Parse options
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    local src_db_name=$1;
    local new_db_name=$2;
    local conf_file=${3:-$ODOO_CONF_FILE};

    if ! odoo_db_exists -q "$src_db_name"; then
        if [ -z "$opt_quite" ]; then
            echoe -e "${REDC}ERROR${NC}: Cannot copy database ${YELLOWC}${src_db_name}${NC} -> ${YELLOWC}${new_db_name}${NC}! Database ${YELLOWC}${src_db_name}${NC} does not exists!";
        fi
        return 1;
    fi
    if odoo_db_exists -q "$new_db_name"; then
        if [ -z "$opt_quite" ]; then
            echoe -e "${REDC}ERROR${NC}: Cannot copy database ${YELLOWC}${src_db_name}${NC} -> ${YELLOWC}${new_db_name}${NC}! Database ${YELLOWC}${new_db_name}${NC} already exists!";
        fi
        return 2;
    fi

    # Filestore should be created by server user, so run duplicate command as server user
    if exec_lodoo_u --conf="$conf_file" db-copy "$src_db_name" "$new_db_name"; then
        echoe -e "${GREENC}OK${NC}: Database ${YELLOWC}$src_db_name${NC} copied to ${YELLOWC}$new_db_name${NC} successfuly!";
        return 0;
    else
        echoe -e "${REDC}ERROR${NC}: Cannot copy databse ${YELLOWC}$src_db_name${NC} to ${YELLOWC}$new_db_name${NC}!";
        return 1;
    fi
}


# odoo_db_backup [options] <dbname>
function odoo_db_backup {
    if [ -z "$BACKUP_DIR" ]; then
        echoe -e "${REDC}ERROR${NC}: Backup dir is not configured. Add ${BLUEC}BACKUP_DIR${NC} variable to your ${BLUEC}odoo-helper.conf${NC}!";
        return 1;
    fi

    local usage="
    Backup database.
    Backup will be stored at ${YELLOWC}${BACKUP_DIR}${NC}

    Usage:

        $SCRIPT_NAME db backup [options] <dbname>

    Arguments:
        <dbname>         - name of database to backup

    Options:
       --format <fmt>    - format of backup: zip or sql. Default: zip
       --conf <path>     - path to configuration file
       --tmp-dir <path>  - use different temp dir
       --help            - display this help message
    ";

    # Default options
    local conf_file=$ODOO_CONF_FILE;
    local format="zip";
    local custom_temp_dir;

    # Parse options
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --format)
                format="$2";
                shift;
            ;;
            --conf)
                conf_file="$2";
                shift;
            ;;
            --tmp-dir)
                if [ -d "$2" ]; then
                    custom_temp_dir=$2;
                else
                    echoe -e "${REDC}ERROR${NC}: temp dir '$2' does not exists!";
                    return 1;
                fi
                shift;
            ;;
            -h|--help|help)
                echoe -e "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done
    local db_name=$1;
    local db_dump_file;
    db_dump_file="$BACKUP_DIR/db-backup-$db_name-$(date -I).$(random_string 4)";

    # if format is passed and format is 'zip':
    if [ "$format" == "zip" ]; then
        db_dump_file="$db_dump_file.zip";
    else
        db_dump_file="$db_dump_file.backup";
    fi

    local res=0
    if [ -n "$custom_temp_dir" ] && [ -d "$custom_temp_dir" ]; then 
        if TMP="$custom_temp_dir" TEMP="$custom_temp_dir" TMPDIR="$custom_temp_dir" exec_lodoo_u --conf="$conf_file" db-backup -f "$format" "$db_name" "$db_dump_file"; then
            echov -e "${GREENC}OK${NC}: Database named ${BLUEC}$db_name${NC} backed up to ${BLUEC}$db_dump_file${NC}!";
        else
            echoe -e "${REDC}ERROR${NC}: Database ${BLUEC}$db_name${NC} fails on dump!";
            res=1;
        fi
    else
        if exec_lodoo_u --conf="$conf_file" db-backup -f "$format" "$db_name" "$db_dump_file"; then
            echov -e "${GREENC}OK${NC}: Database named ${BLUEC}$db_name${NC} backed up to ${BLUEC}$db_dump_file${NC}!";
        else
            echoe -e "${REDC}ERROR${NC}: Database ${BLUEC}$db_name${NC} fails on dump!";
            res=1
        fi
    fi
    echo "$db_dump_file";
    return $res;
}

# odoo_db_backup_all [format [odoo_conf_file]]
# backup all databases available for this server
function odoo_db_backup_all {
    local usage="
    Backup all databases.
    Backups will be stored at ${YELLOWC}${BACKUP_DIR}${NC}

    Usage:

        $SCRIPT_NAME db backup-all [options]

    Options:
       --format <fmt>    - format of backup: zip or sql. Default: zip
       --conf <path>     - path to configuration file
       --tmp-dir <path>  - use different temp dir
       --help            - display this help message
    ";

    # Default options
    local conf_file=$ODOO_CONF_FILE;
    local format="zip";
    local custom_temp_dir;

    # Parse options
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --format)
                format="$2";
                shift;
            ;;
            --conf)
                conf_file="$2";
                shift;
            ;;
            --tmp-dir)
                if [ -d "$2" ]; then
                    custom_temp_dir=$2;
                else
                    echoe -e "${REDC}ERROR${NC}: temp dir '$2' does not exists!";
                    return 1;
                fi
                shift;
            ;;
            -h|--help|help)
                echoe -e "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done

    # dump databases
    local dbnames;
    mapfile -t dbnames < <(odoo_db_list "$conf_file");
    for dbname in "${dbnames[@]}"; do
        echoe -e "${BLUEC}Backing-up database: ${YELLOWC}$dbname${NC}";
        if [ -n "$custom_temp_dir" ]; then
            odoo_db_backup --tmp-dir "$custom_temp_dir" --format "$format" --conf "$conf_file" "$dbname";
        else
            odoo_db_backup --format "$format" --conf "$conf_file" "$dbname";
        fi
    done
}

# odoo_db_restore <dbname> <dump_file> [odoo_conf_file]
function odoo_db_restore {
    local usage="
    Restore database.

    Usage:

        $SCRIPT_NAME db restore [options] <dbname> <dump_file>

    Arguments:
        <dbname>         - name of database to restore
        <dump_file>      - path to database backup

    Options:
       --conf <path>     - path to configuration file
       --tmp-dir <path>  - use different temp dir
       --help            - display this help message
    ";

    # Default options
    local conf_file=$ODOO_CONF_FILE;
    local custom_temp_dir;

    # Parse options
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --conf)
                conf_file="$2";
                shift;
            ;;
            --tmp-dir)
                if [ -d "$2" ]; then
                    custom_temp_dir=$2;
                else
                    echoe -e "${REDC}ERROR${NC}: temp dir '$2' does not exists!";
                    return 1;
                fi
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done
    local db_name=$1;
    local db_dump_file=$2;

    # Filestore should be created by server user, so run resotore command as server user
    if [ -n "$custom_temp_dir" ]; then
        if TMP="$custom_temp_dir" TEMP="$custom_temp_dir" TMPDIR="$custom_temp_dir" exec_lodoo_u --conf="$conf_file" db-restore "$db_name" "$db_dump_file"; then
            echov -e "${GREENC}OK${NC}: Database named ${BLUEC}$db_name${NC} restored from ${BLUEC}$db_dump_file${NC}!";
            return 0;
        else
            echoe -e "${REDC}ERROR${NC}: Database ${BLUEC}$db_name${NC} fails on restore from ${BLUEC}$db_dump_file${NC}!";
            return 1;
        fi
    else
        if exec_lodoo_u --conf="$conf_file" db-restore "$db_name" "$db_dump_file"; then
            echov -e "${GREENC}OK${NC}: Database named ${BLUEC}$db_name${NC} restored from ${BLUEC}$db_dump_file${NC}!";
            return 0;
        else
            echoe -e "${REDC}ERROR${NC}: Database ${BLUEC}$db_name${NC} fails on restore from ${BLUEC}$db_dump_file${NC}!";
            return 1;
        fi
    fi
}


function odoo_db_is_demo_enabled {
    local usage="
    Test if demo-data installed in database

    Usage:

        $SCRIPT_NAME db is-demo [options] <dbname> - test if dbname contains demo-data
        $SCRIPT_NAME db is-demo --help             - show this help message

    Options:

        -q|--quite    do not show messages

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -q|--quite)
                local opt_quite=1;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    local db_name=$1;
    local conf_file=$ODOO_CONF_FILE;

    if ! odoo_db_exists -q "$db_name"; then
        echoe -e "${REDC}ERROR${NC}: Database ${YELLOWC}${db_name}${NC} does not exists!";
        return 2;
    fi

    local demo_data_enabled;
    demo_data_enabled=$(postgres_psql -d "$db_name" -tA -c "SELECT EXISTS (SELECT 1 FROM ir_module_module WHERE state = 'installed' AND name = 'base' AND demo = True);");
    if [ "$demo_data_enabled" == "t" ]; then
        if [ -z "$opt_quite" ]; then
            echoe -e "Database named ${YELLOWC}$db_name${NC} contains demo data!";
        fi
        return 0;
    else
        if [ -z "$opt_quite" ]; then
            echoe -e "Database named ${YELLOWC}$db_name${NC} does NOT contain demo data!";
        fi
        return 1;
    fi
}

function odoo_db_dump_manifest {
    local usage="
    Print dump-manifest for specified database

    Usage:

        $SCRIPT_NAME db dump-manifest <dbname> - print manifest for dbname
        $SCRIPT_NAME db dump-manifest --help   - show this help message
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown command '$1'";
                return 1;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    local db_name=$1;

    if ! odoo_db_exists -q "$db_name"; then
        echoe -e "${REDC}ERROR${NC}: Database ${YELLOWC}${db_name}${NC} does not exists!";
        return 2;
    fi

    if ! exec_lodoo_u --conf="$ODOO_CONF_FILE" db-dump-manifest "$db_name"; then
        echoe -e "${REDC}ERROR${NC}: Cannot generate manifest for database: ${YELLOWC}$db_name${NC}!";
        return 1;
    fi
}


# Command line args processing
function odoo_db_command {
    local usage="
    Manage odoo databases

    Usage:

        $SCRIPT_NAME db list --help
        $SCRIPT_NAME db exists --help
        $SCRIPT_NAME db is-demo --help
        $SCRIPT_NAME db create --help
        $SCRIPT_NAME db drop --help
        $SCRIPT_NAME db rename --help
        $SCRIPT_NAME db copy --help
        $SCRIPT_NAME db dump --help  [deprecated]
        $SCRIPT_NAME db backup --help
        $SCRIPT_NAME db backup-all --help
        $SCRIPT_NAME db dump-manifest --help
        $SCRIPT_NAME db restore --help

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            ls|list)
                shift;
                odoo_db_list "$@";
                return;
            ;;
            create)
                shift;
                odoo_db_create "$@";
                return;
            ;;
            drop)
                shift;
                odoo_db_drop "$@";
                return;
            ;;
            dump-manifest)
                shift;
                odoo_db_dump_manifest "$@";
                return;
            ;;
            backup)
                shift;
                odoo_db_backup "$@";
                return;
            ;;
            backup-all)
                shift;
                odoo_db_backup_all "$@";
                return;
            ;;
            restore)
                shift;
                odoo_db_restore "$@";
                return;
            ;;
            exists)
                shift;
                odoo_db_exists "$@";
                return;
            ;;
            is-demo)
                shift;
                odoo_db_is_demo_enabled "$@";
                return;
            ;;
            rename)
                shift;
                odoo_db_rename "$@";
                return;
            ;;
            copy)
                shift;
                odoo_db_copy "$@";
                return;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echo "Unknown option / command $key";
                return 1;
            ;;
        esac;
        shift;
    done
}
