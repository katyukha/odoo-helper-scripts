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
ohelper_require 'utils';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# Get odoo addon manifest file
# addons_get_manifest_file <addon path>
function addons_get_manifest_file {
    if [ -f "$1/__openerp__.py" ]; then
        echo "$1/__openerp__.py";
    elif [ -f "$1/__manifest__.py" ]; then
        echo "$1/__manifest__.py";
    else
        return 2;
    fi
}

# Get value of specified key from manifest
#
# addons_get_manifest_key <addon> <key>
function addons_get_manifest_key {
    local addon_path=$1;
    local key=$2;

    local manifest_file="$(addons_get_manifest_file $addon_path)";
    run_python_cmd "print(eval(open('$manifest_file', 'rt').read()).get('$key', None))"
}

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

# Check if addon is installable
#
# Return 0 if addon is installable else 1;
#
# addons_is_installable <addon_path>
function addons_is_installable {
    local addon_path=$1;
    local manifest_file="$(addons_get_manifest_file $addon_path)";
    if run_python_cmd "exit(not eval(open('$manifest_file', 'rt').read()).get('installable', True))"; then
        return 0;
    else
        return 1;
    fi
}

# Get list of addon dependencies
# addons_get_addon_dependencies <addon path>
function addons_get_addon_dependencies {
    local addon_path=$1;
    local manifest_file="$(addons_get_manifest_file $addon_path)";

    echo $(run_python_cmd "print(' '.join(eval(open('$manifest_file', 'rt').read()).get('depends', [])))");
}

# Get list of installed addons
# addons_get_installed_addons <db> [conf_file]
function addons_get_installed_addons {
    local db=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd installed_addons=cl['$db']['ir.module.module'].search([('state', '=', 'installed')]);"
    python_cmd="$python_cmd print(','.join(installed_addons.mapped('name')));"

    run_python_cmd "$python_cmd";
}

# Update list of addons visible in system (for single db)
# addons_update_module_list <db> [conf_file]
function addons_update_module_list_db {
    local db=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};

    local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$conf_file']);";
    python_cmd="$python_cmd res=cl['$db']['ir.module.module'].update_list();";
    python_cmd="$python_cmd cl['$db'].cursor.commit();";
    python_cmd="$python_cmd print('updated: %d\nadded: %d\n' % tuple(res));";

    run_python_cmd "$python_cmd";
}


