# Copyright © 2016-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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

ohelper_require 'install';
ohelper_require 'server';
ohelper_require 'fetch';
ohelper_require 'git';
ohelper_require 'scaffold';
# ----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# functions prefix: odoo_*
#-----------------------------------------------------------------------------------------

set -e; # fail on errors

# odoo_get_conf_val <key> [conf file]
# get value from odoo config file
function odoo_get_conf_val {
    local key=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    if [ -z "$conf_file" ]; then
        return 1;
    fi

    if [ ! -f "$conf_file" ]; then
        return 2;
    fi

    awk -F " *= *" "/^$key/ {print \$2}" "$conf_file";
}

# odoo_get_conf_val_default <key> <default> [conf file]
# Get value from odoo config or return default value
function odoo_get_conf_val_default {
    local value;

    value=$(odoo_get_conf_val "$1" "$3");
    if [ -n "$value" ]; then
        echo "$value";
    else
        echo "$2";
    fi
}

function odoo_get_conf_val_http_host {
    odoo_get_conf_val_default 'http_interface' "$(odoo_get_conf_val_default 'xmlrpc_interface' 'localhost')";
}

function odoo_get_conf_val_http_port {
    odoo_get_conf_val_default 'http_port' "$(odoo_get_conf_val_default 'xmlrpc_port' '8069')";
}

function odoo_get_server_url {
    echo "http://$(odoo_get_conf_val_http_host):$(odoo_get_conf_val_http_port)/";
}

# Get name of default test database.
function odoo_conf_get_test_db {
    local test_db;
    test_db=$(odoo_get_conf_val db_name "$ODOO_TEST_CONF_FILE")
    if [ -z "$test_db" ] || [ "$test_db" == "False" ]; then
        # if test database is not specified in conf, use name of test database
        # based on name of db user
        db_user=$(odoo_get_conf_val_default db_user odoo "$ODOO_TEST_CONF_FILE");
        test_db="$db_user-odoo-test";
    fi
    echo "$test_db";
}

function odoo_update_sources_git {
    local update_date;
    local tag_name;
    update_date=$(date +'%Y-%m-%d.%H-%M-%S');

    # Ensure odoo is repository
    if ! git_is_git_repo "$ODOO_PATH"; then
        echo -e "${REDC}Cannot update odoo. Odoo sources are not under git.${NC}";
        return 1;
    fi

    # ensure odoo repository is clean
    if ! git_is_clean "$ODOO_PATH"; then
        echo -e "${REDC}Cannot update odoo. Odoo source repo is not clean.${NC}";
        return 1;
    fi

    # Update odoo source
    tag_name="$(git_get_branch_name "$ODOO_PATH")-before-update-$update_date";
    (cd "$ODOO_PATH" &&
        git tag -a "$tag_name" -m "Save before odoo update ($update_date)" &&
        git pull);
}

