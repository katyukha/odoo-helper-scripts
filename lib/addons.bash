if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

ohelper_require 'git';
ohelper_require 'db';
ohelper_require 'server';
ohelper_require 'odoo';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# Echo path to addon specified by name
# addons_get_addon_path <addon>
function addons_get_addon_path {
    local addon=$1;
    local addons_path=$(odoo_get_conf_val addons_path);
    local addon_dirs=;

    # note addon_dirs is array
    IFS=',' read -r -a addon_dirs <<< "$addons_path";

    local addon_path=$(search_file_in $addon ${addon_dirs[@]});
    echo "$addon_path";
}

# Get list of installed addons
# addons_get_installed_addons <db> [conf_file]
function addons_get_installed_addons {
    local db=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd odoo=cl._server; reg=odoo.registry('$db'); env=odoo.api.Environment(reg.cursor(), 1, {});";
    python_cmd="$python_cmd installed_addons=env['ir.module.module'].search([('state', '=', 'installed')]);"
    python_cmd="$python_cmd print ','.join(installed_addons.mapped('name'));"

    execu python -c "\"$python_cmd\"";
}

# Update list of addons visible in system
# addons_update_module_list <db> [conf_file]
function addons_update_module_list {
    local db=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd odoo=cl._server; reg=odoo.registry('$db');";
    python_cmd="$python_cmd env=odoo.api.Environment(reg.cursor(), 1, {});";
    python_cmd="$python_cmd res=env['ir.module.module'].update_list();";
    python_cmd="$python_cmd env.cr.commit();";
    python_cmd="$python_cmd print('updated: %d\nadded: %d\n' % tuple(res));";

    echo $python_cmd

    execu python -c "\"$python_cmd\"";
}

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


# generate_requirements [addons path]
# prints odoo-requirements file content (only addons which are git repositories)
function addons_generate_requirements {
    local req_addons_dir=${1:-$ADDONS_DIR};
    for repo in $(addons_list_repositories $req_addons_dir); do
      echo "-r $(git_get_remote_url $repo) -b $(git_get_branch_name $repo)";
    done
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


# Install or update addons
# addons_install_update <install|update>
function addons_install_update {
    local cmd="$1";
    shift;
    local usage="Usage:

        $SCRIPT_NAME addons $cmd [-d <db>] <addons>    - $cmd some addons
        $SCRIPT_NAME addons $cmd --help

        if -d <db> argument is not passed '$cmd' will be executed on all databases
        <addons> is comma-separated or space-separated list of addons

    ";
    local dbs="";
    local todo_addons="";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -d|--db)
                dbs=$dbs$'\n'$2;
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            *)
                todo_addons="$todo_addons,$1";
            ;;
        esac
        shift
    done

    if [ -z $dbs ]; then
        dbs=$(odoo_db_list);
    fi

    server_stop;
    for db in $dbs; do
        if [ "$cmd" == "install" ]; then
            server_run -d $db -i $todo_addons --stop-after-init
        elif [ "$cmd" == "update" ]; then
            server_run -d $db -u $todo_addons --stop-after-init
        else
            echo -e "${REDC}ERROR: Wrong command '$cmd'${NC}";
        fi
    done
    server_start;
}


function addons_command {
    local usage="Usage:

        $SCRIPT_NAME addons list_repos [addons path]      - list git repositories
        $SCRIPT_NAME addons list_no_repo [addons path]    - list addons not under git repo
        $SCRIPT_NAME addons status --help                 - show addons status
        $SCRIPT_NAME addons update [-d <db>] <name>       - update some addon
        $SCRIPT_NAME addons install [-d <db>] <name>      - update some addon
        $SCRIPT_NAME addons update-list <db>              - updaate list of addons
        $SCRIPT_NAME addons --help                        - show this help message

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
            status|show_status)
                shift;
                addons_show_status "$@";
                exit 0;
            ;;
            update)
                shift;
                addons_install_update "update" "$@";
                exit 0;
            ;;
            install)
                shift;
                addons_install_update "install" "$@";
                exit 0;
            ;;
            update-list)
                shift;
                addons_update_module_list "$@";
                exit 0;
            ;;
            generate_requirements)
                shift;
                addons_generate_requirements "$@";
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
