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


# ci_check_versions_git <repo> <ref start> <ref end>
function ci_check_versions_git {
    local usage="
    Check that versions of changed addons have been updated

    Usage:
        $SCRIPT_NAME ci check-versions-git [options] <repo> <start> <end>

    Options:
        -h|--help|help  - print this help message end exit

    Parametrs:
        <repo>    - path to git repository to search for changed addons in
        <start>   - git start revision
        <end>     - git end revision
    ";
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
                shift;
                return 0;
            ;;
            *)
                break;
            ;;
        esac
    done

    local repo_path="$1"; shift;
    local ref_start="$1"; shift;
    local ref_end="$1"; shift;
    local cdir="$(pwd)";

    local changed_addons=( $(git_get_addons_changed --exclude-trans $repo_path $ref_start $ref_end) );
    local result=0;
    for addon_path in "${changed_addons[@]}"; do
        cd "$addon_path";

        # Get manifest content at start revision
        local manifest_content_before="$(git show -q ${ref_start}:./__manifest__.py 2>/dev/null)";
        if [ -z "$manifest_content_before" ]; then
            local manifest_content_before="$(git show -q ${ref_start}:./__openerp__.py 2>/dev/null)";
        fi

        # Get manifest content at and revision
        local manifest_content_after="$(git show -q ${ref_end}:./__manifest__.py 2>/dev/null)";
        if [ -z "$manifest_content_after" ]; then
            local manifest_content_after="$(git show -q ${ref_end}:./__openerp__.py 2>/dev/null)";
        fi

        # Get version in first revision
        if [ -z "$manifest_content_before" ]; then
            local version_before="${ODOO_VERSION}.0.0.0";
        else
            local file_name="/tmp/oh-ci-vc-git-$ref_start-$(random_string)";
            echo "$manifest_content_before" > $file_name;
            local version_before=$(run_python_cmd "print(eval(open('$file_name', 'rt').read()).get('version', '${ODOO_VERSION}.1.0.0'))");
            if [ $? -ne 0 ]; then
                echoe -e "${YELLOWC}WARNING${NC} Cannot read version from manifest in first revision! Using ${BLUEC}${ODOO_VERSION}.0.0.0${NC} as default.";
            fi
            rm -f "$file_name";
        fi

        # Get version in second revision
        if [ -z "$manifest_content_after" ]; then
            echoe -e "${YELLOWC}WARNING${NC} cannot find manifest in second revision. it seems that it was removed.";
            continue
        fi
        local file_name="/tmp/oh-ci-vc-git-$ref_end-$(random_string)";
        echo "$manifest_content_after" > $file_name;
        local version_after=$(run_python_cmd "print(eval(open('$file_name', 'rt').read()).get('version', '${ODOO_VERSION}.1.0.0'))");
        if [ $? -ne 0 ]; then
            echoe -e "${REDC}ERRoR${NC} Cannot read version from manifest in second revision! It seems that manifest is broken!";
            result=1;
            rm -f "$file_name";
            continue
        fi
        rm -f "$file_name";

        # Compare version
        # NOTE: here we inverse pythons True to bash zero status code
        if ! run_python_cmd "from pkg_resources import parse_version as V; exit(V('${version_before}') < V('${version_after}'));"; then
            # version before is less that version_after
            echoe -e "$(basename $addon_path): ${GREENC}OK${NC}";
        else
            echoe -e "$(basename $addon_path): ${REDC}FAIL${NC} - incorrect new version! new version (${YELLOWC}${version_after}${NC}) must be greater than old version (${YELLOWC}${version_before}${NC})";
            result=1;
        fi

    done;
    cd "$cdir";
    return $result;
}

function ci_command {
    local usage="
    This command provides subcommands useful in Continious Integration process

    NOTE: This command is experimental and everything may be changed.

    Usage:
        $SCRIPT_NAME ci check-versions-git [--help]  - show list of addons changed
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
