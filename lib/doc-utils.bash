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
            elif [ "$field_type" == "custom" ]; then
                t_name="";
            else
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
                continue
            fi

            if [ "$format" == "md" ]; then
                result="${result} ${t_name} |";
            elif [ "$format" == "csv" ]; then
                result="${result}\"${t_name}\",";
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
                t_res=$(addons_get_manifest_key "$addon" "$field_name" "''" | tr '\n' ' ');
                t_res=$(trim "$t_res");
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
            elif [ "$field_type" == "custom" ]; then
                t_res="$field_name";
            else
                echoe -e "${REDC}ERROR${NC}: cannot parse field '${YELLOWC}${field}${NC}'! Skipping...";
            fi
            if [ "$format" == "md" ]; then
                result="${result} ${t_res} |";
            elif [ "$format" == "csv" ]; then
                result="${result}\"${t_res}\",";
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
        --custom-val <val>         - custom value
        --recursive                - search for addons recusively
        --installable              - installable only

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

    local addons_list_opts=( );

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
            --custom-val)
                field_names+=( "custom-$2" );
                shift;
            ;;
            --no-header)
                local no_header=1;
            ;;
            --format)
                local format=$2;
                shift;
            ;;
            --recursive)
                addons_list_opts+=( --recursive );
            ;;
            --installable)
                addons_list_opts+=( --installable );
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
    mapfile -t addons_list < <(addons_list_in_directory "${addons_list_opts[@]}" "$addons_path");
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

function doc_utils_module_graph {
    local usage="
    ${YELLOWC}Warning${NC}:
        This command is experimental and may be changed in future

    Usage:

        $SCRIPT_NAME doc-utils addons-graph [options] <path>   - build depedency graph for addons in directory
        $SCRIPT_NAME doc-utils addons-graph --help             - show this help message

    Options
        --out <path>   - output path (default ./graph.svg)

    ";


    local out_path;
    out_path="$(pwd)/graph.svg";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --out)
                out_path="$2";
                shift;
            ;;
            -h|--help|help)
                echo -e "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
        shift;
    done
    local addons_path="$1";

    local tmp_graph_file;
    tmp_graph_file="/tmp/oh-module-graph-$(date -I)-$(random_string 4).gv";
    echo "digraph G {" > "$tmp_graph_file";
    echo "    graph [concentrate=true];" >> "$tmp_graph_file";
    echo "    graph [K=1.0];" >> "$tmp_graph_file";
    echo "    graph [minlen=3];" >> "$tmp_graph_file";
    echo "    graph [nodesep=1.0];" >> "$tmp_graph_file";
    echo "    graph [ranksep=2.0];" >> "$tmp_graph_file";

    addons_path=${addons_path:-$ADDONS_DIR};
    local addons_list;
    #mapfile -t addons_list < <(addons_list_in_directory "${addons_list_opts[@]}" "$addons_path");
    mapfile -t addons_list < <(addons_list_in_directory "$addons_path");
    for addon_path in "${addons_list[@]}"; do
        local addon_name;
        addon_name=$(addons_get_addon_name "$addon_path");
        local deps_str;
        deps_str=$(addons_get_addon_dependencies "$addon_path");
        local deps;
        IFS=" " read -a deps <<< "$deps_str";
        for dep in "${deps[@]}"; do
            echo "    $addon_name -> $dep;" >> "$tmp_graph_file";
        done
    done;
    echo "}" >> "$tmp_graph_file";
    dot -Tsvg -o "$out_path" "$tmp_graph_file";
    rm "$tmp_graph_file";
}


function doc_utils_command {
    local usage="
    Usage:

        $SCRIPT_NAME doc-utils addons-list --help            - list addons in specified directory
        $SCRIPT_NAME doc-utils addons-graph --help           - generate graph with addons dependencies
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
            addons-graph)
                shift;
                doc_utils_module_graph "$@";
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
