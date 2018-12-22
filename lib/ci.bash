# Copyright © 2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ---------------------------------------------------------------------

ohelper_require 'git';
ohelper_require 'utils';

set -e; # fail on errors

# ci_ensure_versions_ok <version1> <version2>
# ensure that version2 is greater than version1
function ci_ensure_versions_ok {
    local version1="$1"; shift;
    local version2="$1"; shift;

    # NOTE: here we inverse pythons True to bash zero status code
    if ! run_python_cmd "from pkg_resources import parse_version as V; exit(V('${version1}') < V('${version2}'));"; then
        return 0;
    else
        return 1;
    fi
}

# ci_validate_version <version>
# validate specified version
# version must look like x.x.y.y.y
# where x.x is odoo version and y.y.y repository version
function ci_validate_version {
    local version="$1";
    if ! [[ "$version" =~ ^${ODOO_VERSION}\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1;
    fi
    return 0;
}

# ci_fix_version_serie <version>
# Attempt to fix version serie (to be same as current odoo version)
function ci_fix_version_serie {
    local version="$1";
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        echo "${ODOO_VERSION}.${BASH_REMATCH[1]}";
    else
        return 1;
    fi
        #echo "${ODOO_VERSION}.${BASH_REMATCH[1]}.$((${BASH_REMATCH[2]} + 1))";
}

# ci_fix_version_number <version>
# Attempt to fix version number (increase minor part)
function ci_fix_version_number {
    local version="$1";
    if [[ "$version" =~ ^${ODOO_VERSION}\.([0-9]+\.[0-9]+)\.([0-9]+)$ ]]; then
        echo "${ODOO_VERSION}.${BASH_REMATCH[1]}.$((${BASH_REMATCH[2]} + 1))";
    else
        return 1;
    fi
}



# ci_git_get_repo_version_by_ref [-q] <repo path> <ref>
function ci_git_get_repo_version_by_ref {
    if [ "$1" == "-q" ]; then
        local quiet=1;
        shift;
    fi

    local repo_path="$1"; shift;
    local git_ref="$1"; shift;
    local cdir="$(pwd)";
    local version;

    cd "$repo_path";
    if [ "$git_ref" == "-working-tree-" ]; then
        version=$(cat ./VERSION 2>/dev/null);
    else
        version=$(git show -q ${git_ref}:./VERSION 2>/dev/null);
    fi
    if [ $? -ne 0 ] || [ -z "$version" ]; then
        [ -z "$quiet" ] && echoe -e "${YELLOWC}WARNING${NC}: repository version file (${BLUEC}${repo_path}/VERSION${NC}) not found or empty (revision ${BLUEC}${git_ref}${NC}! Using default version ${BLUEC}${ODOO_VERSION}.0.0.0${NC}";
        echo "${ODOO_VERSION}.0.0.0"
        return 1;
    else
        echo "$version";
    fi

    cd "$cdir";
}

# ci_git_get_addon_version_by_ref [-q] <addon path> <ref>
function ci_git_get_addon_version_by_ref {
    if [ "$1" == "-q" ]; then
        local quiet=1;
        shift;
    fi

    local addon_path="$1"; shift;
    local git_ref="$1"; shift;
    local cdir="$(pwd)";

    local manifest_content;
    local version="${ODOO_VERSION}.0.0.0";

    cd "$addon_path";

    # Get manifest content at start revision
    if [ "$git_ref" == "-working-tree-" ]; then
        version=$(cat ./VERSION 2>/dev/null);
        manifest_content=$(cat ./__manifest__.py 2>/dev/null);
        if [ -z "$manifest_content" ]; then
            manifest_content=$(cat ./__openerp__.py 2>/dev/null);
        fi
    else
        manifest_content=$(git show -q ${git_ref}:./__manifest__.py 2>/dev/null);
        if [ -z "$manifest_content" ]; then
            manifest_content=$(git show -q ${git_ref}:./__openerp__.py 2>/dev/null);
        fi
    fi

    # Get version in first revision
    if [ -z "$manifest_content" ]; then
        local version="${ODOO_VERSION}.0.0.0";
    else
        local version=$(echo "$manifest_content" | execv python -c "\"import sys; print(eval(sys.stdin.read()).get('version', '${ODOO_VERSION}.1.0.0'))\"");
        if [ $? -ne 0 ]; then
            [ -z "$quiet" ] && echoe -e "${YELLOWC}WARNING${NC} Cannot read version from manifest in first revision! Using ${BLUEC}${ODOO_VERSION}.0.0.0${NC} as default.";
        fi
    fi
    echo "$version";
    cd "$cdir";
}

# ci_check_versions_git <repo> <ref start> <ref end>
function ci_check_versions_git {
    local usage="
    Check that versions of changed addons have been updated

    Usage:
        $SCRIPT_NAME ci check-versions-git [options] <repo> <start> [end]

    Options:
        --ignore-trans  - ignore translations
                          Note: this option may not work on old git versions
        --repo-version  - ensure repository version updated.
                          Repository version have to be specified in
                          file named VERSION placed in repository root.
                          Version have to be string of
                          5 numbers separated by dots.
                          For example: 11.0.1.0.0
                          Version number have to be updated if at least one
                          addon changed
        --fix-version   - [experimental] Attempt to fix versions
        -h|--help|help  - print this help message end exit

    Parametrs:
        <repo>    - path to git repository to search for changed addons in
        <start>   - git start revision
        [end]     - [optional] git end revision.
                    if not set then working tree used as end revision
    ";
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local git_changed_extra_opts;
    local repo_path;
    local ref_start;
    local ref_end;
    local check_repo_version=0;
    local opt_fix_version=0;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                shift;
                return 0;
            ;;
            --ignore-trans)
                git_changed_extra_opts="$git_changed_extra_opts --ignore-trans";
                shift;
            ;;
            --repo-version)
                check_repo_version=1;
                shift;
            ;;
            --fix-version)
                opt_fix_version=1;
                shift;
            ;;
            *)
                break;
            ;;
        esac
    done

    repo_path=$(readlink -f "$1"); shift;
    ref_start="$1"; shift;

    if [ -n "$1" ]; then
        ref_end="$1"; shift;
    else
        ref_end="-working-tree-";
    fi
    local cdir="$(pwd)";

    # Check addons versions
    local changed_addons=( $(git_get_addons_changed $git_changed_extra_opts "$repo_path" "$ref_start" "$ref_end") );
    local result=0;
    for addon_path in "${changed_addons[@]}"; do
        cd "$addon_path";
        local addon_name=$(basename "$addon_path");

        echoe -e "${BLUEC}Checking version of ${YELLOWC}${addon_name}${BLUEC} addon ...${NC}";
        local version_before=$(ci_git_get_addon_version_by_ref -q "$addon_path" "${ref_start}");
        local version_after=$(ci_git_get_addon_version_by_ref "$addon_path" "${ref_end}");

        if ! ci_validate_version "$version_after"; then
            if [ "$opt_fix_version" -eq 1 ]; then
                local new_version;
                new_version=$(ci_fix_version_serie "$version_after");
                if [ "$?" -eq 0 ]; then
                    sed -i "s/$version_after/$new_version/g" "$(addons_get_manifest_file $addon_path)";
                    version_after="$new_version";
                    echoe -e "${GREENC}OK${NC}: version serie fixed for addon ${YELLOWC}${addon_name}${NC}";
                else
                    echoe -e "${REDC}ERROR${NC}: Cannot fix version serie ${YELLOWC}${version_after}${NC}. Skipping...";
                fi
            else
                echoe -e "${REDC}FAIL${NC}: Wrong version format. Correct version must match format: ${YELLOWC}${ODOO_VERSION}.X.Y.Z${NC}. Got ${YELLOWC}${version_after}${NC}";
                result=1;
                continue;
            fi
        fi

        # Compare version
        if ci_ensure_versions_ok "$version_before" "$version_after"; then
            # version before is less that version_after
            echoe -e "${GREENC}OK${NC}";
        else
            if [ "$opt_fix_version" -eq 1 ]; then
                local new_version;
                new_version=$(ci_fix_version_serie "$version_after");
                if [ "$?" -eq 0 ]; then
                    sed -i "s/$version_after/$new_version/g" "$(addons_get_manifest_file $addon_path)";
                    echoe -e "${GREENC}OK${NC}: version number fixed for addon ${YELLOWC}${addon_name}${NC}";
                else
                    echoe -e "${REDC}ERROR${NC}: Cannot fix version number ${YELLOWC}${version_after}${NC}. Skipping...";
                fi
            else
                echoe -e "${REDC}FAIL${NC}: ${YELLOWC}${addon_name}${NC} have incorrect new version!"
                echoe -e "${BLUEC}-----${NC} new version ${YELLOWC}${version_after}${NC} must be greater than old version ${YELLOWC}${version_before}${NC}";
                result=1;
            fi
        fi

    done;

    # Check repo version
    if [ "$check_repo_version" -eq 1 ] && [ -n "${changed_addons}" ]; then
        local repo_version_before=$(ci_git_get_repo_version_by_ref -q "$repo_path" "$ref_start");
        local repo_version_after=$(ci_git_get_repo_version_by_ref "$repo_path" "$ref_end");
        if [ -z "$repo_version_after" ]; then
            echoe -e "${REDC}ERROR${NC}: repository version not specified! Please, specify repository version in ${YELLOWC}${repo_path}/VERSION${NC} file.";
            return 2;
        fi
        if ! ci_validate_version "$repo_version_after"; then
            echoe -e "${REDC}ERROR${NC}: Wrong repo version format. Correct version must match format: ${YELLOWC}${ODOO_VERSION}.X.Y.Z${NC}. Got ${YELLOWC}${repo_version_after}${NC}"
            return 2;
        fi
        if ci_ensure_versions_ok "$repo_version_before" "$repo_version_after"; then
            echoe -e "Repository version: ${GREENC}OK${NC}";
        else
            echoe -e "${REDC}FAIL${NC}: incorrect new repository version!"
            echoe -e "${BLUEC}-----${NC} new reposotory version ${YELLOWC}${repo_version_after}${NC} must be greater than old version ${YELLOWC}${repo_version_before}${NC}";
            result=1;
        fi
    fi
    cd "$cdir";
    return $result;
}


