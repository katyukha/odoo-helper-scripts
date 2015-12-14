if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------


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

# odoo_db_exists [odoo_conf_file]
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


# Command line args processing
function odoo_db_command {
    local usage="Usage:

        $SCRIPT_NAME db list [odoo_conf_file]
        $SCRIPT_NAME db exists <name> [odoo_conf_file]
        $SCRIPT_NAME db create <name> [odoo_conf_file]
        $SCRIPT_NAME db drop <name> [odoo_conf_file]

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
            exists)
                shift;
                local VERBOSE=1;
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
