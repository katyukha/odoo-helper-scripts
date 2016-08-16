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
# ----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# functions prefix: odoo_*
#-----------------------------------------------------------------------------------------

set -e; # fail on errors

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
    wget $wget_opt -O $ODOO_ARCHIVE https://github.com/odoo/odoo/archive/$ODOO_BRANCH.tar.gz;
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

# odoo_scaffold <addon_name> [addon_path]
function odoo_scaffold {
    local addon_name=$1;
    local addon_path=${2:-$REPOSITORIES_DIR};

    odoo_py scaffold $addon_name $addon_path;
    link_module $addon_path/$addon_name;
}
