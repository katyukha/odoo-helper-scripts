if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------

set -e; # fail on errors

#-----------------------------------------------------------------------------------------
# functions prefix: odoo_db_*
#-----------------------------------------------------------------------------------------

# odoo_db_create [options] <name> [odoo_conf_file]
function odoo_db_create {
    local usage="Usage:

        $SCRIPT_NAME db create [options]  <name> [odoo_conf_file]

        Creates database named <name>

        Options:
           --demo         - load demo-data (default: no demo-data)
           --lang <lang>  - specified language for this db.
                            <lang> is language code like 'en_US'...
           --help         - display this help message
    ";

    # Parse options
    local demo_data='False';
    local db_lang="en_US";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --demo)
                demo_data='True';
                shift;
            ;;
            --lang)
                db_lang=$2;
                shift; shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
    done

    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};
    
    if [ -z $db_name ]; then
        echoe -e "${REDC}ERROR${NC}: dbname not specified!!!";
        return 1;
    fi

    echov -e "${BLUEC}Creating odoo database ${YELLOWC}$db_name${BLUEC} using conf file ${YELLOWC}$conf_file${NC}";

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.create_database(cl.odoo.tools.config['admin_passwd'], '$db_name', $demo_data, '$db_lang');"

    # Filestore should be created by server user, so run resotore command as server user
    if ! run_python_cmd_u "$python_cmd"; then
        echoe -e "${REDC}ERROR${NC}: Cannot create database ${YELLOWC}$db_name${NC}!";
        return 1;
    else
        echoe -e "${GREENC}OK${NC}: Database ${YELLOWC}$db_name${NC} created successfuly!";
        return 0;
    fi
}

# odoo_db_drop <name> [odoo_conf_file]
function odoo_db_drop {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    if ! odoo_db_exists -q $db_name; then
        echoe -e "${REDC}ERROR${NC}: Cannot drop database ${YELLOWC}${db_name}${NC}! Database does not exists!";
        return 1;
    fi

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.drop(cl.odoo.tools.config['admin_passwd'], '$db_name');"
    
    if ! run_python_cmd "$python_cmd"; then
        echoe -e "${REDC}ERROR${NC}: Cannot drop database ${YELLOWC}$db_name${NC}!";
        return 1;
    else
        echoe -e "${GREENC}OK${NC}: Database ${YELLOWC}$db_name${NC} dropt successfuly!";
        return 0;
    fi
}

# odoo_db_list [odoo_conf_file]
function odoo_db_list {
    local conf_file=${1:-$ODOO_CONF_FILE};

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file', '--logfile', '/dev/null']);";
    python_cmd="$python_cmd print('\n'.join(['%s'%d for d in cl.db.list()]));";
    
    if ! run_python_cmd "$python_cmd"; then
        echoe -e "${REDC}ERROR${NC}: Cannot get list of databases!";
        return 1;
    fi
    return 0;
}

# odoo_db_exists [options] <dbname> [odoo_conf_file]
function odoo_db_exists {
    local usage=" Test if database exists

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
            *)
                break;
            ;;
        esac
        shift
    done

    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file', '--logfile', '/dev/null']);";
    python_cmd="$python_cmd exit(int(not(cl.db.db_exist('$db_name'))));";
    
    if run_python_cmd "$python_cmd"; then
        [ -z $opt_quite ] && echoe -e "Database named ${YELLOWC}$db_name${NC} exists!" || true;
        return 0;
    else
        [ -z $opt_quite ] && echoe -e "Database ${YELLOWC}$db_name${NC} does not exists!" || true;
        return 1;
    fi
}

# odoo_db_rename <old_name> <new_name> [odoo_conf_file]
function odoo_db_rename {
    local old_db_name=$1;
    local new_db_name=$2;
    local conf_file=${3:-$ODOO_CONF_FILE};

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.rename(cl.odoo.tools.config['admin_passwd'], '$old_db_name', '$new_db_name');"
    
    # Filestore should be created by server user, so run resotore command as server user
    if run_python_cmd_u "$python_cmd"; then
        echoe -e "${GREENC}OK${NC}: Database ${BLUEC}$old_db_name${NC} renamed to ${BLUEC}$new_db_name${NC} successfuly!";
        return 0;
    else
        echoe -e "${REDC}ERROR${NC}: Cannot rename databse ${BLUEC}$old_db_name${NC} to ${BLUEC}$new_db_name${NC}!";
        return 1;
    fi
}

