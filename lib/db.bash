if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------


# odoo_create_db <name> [odoo_conf_file]
function odoo_create_db {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    echov "Creating odoo database $db_name using conf file $conf_file";

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.create_database(cl._server.tools.config['admin_passwd'], '$db_name', True, 'en_US');"

    execu python -c "\"$python_cmd\"";
    
    echo -e "${GREENC}Database $db_name created successfuly!${NC}";
}

# odoo_drop_db <name> [odoo_conf_file]
function odoo_drop_db {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd cl.db.drop(cl._server.tools.config['admin_passwd'], '$db_name');"
    
    execu python -c "\"$python_cmd\"";
    
    echo -e "${GREENC}Database $db_name dropt successfuly!${NC}";
}

# odoo_list_db [odoo_conf_file]
function odoo_list_db {
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd print '\n'.join(['%s'%d for d in cl.db.list()]);";
    
    execu python -c "\"$python_cmd\"";
}