function odoo_update_sources_archive {
    local file_suffix;
    local wget_opt;
    local backup_path;
    local odoo_archive;
    local odoo_archive_link;

    file_suffix="$(date -I).$(random_string 4)";

    if [ -n "$ODOO_DOWNLOAD_SOURCE_LINK" ]; then
        odoo_archive_link="$ODOO_DOWNLOAD_SOURCE_LINK";
    elif [ -n "$ODOO_REPO" ] && [[ "$ODOO_REPO" == "https://github.com"* ]]; then
        odoo_archive_link="${ODOO_REPO%.git}/archive/$ODOO_BRANCH.tar.gz"
    else
        odoo_archive_link="https://github.com/odoo/odoo/archive/$ODOO_BRANCH.tar.gz";
    fi

    if [ -d "$ODOO_PATH" ]; then    
        # Backup only if odoo sources directory exists
        local backup_path=$BACKUP_DIR/odoo.sources.$ODOO_BRANCH.$file_suffix.tar.gz
        echoe -e "${LBLUEC}Saving odoo source backup:${NC} $backup_path";
        (cd "$ODOO_PATH/.." && tar -czf "$backup_path" "$ODOO_PATH");
        echoe -e "${LBLUEC}Odoo sources backup saved at:${NC} $backup_path";
    fi

    echoe -e "${LBLUEC}Downloading new sources archive from ${YELLOWC}${odoo_archive_link}${LBLUEC}...${NC}"
    odoo_archive=$DOWNLOADS_DIR/odoo.$ODOO_BRANCH.$file_suffix.tar.gz

    local wget_options=( "-T" "15" "-O" "$odoo_archive" );
    if [ -z "$VERBOSE" ]; then
        wget_options+=( "-q" );
    fi

    if ! wget "${wget_options[@]}" "$odoo_archive_link"; then
        echoe -e "${REDC}ERROR${NC}: Cannot download Odoo. Retry this operation with --verbose option.";
        return 1
    fi

    if [ -d "$ODOO_PATH" ]; then
        echoe -e "${LBLUEC}Removing old odoo sources...${NC}";
        rm -r "$ODOO_PATH";
    fi

    echoe -e "${LBLUEC}Unpacking new source archive ...${NC}";
    (cd "$DOWNLOADS_DIR" && \
        tar -zxf "$odoo_archive" && \
        mv "odoo-$ODOO_BRANCH" "$ODOO_PATH");
    echoe -e "${GREENC}OK${NC}: ${LBLUEC}Odoo sources unpacked.${NC}";
}

function odoo_update_sources {
    local need_start;
    local usage="
    Update odoo sources

    Usage:

        $SCRIPT_NAME update-odoo [options]  - update odoo sourcess

    Options:

        --no-restart     - do not restart the server
        -h|--help|help   - show this help message
    ";

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --no-restart)
                local no_restart_server=1;
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

    # Stop server if it is running
    if [ -z "$no_restart_server" ] && [ "$(server_get_pid)" -gt 0 ]; then
        server_stop;
        local need_start=1;
    fi

    if git_is_git_repo "$ODOO_PATH"; then
        echoe -e "${LBLUEC}Odoo source seems to be git repository. Attemt to update...${NC}";
        odoo_update_sources_git;

    else
        echoe -e "${LBLUEC}Updating odoo sources...${NC}";
        odoo_update_sources_archive;
    fi

    echoe -e "${LBLUEC}Reinstalling odoo...${NC}";

    # Run setup.py with gevent workaround applied.
    odoo_run_setup_py;  # imported from 'install' module

    echoe -e "${GREENC}Odoo sources update finished!${NC}";
    echoe -e "${LBLUEC}It is recommended to update module ${YELLOWC}base${LBLUEC} on all databases on this server!${NC}";

    if [ -n "$need_start" ] && ! server_is_running; then
        server_start;
    fi
}


# Echo major odoo version (10, 11, ...)
function odoo_get_major_version {
    echo "${ODOO_VERSION%.*}";
}

# Get python version number - only 2 or 3
function odoo_get_python_version_number {
    if [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -ge 11 ]; then
        echo "3";
    elif [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -lt 11 ]; then
        echo "2";
    fi
}

# Get python interpreter name to run odoo with
# Returns one of: python2, python3, python
# Default: python
function odoo_get_python_version {
    local py_version;
    py_version=$(odoo_get_python_version_number);
    if [ -n "$py_version" ]; then
        echo "python${py_version}";
    elif check_command python3; then
        echoe -e "${YELLOWC}WARNING${NC}: odoo version not specified, Using python3";
        echo "python3";
    elif check_command python; then
        echoe -e "${YELLOWC}WARNING${NC}: odoo version not specified, using default python executable";
        echo "python";
    else
        echoe -e "${REDC}ERROR${NC}: odoo version not specified and cannot find default python interpreter.";
        return 1;
    fi
}

# Get python interpreter (full path to executable) to run odoo with
function odoo_get_python_interpreter {
    local python_version;
    python_version=$(odoo_get_python_version);
    check_command "$python_version";
}

