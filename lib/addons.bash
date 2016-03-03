if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

ohelper_require 'git'
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# List addons repositories
# Note that this function list only addons that are under git control
#
# addons_list_repositories [addons_path]
function addons_list_repositories {
    local addons_path=${1:-$ADDONS_DIR};

    if [ ! -z $addons_path ]; then
        for addon in "$addons_path"/*; do
            if is_odoo_module $addon && git_is_git_repo $addon; then
                echo "$(git_get_abs_repo_path $addon)";
            fi
        done | sort -u;
    fi
}


# Lists addons that do not belong to any git repository
# Note, that addons that are under git controll will not be listed
#
# addons_list_no_repository [addons_path]
function addons_list_no_repository {
    local addons_path=${1:-$ADDONS_DIR};

    if [ ! -z $addons_path ]; then
        for addon in "$addons_path"/*; do
            if is_odoo_module $addon && ! git_is_git_repo $addon; then
                echo "$(readlink -f $addon)";
            fi
        done | sort -u;
    fi
}


# Show git status for each addon
# show_addons_status
function addons_show_status {
    local addons_dir=$ADDONS_DIR;
    local cdir=$(pwd);

    local usage="
    Usage 

        $SCRIPT_NAME addons show_status [options]

    Options:
        --addons-dir          - directory to search addons in. By default used one from
                                project config
        --only-unclean        - show only addons in unclean repo state
        --ignore-no-git-repo  - do not show addons that are not in any git repository
        --help|-h             - diplay this help message
    ";

    # Parse command line options and run commands
    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            --addons-dir)
                local addons_dir=$2;
                shift;
            ;;
            --only-unclean)
                local only_unclean=1
            ;;
            --ignore-no-git-repo)
                local ignore_no_git_repo=1;
            ;;
            *)
                echo "Unknown option: $key";
                exit 1;
            ;;
        esac;
        shift;
    done;

    local git_status=;
    for addon_repo in $(addons_list_repositories $addons_dir); do
        IFS=$'\n' git_status=( $(git_parse_status $addon_repo || echo '') );
        if [ -z $git_status ]; then
            echo -e "No info available for addon $addon_repo";
            continue;
        fi

        if [ ! -z $only_unclean ] && [ ${git_status[3]} -eq 1 ]; then
            continue
        fi

        echo -e "Addon status for ${BLUEC}$addon_repo${NC}'";
        echo -e "\tRepo branch:          ${git_status[0]}";
        echov -e "\tRepo remote status:   ${git_status[1]}";
        echov -e "\tRepo upstream:        ${git_status[2]}";

        [ ${git_status[3]} -eq 1 ] && echo -e "\t${GREENC}Repo is clean!${NC}";
        [ ${git_status[4]} -gt 0 ] && echo -e "\t${YELLOWC}${git_status[4]} files staged for commit${NC}";
        [ ${git_status[5]} -gt 0 ] && echo -e "\t${YELLOWC}${git_status[5]} files changed${NC}";
        [ ${git_status[6]} -gt 0 ] && echo -e "\t${REDC}${git_status[6]} conflicts${NC}";
        [ ${git_status[7]} -gt 0 ] && echo -e "\t${YELLOWC}${git_status[7]} untracked files${NC}";
        [ ${git_status[8]} -gt 0 ] && echo -e "\t${YELLOWC}${git_status[8]} stashed${NC}";

    done;

    if [ -z $ignore_no_git_repo ]; then
        for addon_path in $(addons_list_no_repository $addons_dir); do
            echo -e "Addon status for ${BLUEC}$addon_path${NC}'";
            echo -e "\t${REDC}Warning: not under git controll${NC}";
        done
    fi
}

function addons_command {
    local usage="Usage:

        $SCRIPT_NAME addons list_repos [addons path]    - list git repositories
        $SCRIPT_NAME addons list_no_repo [addons path]  - list addons not under git repo
        $SCRIPT_NAME addons show_status --help          - show addons status
        $SCRIPT_NAME addons --help

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            list_repos)
                shift;
                addons_list_repositories "$@";
                exit 0;
            ;;
            list_no_repo)
                shift;
                addons_list_no_repository "$@";
                exit 0;
            ;;
            show_status)
                shift;
                addons_show_status "$@";
                exit 0;
            ;;
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            *)
                echo "Unknown option / command $key";
                exit 1;
            ;;
        esac
        shift
    done
}
