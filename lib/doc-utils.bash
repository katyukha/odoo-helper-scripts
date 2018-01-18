if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

ohelper_require 'addons';
#ohelper_require 'db';
#ohelper_require 'server';
#ohelper_require 'odoo';
#ohelper_require 'fetch';
ohelper_require 'utils';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# Internal function to print info about single addon
# doc_utils_addons_list_addon_info_header <field 1> [field 2] ... [field n]
function doc_utils_addons_list_addon_info_header {
    local field_regex="([^-]+)-(.+)"

    local result="|"
    for field in $@; do
        if ! [[ $field =~ $field_regex ]]; then
            echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
        else
            local field_type=${BASH_REMATCH[1]};
            local field_name=${BASH_REMATCH[2]};

            if [ "$field_type" == "manifest" ]; then
                result="${result} ${field_name^} |";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "name" ]; then
                result="${result} System Name |";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "git_repo" ]; then
                result="${result} Git URL |";
            else
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
            fi
        fi
    done

    result="$result\n|";

    for field in $@; do
        if ! [[ $field =~ $field_regex ]]; then
            echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
        else
            result="${result}---|";
        fi
    done
    echo "$result";

}


# Internal function to print info about single addon
# doc_utils_addons_list_addon_info <addon path> <field 1> [field 2] ... [field n]
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

    local addon=$1; shift

    local result="|"
    for field in $@; do
        if ! [[ $field =~ $field_regex ]]; then
            echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
        else
            local field_type=${BASH_REMATCH[1]};
            local field_name=${BASH_REMATCH[2]};

            if [ "$field_type" == "manifest" ]; then
                local t_res=$(addons_get_manifest_key $addon $field_name | tr '\n' ' ');
                result="${result} ${t_res}|";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "name" ]; then
                result="${result} $(basename $addon) |";
            elif [ "$field_type" == "system" ] && [ "$field_name" == "git_repo" ]; then
                result="${result} $(git_get_remote_url $addon) |";
            else
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
            fi
        fi
    done

    echo "$result";

}
# Print addons table in markdown table
function doc_utils_addons_list {
    local usage="Usage:

        $SCRIPT_NAME doc-utils addons-list [options] [addons path]   - list addons in specified directory
        $SCRIPT_NAME doc-utils addons-list --help                    - show this help message

    Options
        -f|--field <field name>    - display name of field in manifest
        --git-repo                 - display git repository
        --sys-name                 - display system name
        --no-header                - do not display header

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
    local field_names=;

    local addons_path=;

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -f|--field)
                field_names="$field_names manifest-$2";
                shift;
            ;;
            --sys-name)
                field_names="$field_names system-name";
            ;;
            --git-repo)
                field_names="$field_names system-git_repo";
            ;;
            --no-header)
                local no_header=1;
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
    field_names=${field_names:-"system-name manifest-name manifest-version manifest-summary"};

    if [ -z $no_header ]; then
        result="$(doc_utils_addons_list_addon_info_header $field_names)";
    else
        result=;
    fi

    for addon in $(addons_list_in_directory $addons_path); do
        local addon_info=$(doc_utils_addons_list_addon_info $addon $field_names);
        if [ -z "$result" ]; then
            result=$addon_info;
        else
            result="${result}\n$addon_info";
        fi
    done

    echo -e "$result";
}


function doc_utils_command {
    local usage="Usage:

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
                doc_utils_addons_list $@;
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
