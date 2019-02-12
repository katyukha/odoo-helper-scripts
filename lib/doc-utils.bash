# Copyright © 2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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

ohelper_require 'addons';
ohelper_require 'utils';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# Internal function to print info about single addon
# doc_utils_addons_list_addon_info_header <format> <field 1> [field 2] ... [field n]
function doc_utils_addons_list_addon_info_header {
    local format=$1; shift;
    local field_regex="([^-]+)-(.+)"

    if [ "$format" == "md" ]; then
        local result="|"
    elif [ "$format" == "csv" ]; then
        local result="";
    fi

    for field in "$@"; do
        if ! [[ $field =~ $field_regex ]]; then
            echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
        else
            local t_name;
            local field_type=${BASH_REMATCH[1]};
            local field_name=${BASH_REMATCH[2]};

            if [ "$field_type" == "manifest" ]; then
                t_name="${field_name^}";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "name" ]; then
                t_name="System Name";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "git_repo" ]; then
                t_name="Git URL";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "dependencies" ]; then
                t_name="Dependencies";
            else
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
                continue
            fi

            if [ "$format" == "md" ]; then
                result="${result} ${t_name} |";
            elif [ "$format" == "csv" ]; then
                result="${result}\"${t_name}\";";
            fi

        fi
    done

    if [ "$format" == "md" ]; then
        result="$result\n|";
        for field in "$@"; do
            if ! [[ $field =~ $field_regex ]]; then
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
            else
                result="${result}---|";
            fi
        done
    fi
    echo "$result";

}


# Internal function to print info about single addon
# doc_utils_addons_list_addon_info <format> <addon path> <field 1> [field 2] ... [field n]
function doc_utils_addons_list_addon_info {
    # Field names is space separated list of names of fields to display.
    # field name consist of two parts: <field-type>-<field-name>
    # field type could be:
    #    - manifest
    #    - system
    # system fields could be following
    #    - name
    #    - git_repo
    local field_regex="([^-]+)-(.+)"

    local format=$1; shift;
    local addon=$1; shift;

    if [ "$format" == "md" ]; then
        local result="|"
    elif [ "$format" == "csv" ]; then
        local result="";
    fi
    for field in "$@"; do
        if ! [[ $field =~ $field_regex ]]; then
            echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
        else
            local t_res="";
            local field_type=${BASH_REMATCH[1]};
            local field_name=${BASH_REMATCH[2]};

            if [ "$field_type" == "manifest" ]; then
                t_res=$(addons_get_manifest_key "$addon" "$field_name" | tr '\n' ' ');
            elif [ "$field_type" == "system" ] && [ "$field_name" == "name" ]; then
                t_res=$(basename "$addon");
            elif [ "$field_type" == "system" ] && [ "$field_name" == "git_repo" ]; then
                if git_is_git_repo "$addon"; then
                    t_res=$(git_get_remote_url "$addon");
                else
                    t_res="Not in git repository";
                fi
            elif [ "$field_type" == "system" ] && [ "$field_name" == "dependencies" ]; then
                t_res=$(addons_get_addon_dependencies "$addon");
            else
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
            fi
            if [ "$format" == "md" ]; then
                result="${result} ${t_res} |";
            elif [ "$format" == "csv" ]; then
                result="${result}\"${t_res}\";";
            fi
        fi
    done

    echo "$result";

}
# Print addons table in markdown table
function doc_utils_addons_list {
    local usage="
    Usage:

        $SCRIPT_NAME doc-utils addons-list [options] [addons path]   - list addons in specified directory
        $SCRIPT_NAME doc-utils addons-list --help                    - show this help message

    Options
        -f|--field <field name>    - display name of field in manifest
        --git-repo                 - display git repository
        --sys-name                 - display system name
        --no-header                - do not display header
        --dependencies             - display dependencies list separated by coma
        --format <md|csv>          - output format. default: md

    Description
        Prints list of addons in specified dierectory in markdown format.

        Could be used like:
            $ odoo-helper doc-utils addons-list ./my_addon_repo/ > addons.md

        Or
            $ odoo-helper doc-utils addons-list ./my-repo-1 && odoo-helper doc-utils addons-list ./my-repo-2 > addons.md

        Default options is following:
            --sys-name -f name -f version -f summary

        Result looks like

            | System Name | Name | Version | Summary |
            |---|---|---|---|
            | my_addon | My Addon | 11.0.0.1.0 | My Cool Addon |
            | my_addon_2 | My Addon 2 | 11.0.0.2.0 | My Cool Addon 2 |
    ";

    # look at doc_utils_addons_list_addon_info for info
    local field_names=( );

    local addons_path=;
    local format="md";

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -f|--field)
                field_names+=( "manifest-$2" );
                shift;
            ;;
            --sys-name)
                field_names+=( system-name );
            ;;
            --git-repo)
                field_names+=( system-git_repo );
            ;;
            --dependencies)
                field_names+=( system-dependencies );
            ;;
            --no-header)
                local no_header=1;
            ;;
            --format)
                local format=$2;
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                addons_path=$key;
                shift;
                break;
            ;;
        esac
        shift;
    done

    addons_path=${addons_path:-$ADDONS_DIR};
    if [ ${#field_names[@]} -eq 0 ]; then
        field_names=( system-name manifest-name manifest-version manifest-summary );
    fi

    if [ -z "$no_header" ]; then
        result=$(doc_utils_addons_list_addon_info_header "$format" "${field_names[@]}");
    else
        result=;
    fi

    local addons_list;
    mapfile -t addons_list < <(addons_list_in_directory "$addons_path");
    for addon in "${addons_list[@]}"; do
        local addon_info;
        addon_info=$(doc_utils_addons_list_addon_info "$format" "$addon" "${field_names[@]}");
        if [ -z "$result" ]; then
            result=$addon_info;
        else
            result="${result}\n$addon_info";
        fi
    done

    echo -e "$result";
}


function doc_utils_command {
    local usage="
    Usage:

        $SCRIPT_NAME doc-utils addons-list --help             - list addons in specified directory
        $SCRIPT_NAME doc-utils --help                        - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            addons-list)
                shift;
                doc_utils_addons_list "$@";
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