# odoo_db_dump <dbname> <file-path> [format [odoo_conf_file]]
# dump database to specified path
function odoo_db_dump {
    local db_name=$1;
    local db_dump_file=$2;
    local conf_file=$ODOO_CONF_FILE;

    # determine 3-d and 4-th arguments (format and odoo_conf_file)
    if [ -f "$3" ]; then
        conf_file=$3;
    elif [ ! -z $3 ]; then
        local format=$3;
        local format_opt=", '$format'";

        if [ -f "$4" ]; then
            conf_file=$4;
        fi
    fi

    local python_cmd="import lodoo, base64; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd dump=base64.b64decode(cl.db.dump(cl.odoo.tools.config['admin_passwd'], '$db_name' $format_opt));";
    python_cmd="$python_cmd open('$db_dump_file', 'wb').write(dump);";
    
    if run_python_cmd "$python_cmd"; then
        echov -e "${GREENC}OK${NC}: Database named ${BLUEC}$db_name${NC} dumped to ${BLUEC}$db_dump_file${NC}!";
        return 0;
    else
        echoe -e "${REDC}ERROR${NC}: Database ${BLUEC}$db_name${NC} fails on dump!";
        return 1;
    fi
}


# odoo_db_backup <dbname> [format [odoo_conf_file]]
# if second argument is file and it exists, then it used as config filename
# in other cases second argument is treated as format, and third (if passed) is treated as conf file
function odoo_db_backup {
    if [ -z $BACKUP_DIR ]; then
        echoe -e "${REDC}ERROR${NC}: Backup dir is not configured. Add ${BLUEC}BACKUP_DIR${NC} variable to your ${BLUEC}odoo-helper.conf${NC}!";
        return 1;
    fi

    local FILE_SUFFIX=`date -I`.`random_string 4`;
    local db_name=$1;
    local db_dump_file="$BACKUP_DIR/db-backup-$db_name-$FILE_SUFFIX";

    # if format is passed and format is 'zip':
    if [ ! -z $2 ] && [ "$2" == "zip" ]; then
        db_dump_file="$db_dump_file.zip";
    else
        db_dump_file="$db_dump_file.backup";
    fi

    odoo_db_dump $db_name $db_dump_file $2 $3;
    echo $db_dump_file
}

# odoo_db_backup_all [format [odoo_conf_file]]
# backup all databases available for this server
function odoo_db_backup_all {
    local conf_file=$ODOO_CONF_FILE;

    # parse args
    if [ -f "$1" ]; then
        conf_file=$1;
    elif [ ! -z $1 ]; then
        local format=$1;
        local format_opt=", '$format'";

        if [ -f "$2" ]; then
            conf_file=$2;
        fi
    fi

    # dump databases
    for dbname in $(odoo_db_list $conf_file); do
        echoe -e "${BLUEC}backing-up database: ${YELLOWC}$dbname${NC}";
        odoo_db_backup $dbname $format $conf_file;
    done
}

# odoo_db_restore <dbname> <dump_file> [odoo_conf_file]
function odoo_db_restore {
    local db_name=$1;
    local db_dump_file=$2;
    local conf_file=${3:-$ODOO_CONF_FILE};

    local python_cmd="import lodoo, base64; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd res=cl.db.restore(cl.odoo.tools.config['admin_passwd'], '$db_name', base64.b64encode(open('$db_dump_file', 'rb').read()));";
    python_cmd="$python_cmd exit(0 if res else 1);";

    # Filestore should be created by server user, so run resotore command as server user
    if run_python_cmd_u "$python_cmd"; then
        echov -e "${GREENC}OK${NC}: Database named ${BLUEC}$db_name${NC} restored from ${BLUEC}$db_dump_file${NC}!";
        return 0;
    else
        echoe -e "${REDC}ERROR${NC}: Database ${BLUEC}$db_name${NC} fails on restore from ${BLUEC}$db_dump_file${NC}!";
        return 1;
    fi
}

# Command line args processing
function odoo_db_command {
    local usage="Usage:

        $SCRIPT_NAME db list [odoo_conf_file]
        $SCRIPT_NAME db exists <name> [odoo_conf_file]
        $SCRIPT_NAME db create <name> [odoo_conf_file]
        $SCRIPT_NAME db create --help
        $SCRIPT_NAME db drop <name> [odoo_conf_file]
        $SCRIPT_NAME db rename <old_name> <new_name> [odoo_conf_file]
        $SCRIPT_NAME db dump <name> <dump_file_path> [format [odoo_conf_file]]
        $SCRIPT_NAME db backup <name> [format [odoo_conf_file]]
        $SCRIPT_NAME db backup-all [format [odoo_conf_file]]
        $SCRIPT_NAME db restore <name> <dump_file_path> [odoo_conf_file]

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            list)
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
            dump)
                shift;
                odoo_db_dump "$@";
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
            rename)
                shift;
                odoo_db_rename "$@";
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
        esac
        shift
    done
}
