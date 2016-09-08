if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

#ohelper_require 'install';
ohelper_require 'server';
#ohelper_require 'fetch';
ohelper_require 'git';
# ----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# functions prefix: scaffold_*
#-----------------------------------------------------------------------------------------

set -e; # fail on errors


# odoo_scaffold <addon_name> [addon_path]
function scaffold_default {
    local addon_name=$1;
    local addon_dir=${2:-$REPOSITORIES_DIR};
    local addon_path=$addon_dir/$addon_name;

    odoo_py scaffold $addon_name $addon_dir;
    link_module $addon_path;

    # if addon is not part of some repo, create repo for it
    if ! git_is_git_repo $addon_path; then
        local cdir=$(pwd);
        cd $addon_path;
        git init;

        # generate gitignore
        echo "*.pyc" >> .gitignore;
        echo "*.swp" >> .gitignore;
        echo "*.idea/" >> .gitignore;
        echo "*~" >> .gitignore;
        echo "*.swo" >> .gitignore;
        echo "*.pyo" >> .gitignore;
        echo ".ropeproject/" >> .gitignore;
        cd $cdir;
    fi
}