# Check if system (current) python satisfies odoo requirements
function odoo_ensure_python_version {
    if [ -z "$ODOO_VERSION" ]; then
        return 1;  # Odoo version is not specified
    fi
    local python_interpreter;
    python_interpreter=$(odoo_get_python_interpreter);
    if [ -z "$python_interpreter" ]; then
        return 2;  # Python interpreter is not available
    fi

    if [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -eq 11 ]; then
        ${python_interpreter} -c "import sys; assert (3, 6) <= sys.version_info < (3, 9);" > /dev/null 2>&1;
    elif [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -eq 12 ]; then
        ${python_interpreter} -c "import sys; assert (3, 6) <= sys.version_info < (3, 9);" > /dev/null 2>&1;
    elif [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -eq 13 ]; then
        ${python_interpreter} -c "import sys; assert (3, 6) <= sys.version_info < (3, 10);" > /dev/null 2>&1;
    elif [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -eq 14 ]; then
        ${python_interpreter} -c "import sys; assert (3, 6) <= sys.version_info < (3, 10);" > /dev/null 2>&1;
    elif [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -eq 15 ]; then
        ${python_interpreter} -c "import sys; assert (3, 7) <= sys.version_info < (3, 11);";
    elif [ -n "$ODOO_VERSION" ] && [ "$(odoo_get_major_version)" -eq 16 ]; then
        ${python_interpreter} -c "import sys; assert (3, 7) <= sys.version_info < (3, 11);";
    else
        echoe -e "${REDC}ERROR${NC}: Automatic detection of python version for odoo ${ODOO_VERSION} is not supported!";
        return 1;
    fi
}

function odoo_recompute_stored_fields {
    local usage="
    Recompute stored fields

    Usage:

        $SCRIPT_NAME odoo recompute <options>            - recompute stored fields for database
        $SCRIPT_NAME odoo recompute --help               - show this help message

    Options:

        -d|--db|--dbname <dbname>  - name of database to recompute stored fields on
        --tdb                      - recompute for test database
        -m|--model <model name>    - name of model (in 'model.name.x' format)
                                     to recompute stored fields on
        -f|--field <field name>    - name of field to be recomputed.
                                     could be specified multiple times,
                                     to recompute few fields at once.
        --parent-store             - recompute parent left and parent right fot selected model
                                     conflicts wiht --field option
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local dbname=;
    local model=;
    local fields=;
    local parent_store=;
    local recompute_opts=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -d|--db|--dbname)
                dbname=$2;
                shift;
            ;;
            --tdb)
                dbname=$(odoo_conf_get_test_db);
            ;;
            -m|--model)
                model=$2;
                shift;
            ;;
            -f|--field)
                fields="'$2',$fields";
                recompute_opts+=( --field="$2" );
                shift;
            ;;
            --parent-store)
                parent_store=1;
                recompute_opts+=( --parent-store );
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

    if [ -z "$dbname" ]; then
        echoe -e "${REDC}ERROR${NC}: database not specified!";
        return 1;
    fi

    if ! odoo_db_exists -q "$dbname"; then
        echoe -e "${REDC}ERROR${NC}: database ${YELLOWC}${dbname}${NC} does not exists!";
        return 2;
    fi

    if [ -z "$model" ]; then
        echoe -e "${REDC}ERROR${NC}: model not specified!";
        return 3;
    fi

    if [ -z "$fields" ] && [ -z "$parent_store" ]; then
        echoe -e "${REDC}ERROR${NC}: no fields nor ${YELLOWC}--parent-store${NC} option specified!";
        return 4;
    fi

    exec_lodoo_u --conf="$ODOO_CONF_FILE" odoo-recompute "$dbname" "$model" "${recompute_opts[@]}";
}


