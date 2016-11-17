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
ohelper_require 'fetch';
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
# NOTE: Odoo 8.0+ required
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

# Update list of addons visible in system (for single db)
# NOTE: Odoo 8.0+ required
# addons_update_module_list <db> [conf_file]
function addons_update_module_list_db {
    local db=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import erppeek; cl=erppeek.Client(['-c', '$conf_file']);";
    python_cmd="$python_cmd odoo=cl._server; reg=odoo.registry('$db');";
    python_cmd="$python_cmd env=odoo.api.Environment(reg.cursor(), 1, {});";
    python_cmd="$python_cmd res=env['ir.module.module'].update_list();";
    python_cmd="$python_cmd env.cr.commit();";
    python_cmd="$python_cmd print('updated: %d\nadded: %d\n' % tuple(res));";

    execu python -c "\"$python_cmd\"";
}


# Update list of addons visible in system for db or all databases
# NOTE: Odoo 8.0+ required
# addons_update_module_list [db] [conf_file]
function addons_update_module_list {
    local db=$1;

    if [ ! -z $db ]; then
        echo -e "${BLUEC}Updating module list for ${YELLOWC}$db${NC}";
        addons_update_module_list_db $db;
    else
        for db in $(odoo_db_list); do
            echo -e "${BLUEC}Updating module list for ${YELLOWC}$db${NC}";
            addons_update_module_list_db $db;
        done
    fi
}