# Ensure that all addons in specified directory have icons
# ci_ensure_addons_have_icons <addon path>
function ci_ensure_addons_have_icons {
    local usage="
    Ensure that all addons in specified directory have icons.

    Usage:

        $SCRIPT_NAME ci ensure-icons <addon path>  - ensure addons have icons
        $SCRIPT_NAME ci ensure-icons --help        - print this help message
    ";

    # Parse options
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    local addons_path="$1";
    if [ ! -d "$addons_path" ]; then
        echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${addons_path}${NC} is not a directory!";
        return 1;
    fi

    local res=0;
    for addon in $(addons_list_in_directory --installable "$1"); do
        if [ ! -f "$addon/static/description/icon.png" ]; then
            echoe -e "${REDC}ERROR${NC}: addon ${YELLOWC}${addon}${NC} have no icon!";
            res=1;
        fi
    done

    return $res;
}

function ci_command {
    local usage="
    This command provides subcommands useful in Continious Integration process

    NOTE: This command is experimental and everything may be changed.

    Usage:
        $SCRIPT_NAME ci check-versions-git [--help]  - ensure versions of changed addons were updated
        $SCRIPT_NAME ci ensure-icons [--help]        - ensure all addons in specified directory have icons
        $SCRIPT_NAME ci -h|--help|help               - show this help message
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            check-versions-git)
                shift;
                ci_check_versions_git "$@";
                return;
            ;;
            ensure-icons)
                shift;
                ci_ensure_addons_have_icons "$@";
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