function odoo_recompute_menu {
    local usage="
    Recompute menu hierarchy.
    Useful to recompute menu hierarchy when it is broken.
    this is usualy caused by errors during update.

    Usage:

        $SCRIPT_NAME odoo recompute-menu <options>  - recompute menu for specified db
        $SCRIPT_NAME odoo recompute-menu --help     - show this help message

    Options:

        -d|--db|--dbname <dbname>  - name of database to recompute menu for
        --tdb                      - recompute for test database
    ";
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local dbname=;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -d|--db|--dbname)
                dbname=$2;
                shift;
            ;;
            --tdb)
                dbname=$(odoo_conf_get_test_db);
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

    if [ -z "$dbname" ]; then
        echoe -e "${REDC}ERROR${NC}: database not specified!";
        return 1;
    fi

    # TODO: use lodoo here
    odoo_recompute_stored_fields --db "$dbname" --model 'ir.ui.menu' --parent-store;
}

function odoo_shell {
    local odoo_shell_opts=( );
    if [ "$(odoo_get_major_version)" -gt 10 ]; then
        odoo_shell_opts+=( "--no-http" );
    else
        odoo_shell_opts+=( "--no-xmlrpc" );
    fi
    server_run --no-unbuffer -- shell "${odoo_shell_opts[@]}" "$@";
}

function odoo_clean_compiled_assets {
    local usage="
    Remove compiled assets (css, js, etc) to enforce Odoo
    to regenerate compiled assets.
    This is required some times, when compiled assets are broken,
    and Odoo do not want to regenerate them in usual way.

    WARNING: This is experimental feature;

    Usage:

        $SCRIPT_NAME odoo clean-compiled-assets <options>  - clean-up assets
        $SCRIPT_NAME odoo recompute-menu --help            - show this help

    Options:

        -d|--db|--dbname <dbname>  - name of database to clean-up assets for
        --all                      - apply to all databases
    ";
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local dbnames=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -d|--db|--dbname)
                dbnames+=( "$2" );
                shift;
            ;;
            --all)
                mapfile -t dbnames < <(odoo_db_list | sed '/^$/d');
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

    if [ ${#dbnames[@]} -eq 0 ]; then
        echoe -e "${REDC}ERROR${NC}: at lease one database must be specified!";
        return 1;
    fi
    for dbname in "${dbnames[@]}"; do
# TODO select id,name,store_fname from ir_attachment where name ilike '%/web/content/%-%/%';
PGAPPNAME="odoo-helper" postgres_psql -d "$dbname" << EOF
        DELETE FROM ir_attachment WHERE name ILIKE '%/web/content/%/web.assets%';
        DELETE FROM ir_attachment WHERE name ~* '/[a-z0-9_]+/static/(lib|src)/.*.(scss|less).css';

        -- Version 15+?
        DELETE FROM ir_attachment
        WHERE res_model = 'ir.ui.view'
          AND type = 'binary'
          AND (url ILIKE '/web/content/%' OR url ILIKE '/web/assets/%');
EOF
    done
}

function odoo_command {
    local usage="
    Helper functions for Odoo

    Usage:

        $SCRIPT_NAME odoo recompute --help       - recompute stored fields for database
        $SCRIPT_NAME odoo recompute-menu --help  - recompute menus for db
        $SCRIPT_NAME odoo server-url             - print URL to access this odoo instance
        $SCRIPT_NAME odoo shell                  - open odoo shell
        $SCRIPT_NAME odoo clean-compiled-assets  - Remove compilled versions of assets
        $SCRIPT_NAME odoo --help                 - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            recompute)
                shift;
                odoo_recompute_stored_fields "$@";
                return 0;
            ;;
            recompute-menu)
                shift;
                odoo_recompute_menu "$@";
                return 0;
            ;;
            server-url)
                shift;
                odoo_get_server_url;
                return;
            ;;
            shell)
                shift;
                odoo_shell "$@";
                return;
            ;;
            clean-compiled-assets)
                shift;
                odoo_clean_compiled_assets "$@";
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
    done
}
