if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi
# -----------------------------------------------------------------------------

# function to print odoo-helper config
function config_print {
    echo "ODOO_VERSION=$ODOO_VERSION;";
    echo "ODOO_BRANCH=$ODOO_BRANCH;";
    echo "PROJECT_ROOT_DIR=$PROJECT_ROOT_DIR;";
    echo "CONF_DIR=$CONF_DIR;";
    echo "LOG_DIR=$LOG_DIR;";
    echo "LOG_FILE=$LOG_FILE;";
    echo "LIBS_DIR=$LIBS_DIR;";
    echo "DOWNLOADS_DIR=$DOWNLOADS_DIR;";
    echo "ADDONS_DIR=$ADDONS_DIR;";
    echo "DATA_DIR=$DATA_DIR;";
    echo "BIN_DIR=$BIN_DIR;";
    echo "VENV_DIR=$VENV_DIR;";
    echo "ODOO_PATH=$ODOO_PATH;";
    echo "ODOO_CONF_FILE=$ODOO_CONF_FILE;";
    echo "ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;";
    echo "ODOO_PID_FILE=$ODOO_PID_FILE;";
    echo "BACKUP_DIR=$BACKUP_DIR;";
    echo "REPOSITORIES_DIR=$REPOSITORIES_DIR;";
    
    if [ ! -z $INIT_SCRIPT ]; then
        echo "INIT_SCRIPT=$INIT_SCRIPT;";
    fi
    if [ ! -z $ODOO_REPO ]; then
        echo "ODOO_REPO=$ODOO_REPO;";
    fi
}


# Function to configure default variables
function config_set_defaults {
    if [ -z $PROJECT_ROOT_DIR ]; then
        echo -e "${REDC}There is no PROJECT_ROOT_DIR set!${NC}";
        return 1;
    fi
    CONF_DIR=${CONF_DIR:-$PROJECT_ROOT_DIR/conf};
    ODOO_CONF_FILE=${ODOO_CONF_FILE:-$CONF_DIR/odoo.conf};
    ODOO_TEST_CONF_FILE=${ODOO_TEST_CONF_FILE:-$CONF_DIR/odoo.test.conf};
    LOG_DIR=${LOG_DIR:-$PROJECT_ROOT_DIR/logs};
    LOG_FILE=${LOG_FILE:-$LOG_DIR/odoo.log};
    LIBS_DIR=${LIBS_DIR:-$PROJECT_ROOT_DIR/libs};
    DOWNLOADS_DIR=${DOWNLOADS_DIR:-$PROJECT_ROOT_DIR/downloads};
    ADDONS_DIR=${ADDONS_DIR:-$PROJECT_ROOT_DIR/custom_addons};
    DATA_DIR=${DATA_DIR:-$PROJECT_ROOT_DIR/data};
    BIN_DIR=${BIN_DIR:-$PROJECT_ROOT_DIR/bin};
    VENV_DIR=${VENV_DIR:-$PROJECT_ROOT_DIR/venv};
    ODOO_PID_FILE=${ODOO_PID_FILE:-$PROJECT_ROOT_DIR/odoo.pid};
    ODOO_PATH=${ODOO_PATH:-$PROJECT_ROOT_DIR/odoo};
    BACKUP_DIR=${BACKUP_DIR:-$PROJECT_ROOT_DIR/backups};
    REPOSITORIES_DIR=${REPOSITORIES_DIR:-$PROJECT_ROOT_DIR/repositories};
    INIT_SCRIPT=$INIT_SCRIPT;
}


# Load project configuration. No args provided
function config_load_project {
    if [ -z $PROJECT_ROOT_DIR ]; then
        # Load project conf, only if it is not loaded yet.
        local project_conf=`search_file_up $WORKDIR $CONF_FILE_NAME`;
        if [ -f "$project_conf" ] && [ ! "$project_conf" == "$HOME/odoo-helper.conf" ]; then
            echov -e "${LBLUEC}Loading conf${NC}: $project_conf";
            source $project_conf;
        fi

        if [ -z $PROJECT_ROOT_DIR ]; then
            echo -e "${YELLOWC}WARNING${NC}: no project config file found!";
        fi
    fi
}

