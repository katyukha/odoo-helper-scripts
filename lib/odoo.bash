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

    echo $(awk -F " *= *" "/^$key/ {print \$2}" $conf_file);
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
    echo $(odoo_get_conf_val_default 'http_interface' $(odoo_get_conf_val_default 'xmlrpc_interface' 'localhost'));
}

function odoo_get_conf_val_http_port {
    echo $(odoo_get_conf_val_default 'http_port' $(odoo_get_conf_val_default 'xmlrpc_port' '8069'));
}

function odoo_get_server_url {
    echo "http://$(odoo_get_conf_val_http_host):$(odoo_get_conf_val_http_port)/";
}

function odoo_update_sources_git {
    local update_date=$(date +'%Y-%m-%d.%H-%M-%S')

    # Ensure odoo is repository
    if ! git_is_git_repo $ODOO_PATH; then
        echo -e "${REDC}Cannot update odoo. Odoo sources are not under git.${NC}";
        return 1;
    fi

    # ensure odoo repository is clean
    if ! git_is_clean $ODOO_PATH; then
        echo -e "${REDC}Cannot update odoo. Odoo source repo is not clean.${NC}";
        return 1;
    fi

    # Update odoo source
    local tag_name="$(git_get_branch_name $ODOO_PATH)-before-update-$update_date";
    (cd $ODOO_PATH &&
        git tag -a $tag_name -m "Save before odoo update ($update_date)" &&
        git pull);
}

function odoo_update_sources_archive {
    local FILE_SUFFIX=`date -I`.`random_string 4`;
    local wget_opt="-T 2";

    [ -z $VERBOSE ] && wget_opt="$wget_opt -q";

    if [ -d $ODOO_PATH ]; then    
        # Backup only if odoo sources directory exists
        local BACKUP_PATH=$BACKUP_DIR/odoo.sources.$ODOO_BRANCH.$FILE_SUFFIX.tar.gz
        echoe -e "${LBLUEC}Saving odoo source backup:${NC} $BACKUP_PATH";
        (cd $ODOO_PATH/.. && tar -czf $BACKUP_PATH `basename $ODOO_PATH`);
        echoe -e "${LBLUEC}Odoo sources backup saved at:${NC} $BACKUP_PATH";
    fi

    echoe -e "${LBLUEC}Downloading new sources archive...${NC}"
    local ODOO_ARCHIVE=$DOWNLOADS_DIR/odoo.$ODOO_BRANCH.$FILE_SUFFIX.tar.gz
    # TODO: use odoo-repo variable here
    wget $wget_opt -O $ODOO_ARCHIVE https://github.com/odoo/odoo/archive/$ODOO_BRANCH.tar.gz;
    rm -r $ODOO_PATH;
    (cd $DOWNLOADS_DIR && tar -zxf $ODOO_ARCHIVE && mv odoo-$ODOO_BRANCH $ODOO_PATH);

}

function odoo_update_sources {
    if git_is_git_repo $ODOO_PATH; then
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

}


# Echo major odoo version (10, 11, ...)
function odoo_get_major_version {
    echo ${ODOO_VERSION%.*};
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
    else
        echoe -e "${YELLOWC}WARNING${NC}: odoo version not specified, using default python executable";
        echo "python";
    fi
}

# Get python interpreter (full path to executable) to run odoo with
function odoo_get_python_interpreter {
    local python_version="$(odoo_get_python_version)";
    echo $(check_command $python_version);
}

function odoo_recompute_stored_fields {
    local usage="
    Recompute stored fields

    Usage:

        $SCRIPT_NAME odoo recompute <options>            - recompute stored fields for database
        $SCRIPT_NAME odoo recompute --help               - show this help message

    Options:

        -d|--dbname <dbname>    - name of database to recompute stored fields on
        -m|--model <model name> - name of model (in 'model.name.x' format)
                                  to recompute stored fields on
        -f|--field <field name> - name of field to be recomputed.
                                  could be specified multiple times,
                                  to recompute few fields at once.
        --parent-store          - recompute parent left and parent right fot selected model
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
    local conf_file=$ODOO_CONF_FILE;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -d|--dbname)
                dbname=$2;
                shift;
            ;;
            -m|--model)
                model=$2;
                shift;
            ;;
            -f|--field)
                fields="'$2',$fields";
                shift;
            ;;
            --parent-store)
                parent_store=1;
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

    if [ -z $dbname ]; then
        echoe -e "${REDC}ERROR${NC}: database not specified!";
        return 1;
    fi

    if ! odoo_db_exists -q $dbname; then
        echoe -e "${REDC}ERROR${NC}: database ${YELLOWC}${dbname}${NC} does not exists!";
        return 2;
    fi

    if [ -z $model ]; then
        echoe -e "${REDC}ERROR${NC}: model not specified!";
        return 3;
    fi

    if [ -z $fields ] && [ -z $parent_store ]; then
        echoe -e "${REDC}ERROR${NC}: no fields nor --parent-store option specified!";
        return 4;
    fi

    local python_cmd="import lodoo; db=lodoo.LocalClient(['-c', '$conf_file'])['$dbname'];";
    if [ -z $parent_store ]; then
        python_cmd="$python_cmd db.recompute_fields('$model', [$fields]);"
    else
        python_cmd="$python_cmd db.recompute_parent_store('$model');"
    fi

    run_python_cmd "$python_cmd";
}

function odoo_command {
    local usage="
    Usage:

        $SCRIPT_NAME odoo recompute --help                - recompute stored fields for database
        $SCRIPT_NAME odoo server-url                      - print URL to access this odoo instance
        $SCRIPT_NAME odoo --help                          - show this help message

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
                odoo_recompute_stored_fields $@;
                return 0;
            ;;
            server-url)
                shift;
                odoo_get_server_url;
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
