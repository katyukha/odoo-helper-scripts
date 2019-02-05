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

#ohelper_require 'install';
ohelper_require 'server';
#ohelper_require 'fetch';
ohelper_require 'git';
# ----------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# functions prefix: scaffold_*
#-----------------------------------------------------------------------------------------

set -e; # fail on errors


# Define tempalte paths
TMPL_GITIGNORE=$ODOO_HELPER_LIB/templates/scaffold/gitignore.tmpl;
TMPL_ADDON=$ODOO_HELPER_LIB/templates/scaffold/addon;
TMPL_ADDON_MANIFEST=$ODOO_HELPER_LIB/templates/scaffold/addon__manifest__.py.tmpl;
TMPL_ADDON_README=$ODOO_HELPER_LIB/templates/scaffold/addon__README.rst.tmpl;

# Templater
TEMPLATER=$ODOO_HELPER_LIB/pylib/jinja-cli.py


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

        cp $TMPL_GITIGNORE ./.gitignore;
        cd $cdir;
    fi
}

function scaffold_repo {
    local usage="
    Usage

        $SCRIPT_NAME scaffold repo <repo name>
        $SCRIPT_NAME scaffold repo --help

    This command will automatically create git repository with specified
    name inside $REPOSITORIES_DIR
    ";

    if [[ "$1" =~ help|--help|-h ]]; then
        echo "$usage";
        return 0;
    fi

    local repo_name=$1;
    local repo_path=$REPOSITORIES_DIR/$repo_name;

    if [ -z "$repo_name" ]; then
        echo -e "${REDC}ERROR:${NC} No repository name supplied!";
        return 1;
    fi

    if [ -d $repo_path ]; then
        echo -e "${REDC}ERROR:${NC} Such repository already exists!";
        return 2;
    fi

    # Create repo dir
    mkdir -p $repo_path;

    # Init git repository
    (cd $repo_path && git init);

    # Copy .gitignore to new repo;
    cp $TMPL_GITIGNORE $repo_path/.gitignore;

    echo -e "${GREENC}Repository $repo_name created:${NC} $repo_path$";
}

function scaffold_addon {
    local usage="
    Usage

        $SCRIPT_NAME scaffold addon [options] <addon name>
        $SCRIPT_NAME scaffold addon --help

    This command will automatically create new addons with specified name
    in current working directory.

    Options

        --repo|-r <name>     - name or path to repository to create addon iside
        --depends|-d <name>  - name of addon to be added to depends section of manifest.
                               Could be specified multiple times
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local depends="";
    while [[ $# -gt 0 ]]
    do
        case $1 in
            --repo|-r)
                local repo=$2;
                shift; shift;
            ;;
            --depends|-d)
                depends="$depends \"$2\"";
                shift; shift;
            ;;
            --help|-h|help)
                echo "$usage";
                return 0;
            ;;
            *)
                # Options finished
                break
            ;;
        esac
    done

    local addon_name=$1;
    local addon_dest=$(pwd);

    if ! [[ "$addon_name" =~ ^[a-z0-9_]+$ ]]; then
        echo -e "${REDC}ERROR:${NC} Wrong addon name specified. addon name should contain only 'a-z0-9_' sympbols!"
        return 1;
    fi

    if [ -z "$depends" ]; then
        depends="\"base\""
    fi

    depends=$(join_by "," $depends);

    # If repo specified, take it into account
    if [ ! -z $repo ] && git_is_git_repo $REPOSITORIES_DIR/$repo; then
        addon_dest=$REPOSITORIES_DIR/$repo;
    elif [ ! -z $repo ] && git_is_git_repo $(readlink -f $repo); then
        addon_dest=$(readlink -f $repo);
    fi

    local addon_path=$addon_dest/$addon_name;

    # Choose correct manifest filename for Odoo version
    if [[ $(odoo_get_major_version) -lt 10 ]]; then
        local manifest_name="__openerp__.py";
    else
        local manifest_name="__manifest__.py";
    fi

    # Copy odoo addon skeleton
    cp -r $TMPL_ADDON $addon_path; 

    # Generate manifest file for addon
    local default_addon_author=$(git config user.name)
    execv $TEMPLATER \
        -D ODOO_VERSION=$ODOO_VERSION \
        -D ADDON_NAME=$addon_name \
        -D ADDON_AUTHOR=\"${SCAFFOLD_ADDON_AUTHOR:-$default_addon_author}\" \
        -D ADDON_LICENCE=\"${SCAFFOLD_ADDON_LICENCE}\" \
        -D ADDON_WEBSITE=\"${SCAFFOLD_ADDON_WEBSITE}\" \
        -D ADDON_DEPENDS="'$depends'" \
        $TMPL_ADDON_MANIFEST > $addon_path/$manifest_name;

    execv $TEMPLATER \
        -D ODOO_VERSION=$ODOO_VERSION \
        -D ADDON_NAME=$addon_name \
        -D ADDON_AUTHOR=\"${SCAFFOLD_ADDON_AUTHOR:-$default_addon_author}\" \
        -D ADDON_LICENCE=\"${SCAFFOLD_ADDON_LICENCE}\" \
        -D ADDON_WEBSITE=\"${SCAFFOLD_ADDON_WEBSITE}\" \
        -D ADDON_DEPENDS="'$depends'" \
        $TMPL_ADDON_README > $addon_path/README.rst;

    link_module off $addon_path;
}

function scaffold_model {
    echo -e "${REDC}Not implemented yet${YELLOWC}:(${NC}";
}

function scaffold_parse_cmd {
    local usage="
    ${YELLOWC}WARNING${NC}: this command is experimental and not maintained.

    Usage:

        $SCRIPT_NAME scaffold repo [--help]  - create new repository
        $SCRIPT_NAME scaffold addon [--help] - create new addon.
        $SCRIPT_NAME scaffold model [--help] - create new model.
        $SCRIPT_NAME scaffold --help         - show this help message

        $SCRIPT_NAME scaffold <addons name> [addon path] - defaut scaffold
                                                           (Odoo builtin)
    ";

    if [ -z "$1" ]; then
        echo "$usage";
        return 0;
    fi

    local key="$1";
    case $key in
        repo)
            shift;
            scaffold_repo $@;
            return 0;
        ;;
        addon)
            shift;
            scaffold_addon $@;
            return 0;
        ;;
        model)
            shift;
            scaffold_model $@;
            return 0;
        ;;
        -h|--help|help)
            echo "$usage";
            return 0;
        ;;
        *)
            scaffold_default $@;
            return 0;
        ;;
    esac
}
