# Copyright © 2017-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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

# Require libs
ohelper_require 'git';
ohelper_require 'recursion';
ohelper_require 'addons';
ohelper_require 'fetch';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors

# Define veriables
REQUIREMENTS_FILE_NAME="odoo_requirements.txt";
PIP_REQUIREMENTS_FILE_NAME="requirements.txt";
OCA_REQUIREMENTS_FILE_NAME="oca_dependencies.txt";


# link_is_addon_linked <addon_path>
# Return statuses
#  * 0 - addon is linked
#  * 1 - addon is not present in addons dir
#  * 2 - addon is present in addons dir, but link points to another path
function link_is_addon_linked {
    local addon_path;
    local addon_name;
    addon_path=$(readlink -f "$1");
    addon_name=$(basename "$addon_path");

    if [ ! -e "$ADDONS_DIR/$addon_name" ]; then
        # Addon is not present in custom addons
        return 1;
    fi
    local linked_path;
    linked_path=$(readlink -f "$ADDONS_DIR/$addon_name")

    if [ "$addon_path" == "$linked_path" ]; then
        # Addon is present in custom addons and link points to addon been checked
        return 0;
    else
        return 2;
    fi

}


# link_module_impl <source_path> <dest_path> <force: on|off>
function link_module_impl {
    local src; src=$(readlink -f "$1");
    local dest=$2;
    local force=$3;

    if [ "$force" == "on" ] && { [ -e "$dest" ] || [ -L "$dest" ]; }; then
        echov "Rewriting module $dest...";
        rm -rf "$dest";
    fi

    if [ ! -d "$dest" ]; then
        if [ -z "$USE_COPY" ]; then
            if [ -h "$dest" ] && [ ! -e "$dest" ]; then
                # If it is broken link, remove it
                rm "$dest";
            fi
            ln -s "$src" "$dest" ;
        else
            cp -r "$src" "$dest";
        fi
    else
        echov "Module $src already linked to $dest";
    fi
    fetch_requirements "$dest";
    fetch_pip_requirements "$dest/$PIP_REQUIREMENTS_FILE_NAME";
    fetch_oca_requirements "$dest/$OCA_REQUIREMENTS_FILE_NAME";
}

# link_module <force: on|off> <repo_path> [<module_name>]
function link_module {
    local force=$1;
    local REPO_PATH=$2;
    local MODULE_NAME=$3

    if [ -z "$REPO_PATH" ]; then
        echo -e "${REDC}Bad repo path for link: ${YELLOWC}${REPO_PATH}${NC}";
        return 2;
    fi

    REPO_PATH=$(readlink -f "$2");

    local recursion_key="link_module";
    if ! recursion_protection_easy_check "$recursion_key" "${REPO_PATH}__${MODULE_NAME:-all}"; then
        echo -e "${YELLOWC}WARN${NC}: REPO__MODULE ${REPO_PATH}__${MODULE_NAME:-all} already had been processed. skipping...";
        return 0
    fi

    echov "Linking module $REPO_PATH [$MODULE_NAME] ...";

    # Guess repository type
    if is_odoo_module "$REPO_PATH"; then
        # single module repo
        local basename_repo;
        basename_repo=$(basename "$REPO_PATH");
        link_module_impl "$REPO_PATH" "$ADDONS_DIR/${MODULE_NAME:-$basename_repo}" "$force";
    else
        # multi module repo
        if [ -z "$MODULE_NAME" ]; then
            # Check for requirements files in repository root dir
            fetch_requirements "$REPO_PATH";
            fetch_pip_requirements "$REPO_PATH/$PIP_REQUIREMENTS_FILE_NAME";
            fetch_oca_requirements "$REPO_PATH/$OCA_REQUIREMENTS_FILE_NAME";

            # No module name specified, then all modules in repository should be linked
            for file in "$REPO_PATH"/*; do
                local base_filename;
                base_filename=$(basename "$file");
                if is_odoo_module "$file" && addons_is_installable "$file"; then
                    # link module
                    link_module_impl "$file" "$ADDONS_DIR/$base_filename" "$force";
                elif [ -d "$file" ] && ! is_odoo_module "$file" && [ "$base_filename" != 'setup' ]; then
                    # if it is directory but not odoo module,
                    # and not 'setup' dir, then recursively look for addons there
                    link_module "$force" "$file";
                fi
            done
        else
            # Module name specified, then only single module should be linked
            link_module_impl "$REPO_PATH/$MODULE_NAME" "$ADDONS_DIR/$MODULE_NAME" "$force";
        fi
    fi
}


function link_command {
    local usage="
    Usage: 

        $SCRIPT_NAME link [-f|--force] <repo_path> [<module_name>]

    Options:
        -f|--force   - rewrite links if already exists
        --ual        - update addons list after link
    ";

    local force=off;
    local ual;

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options supplied $#: $*";
        echo "";
        echo "$usage";
        return 0;
    fi

    # Process all args that starts with '-' (ie. options)
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -f|--force)
                force=on;
            ;;
            --ual)
                ual=1;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done

    link_module "$force" "$@";

    if [ -n "$ual" ]; then
        addons_update_module_list;
    fi
}
