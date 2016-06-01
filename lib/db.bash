if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------

set -e; # fail on errors



# odoo_db_create <name> [odoo_conf_file]
function odoo_db_create {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    echov "Creating odoo database $db_name using conf file $conf_file";

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.create_database(cl._server.tools.config['admin_passwd'], '$db_name', True, 'en_US');"

    execu python -c "\"$python_cmd\"";
    
    echo -e "${GREENC}Database $db_name created successfuly!${NC}";
}

# odoo_db_drop <name> [odoo_conf_file]
function odoo_db_drop {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.drop(cl._server.tools.config['admin_passwd'], '$db_name');"
    
    execu python -c "\"$python_cmd\"";
    
    echo -e "${GREENC}Database $db_name dropt successfuly!${NC}";
}

# odoo_db_list [odoo_conf_file]
function odoo_db_list {
    local conf_file=${1:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd print '\n'.join(['%s'%d for d in cl.db.list()]);";
    
    execu python -c "\"$python_cmd\"";
}

# odoo_db_exists <dbname> [odoo_conf_file]
function odoo_db_exists {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd exit(int(not(cl.db.db_exist('$db_name'))));";
    
    if execu python -c "\"$python_cmd\""; then
        echov "Database named '$db_name' exists!";
        return 0;
    else
        echov "Database '$db_name' does not exists!";
        return 1;
    fi
}

# odoo_db_dump <dbname> <file-path> [format [odoo_conf_file]]
# dump database to specified path
function odoo_db_dump {
    local db_name=$1;
    local db_dump_file=$2;
    local conf_file=$ODOO_CONF_FILE;

    if [ -f "$3" ]; then
        conf_file=$3;
    elif [ ! -z $3 ]; then
        local format=$3;
        local format_opt=", '$format'";

        if [ -f "$4" ]; then
            conf_file=$4;
        fi
    fi

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd dump=cl.db.dump(cl._server.tools.config['admin_passwd'], '$db_name' $format_opt).decode('base64');";
    python_cmd="$python_cmd open('$db_dump_file', 'wb').write(dump);";
    
    if execu python -c "\"$python_cmd\""; then
        echov "Database named '$db_name' dumped to '$db_dump_file'!";
        return 0;
    else
        echo "Database '$db_name' fails on dump!";
        return 1;
    fi
}


# odoo_db_backup <dbname> [format [odoo_conf_file]]
# if second argument is file and it exists, then it used as config filename
# in other cases second argument is treated as format, and third (if passed) is treated as conf file
function odoo_db_backup {
    if [ -z $BACKUP_DIR ]; then
        echo "Backup dir is not configured. Add 'BACKUP_DIR' variable to your 'odoo-helper.conf'!";
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
        echo -e "${LBLUEC}backing-up database: $dbname${NC}";
        odoo_db_backup $dbname $format $conf_file;
    done
}

# odoo_db_restore <dbname> <dump_file> [odoo_conf_file]
function odoo_db_restore {
    local db_name=$1;
    local db_dump_file=$2;
    local conf_file=${3:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd res=cl.db.restore(cl._server.tools.config['admin_passwd'], '$db_name', open('$db_dump_file', 'rb').read().encode('base64'));";
    python_cmd="$python_cmd exit(0 if res else 1);";
    
    if execu python -c "\"$python_cmd\""; then
        echov "Database named '$db_name' restored from '$db_dump_file'!";
        return 0;
    else
        echov "Database '$db_name' fails on restore from '$db_dump_file'!";
        return 1;
    fi
}

# Command line args processing
function odoo_db_command {
    local usage="Usage:

        $SCRIPT_NAME db list [odoo_conf_file]
        $SCRIPT_NAME db exists <name> [odoo_conf_file]
        $SCRIPT_NAME db create <name> [odoo_conf_file]
        $SCRIPT_NAME db drop <name> [odoo_conf_file]
        $SCRIPT_NAME db dump <name> <dump_file_path> [format [odoo_conf_file]]
        $SCRIPT_NAME db backup <name> [format [odoo_conf_file]]
        $SCRIPT_NAME db backup-all [format [odoo_conf_file]]
        $SCRIPT_NAME db restore <name> <dump_file_path> [odoo_conf_file]

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            list)
                shift;
                odoo_db_list "$@";
                exit;
            ;;
            create)
                shift;
                odoo_db_create "$@";
                exit;
            ;;
            drop)
                shift;
                odoo_db_drop "$@";
                exit;
            ;;
            dump)
                shift;
                odoo_db_dump "$@";
                exit;
            ;;
            backup)
                shift;
                odoo_db_backup "$@";
                exit;
            ;;
            backup-all)
                shift;
                odoo_db_backup_all "$@";
                exit;
            ;;
            restore)
                shift;
                odoo_db_restore "$@";
                exit;
            ;;
            exists)
                shift;
                odoo_db_exists "$@";
                exit;
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
