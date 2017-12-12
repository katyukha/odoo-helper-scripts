if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
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

    echo $(awk -F " *= *" "/$key/ {print \$2}" $conf_file);
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
    local wget_opt="";

    [ ! -z $VERBOSE ] && wget_opt="$wget_opt -q";

    if [ -d $ODOO_PATH ]; then    
        # Backup only if odoo sources directory exists
        local BACKUP_PATH=$BACKUP_DIR/odoo.sources.$ODOO_BRANCH.$FILE_SUFFIX.tar.gz
        echo -e "${LBLUEC}Saving odoo source backup:${NC} $BACKUP_PATH";
        (cd $ODOO_PATH/.. && tar -czf $BACKUP_PATH `basename $ODOO_PATH`);
        echo -e "${LBLUEC}Odoo sources backup saved at:${NC} $BACKUP_PATH";
    fi

    echo -e "${LBLUEC}Downloading new sources archive...${NC}"
    local ODOO_ARCHIVE=$DOWNLOADS_DIR/odoo.$ODOO_BRANCH.$FILE_SUFFIX.tar.gz
    # TODO: use odoo-repo variable here
    wget -T 2 $wget_opt -O $ODOO_ARCHIVE https://github.com/odoo/odoo/archive/$ODOO_BRANCH.tar.gz;
    rm -r $ODOO_PATH;
    (cd $DOWNLOADS_DIR && tar -zxf $ODOO_ARCHIVE && mv odoo-$ODOO_BRANCH $ODOO_PATH);

}

function odoo_update_sources {
    if git_is_git_repo $ODOO_PATH; then
        echo -e "${LBLUEC}Odoo source seems to be git repository. Attemt to update...${NC}";
        odoo_update_sources_git;

    else
        echo -e "${LBLUEC}Updating odoo sources...${NC}";
        odoo_update_sources_archive;
    fi

    echo -e "${LBLUEC}Reinstalling odoo...${NC}";

    # Run setup.py with gevent workaround applied.
    odoo_run_setup_py;  # imported from 'install' module

    echo -e "${GREENC}Odoo sources update finished!${NC}";

}


# Echo major odoo version (10, 11, ...)
function odoo_get_major_version {
    echo ${ODOO_VERSION%.*};
}

# Get python interpreter to run odoo with
# Returns one of: python2, python3, python
# Default: python
function odoo_get_python_version {
    if [ ! -z $ODOO_VERSION ] && [ $(odoo_get_major_version) -ge 11 ]; then
        echo "python3";
    elif [ ! -z $ODOO_VERSION ] && [ $(odoo_get_major_version) -lt 11 ]; then
        echo "python2";
    else
        echoe -e "${REDC}ERROR${NC}: odoo version not specified, using default python executable";
        echo "python";
    fi
}


function odoo_recompute_stored_fields {
    local usage="Recompute stored fields

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
                                  NOTE: this applicable only for new-style-fields in Odoo 8.0, 9.0
        --parent-store          - recompute parent left and parent right fot selected model
                                  conflicts wiht --field option

    Note: this command works only for Odoo ${YELLOWC}8.0+${NC}

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

    local python_cmd="import lodoo; cl=lodoo.LocalClient('$dbname', ['-c', '$conf_file']);";
    if [ -z $parent_store ]; then
        python_cmd="$python_cmd cl.recompute_fields('$model', [$fields]);"
    else
        python_cmd="$python_cmd cl.recompute_parent_store('$model');"
    fi

    run_python_cmd "$python_cmd";
}

function odoo_command {
    local usage="Usage:

        $SCRIPT_NAME odoo recompute --help                - recompute stored fields for database
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