# List addons in specified directory
#
# addons_list_in_directory <directory to search odoo addons in>
#
# Note: this funtion lists addon paths
function addons_list_in_directory {
    local addons_path=${1:-$ADDONS_DIR};
    if [ -d $addons_path ]; then
        for addon in "$addons_path"/*; do
            if is_odoo_module $addon; then
                echo "$(readlink -f $addon)";
            fi
        done
    fi
}


# List addons in specified directory by name
# This function prints only name of addons found in specified dir.
# Not paths!
#
# addons_list_in_directory_by_name <directory to search odoo addons in>
function addons_list_in_directory_by_name {
    for addon_path in $(addons_list_in_directory $1); do
        echo "$(basename $addon_path)";
    done
}


# List addons repositories
# Note that this function list only addons that are under git control
#
# addons_list_repositories [addons_path]
function addons_list_repositories {
    local addons_path=${1:-$ADDONS_DIR};

    for addon in $(addons_list_in_directory $addons_path); do
        if git_is_git_repo $addon; then
            echo "$(git_get_abs_repo_path $addon)";
        fi
    done | sort -u;
}


# Lists addons that do not belong to any git repository
# Note, that addons that are under git controll will not be listed
#
# addons_list_no_repository [addons_path]
function addons_list_no_repository {
    local addons_path=${1:-$ADDONS_DIR};

    for addon in $(addons_list_in_directory $addons_path); do
        if ! git_is_git_repo $addon; then
            echo "$(readlink -f $addon)";
        fi
    done | sort -u;
}


# generate_requirements [addons path]
# prints odoo-requirements file content (only addons which are git repositories)
function addons_generate_requirements {
    local req_addons_dir=${1:-$ADDONS_DIR};
    for repo in $(addons_list_repositories $req_addons_dir); do
      echo "-r $(git_get_remote_url $repo) -b $(git_get_branch_name $repo)";
    done
}


# Check for git updates for addons
# addons_git_fetch_updates [addons path]
function addons_git_fetch_updates {
    local addons_dir=${1:-$ADDONS_DIR};
    # fetch updates for each addon repo
    for addon_repo in $(addons_list_repositories $addons_dir); do
        (cd $addon_repo && git fetch) || true;
    done
}

# Update git repositories
# addons_git_pull_updates [addons path]
function addons_git_pull_updates {
    local addons_dir=${1:-$ADDONS_DIR};
    for addon_repo in $(addons_list_repositories $addons_dir); do
        IFS=$'\n' git_status=( $(git_parse_status $addon_repo || echo '') );
        local git_remote_status=${git_status[1]};
        if [[ $git_remote_status == _BEHIND_* ]] && [[ $git_remote_status != *_AHEAD_* ]]; then
            (cd $addon_repo && git pull && link_module .);
        fi
    done

    # update list available modules for all databases
    addons_update_module_list
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
        --only-git-updates    - display only addons that are not up to date with remotes
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
                local only_unclean=1;
            ;;
            --only-git-updates)
                local only_git_updates=1;
                local ignore_no_git_repo=1;
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

        # if '--only-unclean' specified, skip addons that are clean
        if [ ! -z $only_unclean ] && [ ${git_status[3]} -eq 1 ]; then
            continue
        fi

        # if '--only-git-updates' specified, skip addons which is up to date
        if [ ! -z $only_git_updates ] && [ ${git_status[1]} == "." ]; then
            continue
        fi

        # Display addon status
        echo -e "Addon status for ${BLUEC}$addon_repo${NC}'";
        echo -e "\tRepo branch:          ${git_status[0]}";
        echo -e "\tRepo remote:          $(git_get_remote_url $addon_repo)";
        [ ${git_status[1]} != "." ] && echo -e "\t${YELLOWC}Remote: ${git_status[1]}${NC}";
        [ ${git_status[1]} != "." ] && echo -e "\t${YELLOWC}Upstream: ${git_status[2]}${NC}";
        [ ${git_status[3]} -eq 1 ]  && echo -e "\t${GREENC}Repo is clean!${NC}";
        [ ${git_status[4]} -gt 0 ]  && echo -e "\t${YELLOWC}${git_status[4]} files staged for commit${NC}";
        [ ${git_status[5]} -gt 0 ]  && echo -e "\t${YELLOWC}${git_status[5]} files changed${NC}";
        [ ${git_status[6]} -gt 0 ]  && echo -e "\t${REDC}${git_status[6]} conflicts${NC}";
        [ ${git_status[7]} -gt 0 ]  && echo -e "\t${YELLOWC}${git_status[7]} untracked files${NC}";
        [ ${git_status[8]} -gt 0 ]  && echo -e "\t${YELLOWC}${git_status[8]} stashed${NC}";

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

    todo_addons="${todo_addons#,}";  # remove first comma

    if [ -z $todo_addons ]; then
        echo "No addons specified! Exiting";
        return 1;
    fi

    # If no database specified, install/update addons
    # to all available databases
    if [ -z $dbs ]; then
        dbs=$(odoo_db_list);
    fi

    [ "$cmd" == "install" ] && local cmd_opt="-i";
    [ "$cmd" == "update" ]  && local cmd_opt="-u";

    if [ -z $cmd_opt ]; then
        echo -e "${REDC}ERROR: Wrong command '$cmd'${NC}";
    fi

    server_stop;
    for db in $dbs; do
        if server_run -d $db $cmd_opt $todo_addons --stop-after-init; then
            echo -e "${LBLUEC}Update for '$db':${NC} ${GREENC}OK${NC}";
        else
            echo -e "${LBLUEC}Update for '$db':${NC} ${REDC}FAIL${NC}";
        fi
    done
    server_start;
}


function addons_command {
    local usage="Usage:

        $SCRIPT_NAME addons list_repos [addons path]      - list git repositories
        $SCRIPT_NAME addons list_no_repo [addons path]    - list addons not under git repo
        $SCRIPT_NAME addons check_updates [addons path]   - Check for git updates of addons and displays status
        $SCRIPT_NAME addons pull_updates [addons path]    - Pull changes from git repos
        $SCRIPT_NAME addons status --help                 - show addons status
        $SCRIPT_NAME addons update [-d <db>] <name>       - update some addon
        $SCRIPT_NAME addons install [-d <db>] <name>      - update some addon
        $SCRIPT_NAME addons update-list [db]              - update list of addons
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
            check_updates)
                shift;
                ADDONS_DIR=${1:-$ADDONS_DIR};
                addons_git_fetch_updates;
                addons_show_status --only-git-updates;
                exit 0;
            ;;
            pull_updates)
                shift;
                echo -e "${LBLUEC}Checking for updates...${NC}";
                addons_git_fetch_updates "$@";
                echo -e "${LBLUEC}Applying updates...${NC}";
                addons_git_pull_updates "$@";
                echo -e "${GREENC}DONE${NC}";
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
