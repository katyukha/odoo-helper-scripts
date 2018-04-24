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


# Check if postgres is installed
#
# postgres_is_installed
function postgres_is_installed {
    # TODO: think about better way to check postgres presence
    if [ ! -f /etc/init.d/postgresql ]; then
        return 1;  # not installed
    else
        return 0;  # installed
    fi
}

# Install postgresql
# NOTE: Requires SUDO
#
# postgres_install_postgresql
function postgres_install_postgresql {
    with_sudo apt-get install -y postgresql;
}


# Test connection to local postgres instance
function postgres_test_connection {
    if ! sudo -u postgres -H psql -tA -c "SELECT 1;" >/dev/null 2>&1; then
        echoe -e "${REDC}ERROR:${NC} Cannot connect to local postgres DB!";
        return 1;
    fi
    return 0;
}

# Check if postgresql user exists
# NOTE: Requires SUDO
#
# postgres_user_exists <user name>
function postgres_user_exists {
    local user_name="$1";

    local user_count=$(sudo -u postgres -H psql -tA -c "SELECT count(*) FROM pg_user WHERE usename = '$user_name';");
    if [ $user_count -eq 0 ]; then
        return 1;
    else
        return 0
    fi
}

# Create new postgresql user
# NOTE: Requires SUDO
#
# postgres_user_create <username> <password>
function postgres_user_create {
    local user_name="$1";
    local user_password="$2";

    if ! postgres_test_connection; then
        return 1;
    fi

    if ! postgres_user_exists $user_name; then
        sudo -u postgres -H psql -c "CREATE USER \"$user_name\" WITH CREATEDB PASSWORD '$user_password';"
        echoe -e "${GREENC}OK${NC}: Postgresql user ${BLUEC}$user_name${NC} was created for this Odoo instance";
    else
        echoe -e "${YELLOWC}There are $user_name already exists in postgres server${NC}";
    fi
}

# Connect to database via psql
# Automaticaly pass connection parametrs
#
# postgres_psql ....
function postgres_psql {
    echoe -e "${BLUEC}Prepare psql cmd...${NC}"
    local pghost=$(odoo_get_conf_val db_host);
    local pgport=$(odoo_get_conf_val db_port);
    local pguser=$(odoo_get_conf_val db_user);
    local pgpass=$(odoo_get_conf_val db_password);
    local default_db=$(odoo_get_conf_val db_name);
          default_db=${default_db:-postgres};

    if [ -z "$pgport" ] || [ "$pgport" == 'False' ]; then
        pgport=;
    fi

    echoe -e "${BLUEC}Connection to psql via: '$cmd'${NC}"
    PGPASSWORD=$pgpass PGDATABASE=$default_db PGHOST=$pghost \
        PGPORT=$pgport PGUSER=$pguser psql $@;
}

# Show active postgres transactions
#
function postgres_psql_stat_activity {
PGAPPNAME="odoo-helper-pgstat" postgres_psql << EOF
    SELECT
        datname,
        pid,
        usename,
        application_name,
        client_addr,
        to_char(query_start,
        'YYYY-MM-DD HH:MM'),
        state,
        query
    FROM pg_stat_activity
    WHERE application_name != 'odoo-helper-pgstat';
EOF
}

# Configure local postgresql instance to be faster but less safe
#
# postgres_config_local_speed_unsafe
function postgres_config_speedify_unsafe {
    local postgres_config="$(sudo -u postgres psql -qSt -c 'SHOW config_file')";

    # Stop postgres
    sudo service postgresql stop

	# Disable fsync, etc
	sudo sed -ri "s/#fsync = on/fsync = off/g" $postgres_config;
	sudo sed -ri "s/#synchronous_commit = on/synchronous_commit = off/g" $postgres_config;
	sudo sed -ri "s/#full_page_writes = on/full_page_writes = off/g" $postgres_config;
	sudo sed -ri "s/#work_mem = 4MB/work_mem = 8MB/g" $postgres_config;

    # Start postgres
    sudo service postgresql start
}

# Parse command line args
function postgres_command {
    local usage="Usage:

        NOTE: subcommands tagged by [local] applicable only to local postgres instance!
        NOTE: subcommands tagged by [sudo] require sudo. (they will use sudo automaticaly)
        NOTE: most of commands require sudo

        $SCRIPT_NAME postgres psql [psql options]                  - Run psql with odoo connection params
        $SCRIPT_NAME postgres psql -d <database> [psql options]    - Run psql connected to specified database
        $SCRIPT_NAME postgres user-create <user name> <password>   - [local][sudo] Create postgres user for odoo
                                                                     It automaticaly uses credentials used by odoo
        $SCRIPT_NAME postgres stat-activity                        - list running postgres queries in database
                                                                     print data from pg_stat_activity table.
        $SCRIPT_NAME postgres speedify                             - [local][sudo] Modify local postgres config
                                                                     to make it faster. But also makes postgres unsafe.
                                                                     Usualy this is normal for dev machines,
                                                                     but not for production
        $SCRIPT_NAME postgres --help                               - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            user-create)
                shift;
                postgres_user_create "$@";
                return;
            ;;
            speedify)
                postgres_config_speedify_unsafe;
                return;
			;;
            psql)
                shift;
                config_load_project;
                postgres_psql $@;
                return;
            ;;
            stat-activity)
                shift;
                config_load_project;
                postgres_psql_stat_activity $@;
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