# Update list of addons visible in system for db or all databases
# addons_update_module_list [db] [conf_file]
function addons_update_module_list {
    local db=$1;

    # TODO: improve performance of all databases case

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
# addons_list_in_directory [options] <directory to search odoo addons in>
#
# Note: this funtion lists addon paths
function addons_list_in_directory {
    # TODO: add ability to filter only installable addons
    # Process all args that starts with '-' (ie. options)
    local usage="
    Usage:

        $SCRIPT_NAME addons list [options] <path>
        $SCRIPT_NAME addons list --help

    Options:

        -r|--recursive    - look for addons recursively
        --installable     - display only installable addons
        --by-name         - display only addon names
        -h|--help|help    - display this help message
    ";

    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -r|--recursive)
                local recursive=1;
            ;;
            --installable)
                local installable_only=1;
            ;;
            --by-name)
                local by_name=1;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done

    local addons_path=${1:-$ADDONS_DIR};

    # Check if addons_path exists
    if [ -z $addons_path ] || [ ! -d $addons_path ]; then
        echoe -e "${REDC}ERROR${NC}: addons directory (${YELLOWC}$addons_path${NC}) not specified or does not exists!";
        return 1
    fi

    # Look for addons
    if [ -d $addons_path ]; then
        if is_odoo_module $addons_path; then
            if [ -z $installable_only ] || addons_is_installable $addons_path; then
                if [ -z $by_name ]; then
                    echo "$(readlink -f $addons_path)";
                else
                    echo "$(basename $(readlink -f $addons_path))";
                fi
            fi
        fi

        for addon in "$addons_path"/*; do
            if is_odoo_module $addon; then
                if [ -z $installable_only ] || addons_is_installable $addon; then
                    if [ -z $by_name ]; then
                        echo "$(readlink -f $addon)";
                    else
                        echo "$(basename $(readlink -f $addon))";
                    fi
                fi
            elif [ ! -z $recursive ] && [ -d "$addon" ]; then
                addons_list_in_directory "$addon";
            fi
        done | sort
    fi
}


# List addons in specified directory by name
# This function prints only name of addons found in specified dir.
# Not paths!
#
# addons_list_in_directory_by_name <directory to search odoo addons in>
function addons_list_in_directory_by_name {
    echoe -e "${YELLOWC}WARNING${NC}: 'addons_list_in_directory_by_name' is deprecated, use 'addons_list_in_directory --by-name' instead";

    # If help in options, do not process result of addons_list_in_directory
    for opt in $@; do
        case $opt in
            -h|--help|help)
                addons_list_in_directory $@
                return 0;
            ;;
        esac
    done

    # Process list of addons, displaying their names
    addons_list_in_directory --by-name $@;
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
      echo "--repo $(git_get_remote_url $repo) --branch $(git_get_branch_name $repo)";
    done
}


# Check for git updates for addons
# addons_git_fetch_updates [addons path]
function addons_git_fetch_updates {
    local addons_dir=${1:-$ADDONS_DIR};
    # fetch updates for each addon repo
    for addon_repo in $(addons_list_repositories $addons_dir); do
        if ! (cd $addon_repo && git fetch); then
            echo -e "${REDC} fetch updates error: $addon_repo${NC}";
        fi
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
                return 0;
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
                return 1;
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


# addons_install_update_internal <cmd> <db> <todo_addons>
# Options:
#   cmd          - one of 'install', 'update', 'uninstall'
#   db           - name of database
#   todo_addons  - coma-separated list of addons
function addons_install_update_internal {
    local cmd="$1"; shift;
    local db="$1"; shift;
    local todo_addons="$1"; shift;

    if [ "$cmd" == "install" ]; then
        server_run -d $db -i $todo_addons --stop-after-init --no-xmlrpc;
        return $?
    elif [ "$cmd" == "update" ]; then
        server_run -d $db -u $todo_addons --stop-after-init --no-xmlrpc;
        return $?
    elif [ "$cmd" == "uninstall" ]; then
        local addons_domain="[('name', 'in', '$todo_addons'.split(',')),('state', 'in', ('installed', 'to upgrade', 'to remove'))]";
        local python_cmd="import lodoo; cl=lodoo.LocalClient(['-c', '$ODOO_CONF_FILE']);";
        python_cmd="$python_cmd db=cl['$db']; db.require_v8_api();";
        python_cmd="$python_cmd modules=db['ir.module.module'].search($addons_domain);";
        python_cmd="$python_cmd modules.button_immediate_uninstall();";
        python_cmd="$python_cmd print(', '.join(modules.mapped('name')));";
        local addons_uninstalled=$(run_python_cmd "$python_cmd");
        if [ -z "$addons_uninstalled" ]; then
            echoe -e "${YELLOWC}WARNING${NC}: Nothing to uninstall";
        else
            echoe -e "${GREENC}OK${NC}: Following addons successfully uninstalled:\n${addons_uninstalled};";
        fi
        return 0;
    else
        echoe -e "${REDC}ERROR: Wrong command '$cmd'${NC}";
        return 1;
    fi
}

# Install or update addons
# addons_install_update <install|update>
function addons_install_update {
    local cmd="$1";
    shift;
    local usage="Usage:

        $SCRIPT_NAME addons $cmd [-d <db>] [--no-restart] <addons>    - $cmd some addons
        $SCRIPT_NAME addons $cmd --help

        if -d <db> argument is not passed '$cmd' will be executed on all databases
        <addons> is comma-separated or space-separated list of addons

        if --no-restart option passed, then do not restart server.
        By default, befor updating \ installing addons server will be stopped,
        and started on success

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
            --no-restart)
                local no_restart_server=1;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                todo_addons="$todo_addons,$1";
            ;;
        esac
        shift
    done

    todo_addons="${todo_addons#,}";  # remove first comma

    if [ -z $todo_addons ]; then
        echoe -e "${REDC}ERROR${NC}:No addons specified! Exiting";
        return 1;
    fi

    # If no database specified, install/update addons
    # to all available databases
    if [ -z $dbs ]; then
        # TODO: search for databases where these addons installed
        dbs=$(odoo_db_list);
    fi

    # Stop server if it is running
    if [ -z $no_restart_server ] && [ $(server_get_pid) -gt 0 ]; then
        server_stop;
        local need_start=1;
    fi

    for db in $dbs; do
        if addons_install_update_internal $cmd $db $todo_addons; then
            echoe -e "${LBLUEC}${cmd} for ${YELLOWC}$db${LBLUEC}:${NC} ${GREENC}OK${NC}";
        else
            echoe -e "${LBLUEC}${cmd} for ${YELLOWC}$db${LBLUEC}:${NC} ${REDC}FAIL${NC}";
            return 1;
        fi
    done

    # Start server again if it was stopped
    if [ -z $no_restart_server ] && [ ! -z $need_start ]; then
        server_start;
    fi
}


# This function test what databases have this addon installed
# addons_test_installed <addon>
function addons_test_installed {
    local addons=$(join_by , $@);
    for db in $(odoo_db_list); do
        local python_cmd="import lodoo; cl=lodoo.Client(['-c', '$ODOO_CONF_FILE']);";
        python_cmd="$python_cmd Module=cl['$db'].env['ir.module.module'];";
        python_cmd="$python_cmd is_installed=bool(Module.search([('name', 'in', '$addons'.split(',')),('state', '=', 'installed')], count=1));"
        # returns 0 (OK) if addon is installed in database
        # returns 1 (False) if addon is not installed in database
        python_cmd="$python_cmd exit(not is_installed);"

        if run_python_cmd "$python_cmd" >/dev/null 2>&1; then
            echo "$db";
        fi
    done
}


# This functions walk through addons found in custom_addons dir, and searches
# for requirements.txt file there. if such file is present,
# install depenencies listed there
# Also it checks for repository-level requirements.txt
#
# just call as: addons_update_py_deps
function addons_update_py_deps {
    for repo in $(addons_list_repositories); do
        if git_is_git_repo $repo && [ -f $repo/requirements.txt ]; then
            echoe -e "${BLUEC}Installing dependencies for ${YELLOWC}$(git_get_abs_repo_path $repo)${BLUEC} repository...${NC}";
            exec_pip install -r $repo/requirements.txt;
        fi
    done

    for addon in $(addons_list_in_directory); do
        if [ -f "$addon/requirements.txt" ]; then
            echoe -e "${BLUEC}Installing dependencies for ${YELLOWC}$(basename $addon)${BLUEC}... ${NC}";
            exec_pip install -r $addon/requirements.txt;
        fi
    done
}



function addons_command {
    local usage="Usage:

        $SCRIPT_NAME addons list <addons path>            - list addons in specified directory
        $SCRIPT_NAME addons list-repos [addons path]      - list git repositories
        $SCRIPT_NAME addons list-no-repo [addons path]    - list addons not under git repo
        $SCRIPT_NAME addons check-updates [addons path]   - Check for git updates of addons and displays status
        $SCRIPT_NAME addons pull-updates [addons path]    - Pull changes from git repos
        $SCRIPT_NAME addons status --help                 - show addons status
        $SCRIPT_NAME addons update --help                 - update some addon[s]
        $SCRIPT_NAME addons install --help                - install some addon[s]
        $SCRIPT_NAME addons uninstall --help              - uninstall some addon[s]
        $SCRIPT_NAME addons update-list [db]              - update list of addons
        $SCRIPT_NAME addons test-installed <addon>        - lists databases this addon is installed in
        $SCRIPT_NAME addons update-py-deps                - update python dependencies of addons
        $SCRIPT_NAME addons generate-requirements         - generate odoo_requirements.txt for this instance
        $SCRIPT_NAME addons --help                        - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            list)
                shift;
                addons_list_in_directory $@;
                return 0;
            ;;
            list-repos|list_repos)
                shift;
                addons_list_repositories "$@";
                return 0;
            ;;
            list-no-repo|list_no_repo)
                shift;
                addons_list_no_repository "$@";
                return 0;
            ;;
            check-updates|check_updates)
                shift;
                ADDONS_DIR=${1:-$ADDONS_DIR};
                addons_git_fetch_updates;
                addons_show_status --only-git-updates;
                return 0;
            ;;
            pull-updates|pull_updates)
                shift;
                echo -e "${BLUEC}Checking for updates...${NC}";
                addons_git_fetch_updates "$@";
                echo -e "${BLUEC}Applying updates...${NC}";
                addons_git_pull_updates "$@";
                echo -e "${GREENC}DONE${NC}";
                return 0;
            ;;
            status|show_status)
                shift;
                addons_show_status "$@";
                return 0;
            ;;
            update)
                shift;
                addons_install_update "update" "$@";
                return 0;
            ;;
            install)
                shift;
                addons_install_update "install" "$@";
                return 0;
            ;;
            uninstall)
                shift;
                addons_install_update "uninstall" "$@";
                return 0;
            ;;
            update-list)
                shift;
                addons_update_module_list "$@";
                return 0;
            ;;
            test-installed)
                shift;
                addons_test_installed $@;
                return 0;
            ;;
            update-py-deps)
                shift;
                addons_update_py_deps;
                return;
            ;;
            generate-requirements)
                shift;
                addons_generate_requirements "$@";
                return 0;
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
