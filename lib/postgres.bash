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
        echoe -e "${GEENC}OK${NC}: Postgresql user ${BLUEC}$user_name${NC} was created for this Odoo instance";
    else
        echoe -e "${YELLOWC}There are $user_name already exists in postgres server${NC}";
    fi
}

# Parse command line args
function postgres_command {
    local usage="Usage:

        NOTE: this subcommand manages local postgres instance!
        NOTE: most of commands require sudo

        $SCRIPT_NAME postgres user-create <user name> <password>   - Create postgres user for odoo
        $SCRIPT_NAME addons --help                                 - show this help message

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
                exit 0;
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
