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


# link_module_impl <source_path> <dest_path> <force: on|off> <py-deps-manifest: on|off>
function link_module_impl {
    local src; src=$(readlink -f "$1");
    local dest=$2;
    local force=$3;
    local py_deps_manifest="${4:-off}";

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
    fetch_pip_requirements "$dest";
    fetch_oca_requirements "$dest";

    if [ "$py_deps_manifest" == "on" ] && [ -f "$dest/__manifest__.py" ]; then
        local py_deps;
        py_deps=$(exec_py_utils addon-py-deps --addon-path "$dest");
        if [ -n "$py_deps" ]; then
            odoo-helper pip install "$py_deps";
        fi
    fi
}

# signature:
#     link_module [options] <repo_path> [<module_name>]
# options:
#     --force
#     --module-name <module name>
#     --fetch-manifest-py-deps
function link_module {
    local force=off;
    local fetch_manifest_py_deps=off;
    local module_name;

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options supplied $#: $*";
        return 1;
    fi

    # Process all args that starts with '-' (ie. options)
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            -f|--force)
                force=on;
            ;;
            --fetch-manifest-py-deps)
                fetch_manifest_py_deps=on;
            ;;
            --module-name)
                module_name="$2";
                shift;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done
    local repo_path="$1"

    if [ -z "$repo_path" ]; then
        echo -e "${REDC}Bad repo path for link: ${YELLOWC}${repo_path}${NC}";
        return 2;
    fi

    repo_path=$(readlink -f "$repo_path");

    local recursion_key="link_module";
    if ! recursion_protection_easy_check "$recursion_key" "${repo_path}__${module_name:-all}"; then
        echo -e "${YELLOWC}WARN${NC}: REPO__MODULE ${repo_path}__${module_name:-all} already had been processed. skipping...";
        return 0
    fi

    echov "Linking module $repo_path [$module_name] ...";

    # Guess repository type
    if is_odoo_module "$repo_path"; then
        # single module repo
        local basename_repo;
        basename_repo=$(basename "$repo_path");
        link_module_impl "$repo_path" "$ADDONS_DIR/${module_name:-$basename_repo}" "$force" "$fetch_manifest_py_deps";
    else
        # multi module repo
        if [ -z "$module_name" ]; then
            # Check for requirements files in repository root dir
            fetch_requirements "$repo_path";
            fetch_pip_requirements "$repo_path";
            fetch_oca_requirements "$repo_path";

            # No module name specified, then all modules in repository should be linked
            for file in "$repo_path"/*; do
                local base_filename;
                base_filename=$(basename "$file");
                if is_odoo_module "$file" && addons_is_installable "$file"; then
                    # link module
                    link_module_impl "$file" "$ADDONS_DIR/$base_filename" "$force" "$fetch_manifest_py_deps";
                elif [ -d "$file" ] && ! is_odoo_module "$file" && [ "$base_filename" != 'setup' ]; then
                    # if it is directory but not odoo module,
                    # and not 'setup' dir, then recursively look for addons there
                    local link_module_opts=( );
                    if [ "$force" == on ]; then
                        link_module_opts+=( --force )
                    fi
                    if [ "$fetch_manifest_py_deps" == on ]; then
                        link_module_opts+=( --fetch-manifest-py-deps );
                    fi
                    link_module "${link_module_opts[@]}" "$file";
                fi
            done
        else
            # Module name specified, then only single module should be linked
            link_module_impl "$repo_path/$module_name" "$ADDONS_DIR/$module_name" "$force" "$fetch_manifest_py_deps";
        fi
    fi
}


function link_command {
    local usage="
    Usage: 

        $SCRIPT_NAME link [options] <repo_path>

    Options:
        -f|--force                - rewrite links if already exists
        --fetch-manifest-py-deps  - fetch python dependencies from addon's manifest
        --module-name <name>      - name of module to link from repo
        --ual                     - update addons list after link
    ";

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options supplied $#: $*";
        echo "";
        echo "$usage";
        return 0;
    fi

    local link_module_opts=( )
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
                link_module_opts+=( --force );
            ;;
            --fetch-manifest-py-deps)
                link_module_opts+=( --fetch-manifest-py-deps );
            ;;
            --module-name)
                link_module_opts+=( --module-name "$2" );
                shift;
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

    link_module "${link_module_opts[@]}" "$@";

    if [ -n "$ual" ]; then
        addons_update_module_list;
    fi
}
