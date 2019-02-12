# Copyright © 2015-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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

    local addon_path;
    addon_path=$(search_file_in $addon ${addon_dirs[@]});
    addon_path=$(readlink -f "$addon_path");
    echo "$addon_path";
}

# Echo name of addon specified by path
# addons_get_addon_name <addon path>
function addons_get_addon_name {
    local addon=$1;
    if [ -d "$addon" ] && is_odoo_module $addon; then
        local addon_path="$(readlink -f $addon)";
        echo "$(basename $addon_path)";
    else
        # If addon does not points to a directory, then we think that it is
        # name of addon
        echo "$addon";
    fi
}


# Check if specified addons name or path is odoo addon
# addons_is_odoo_addon <addon name or path>
function addons_is_odoo_addon {
    local addon=$1;

    if [ -z "$addon" ]; then
        return 1;
    elif [ -d "$addon" ] && is_odoo_module $addon; then
        local addon_path="$(readlink -f $addon)";
    else
        local addon_path="$(addons_get_addon_path $addon)";
    fi

    if [ -z "$addon_path" ]; then
        return 2;
    elif ! is_odoo_module "$addon_path"; then
        return 3;
    fi
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
    local addon_path="$1";
    local manifest_file=$(addons_get_manifest_file "$addon_path");

    echo $(run_python_cmd "print(' '.join(eval(open('$manifest_file', 'rt').read()).get('depends', [])))");
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

    if run_python_cmd "$python_cmd"; then
        echoe -e "${GREENC}OK${NC}: Addons list successfully updated for ${YELLOWC}${db}${NC} database";
    else
        echoe -e "${REDC}ERROR${NC}: Cannot update module list for ${YELLOWC}${db}${NC} database";
    fi
}


# Update list of addons visible in system for db or all databases
# addons_update_module_list [options] [db] 
function addons_update_module_list {
    local usage="
    Usage:
        $SCRIPT_NAME addons update-list [options] [db]    - update module list
        $SCRIPT_NAME addons update-list --help

    Description:
        Update list of addons (apps)  in specified databases.
        If no databases specified, then all databases will be updated.

    Options:
        --cdb|--conf-db        - use default database from config file
        --tdb|--test-db        - use database used for tests
        -h|--help|help         - show this help message
    ";
    local dbs="";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --cdb|--conf-db)
                dbs="$dbs $(odoo_get_conf_val db_name)";
            ;;
            --tdb|--test-db)
                dbs="$dbs $(odoo_get_conf_val db_name $ODOO_TEST_CONF_FILE)";
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown option ${YELLOWC}${1}${NC}!"
                return 1;
            ;;
            *)
                if odoo_db_exists -q "$1"; then
                    dbs="$dbs $1";
                else
                    echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${1}${NC} is not database name or such database is not available for this Odoo instance!";
                    return 1;
                fi
            ;;
        esac
        shift
    done

    if [ -z "$dbs" ]; then
        dbs="$(odoo_db_list)";
    fi

    dbs=($dbs);

    for db in ${dbs[@]}; do
        echo -e "${BLUEC}Updating module list for ${YELLOWC}$db${NC}";
        addons_update_module_list_db "$db";
    done
}

# _addons_list_in_directory_display <addon_path> <name_mode> <color model>
function _addons_list_in_directory_display {
    local addon_path=$(readlink -f $1); shift;
    local name_mode=$1; shift;
    local color_mode=$1; shift;


    if [ "$name_mode" == 'path' ]; then
        local result="$addon_path";
    elif [ "$name_mode" == 'name' ]; then
        local result="$(basename $addon_path)";
    else
        return 1;
    fi

    if [ "$color_mode" == 'link' ]; then
        if link_is_addon_linked $addon_path; then
            result="${GREENC}${result}${NC}";
        else
            local link_result="$?";
            if [ $link_result -eq 1 ]; then
                result="${REDC}${result}${NC}";
            elif [ $link_result -eq 2 ]; then
                result="${YELLOWC}${result}${NC}";
            fi
        fi
    fi


    echo -e "$result";
}

# _addons_list_in_directory_filter <addon_path> <installable 1|0> <not-linked 1|0> <linked 1|0> <filter_expr>
# filer_expr is string that contains regular expression to filter addons with
function _addons_list_in_directory_filter {
    local addon_path=$1;
    local installable=$2;
    local not_linked=$3;
    local linked=$4;
    local filter_expr=$5;

    local addon_name=$(addons_get_addon_name "$addon_path");

    if [ -n "$filter_expr" ] && ! [[ "$addon_name" =~ $filter_expr ]]; then
        return 1;
    fi

    if [ $installable -eq 1 ] && ! addons_is_installable $addon_path; then
        return 1;
    fi
    if [ $not_linked -eq 1 ] && link_is_addon_linked $addon_path; then
        return 1;
    fi
    if [ $linked -eq 1 ] && ! link_is_addon_linked $addon_path; then
        return 1;
    fi
    return 0;
}


# List addons in specified directory
#
# addons_list_in_directory [options] <directory to search odoo addons in> [dir2 [dirn]]
#
# Note: this funtion lists addon paths
function addons_list_in_directory {
    # Process all args that starts with '-' (ie. options)
    local usage="
    Usage:

        $SCRIPT_NAME addons list [options] [path [path2 [pathn]]]
        $SCRIPT_NAME addons list --help

    Options:

        -r|--recursive    - look for addons recursively
        --installable     - display only installable addons
        --linked          - display only linked addons
        --not-linked      - display addons that are not present in custom_addons dir
        --by-name         - display only addon names
        --by-path         - display addon path
        --filter <expr>   - filter addons by expression.
                            expression is a string that is bash regular expression
                            (this option is experimental and its bechavior may be changed)
        --color           - color result by link-status
        -h|--help         - display this help message

    Note:

        --by-name and --by-path options are conflicting,
        thus last option in command call will take effect.
    ";

    local name_mode='path';
    local color_mode='off';
    local installable_only=0;
    local not_linked_only=0;
    local linked_only=0;
    local recursive_options=;
    local filter_expr="";

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
                recursive_options="$recursive_options --recursive";
            ;;
            --installable)
                installable_only=1;
                recursive_options="$recursive_options --installable";
            ;;
            --linked)
                linked_only=1;
                recursive_options="$recursive_options --linked";
            ;;
            --not-linked)
                not_linked_only=1;
                recursive_options="$recursive_options --not-linked";
            ;;
            --by-name)
                name_mode='name';
                recursive_options="$recursive_options --by-name";
            ;;
            --by-path)
                name_mode='path';
                recursive_options="$recursive_options --by-path";
            ;;
            --color)
                color_mode='link';
                recursive_options="$recursive_options --color";
            ;;
            --filter)
                filter_expr="$2";
                recursive_options="$recursive_options --filter $2";
                shift;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done

    if [ -z "$1" ]; then
        addons_list_in_directory $recursive_options $(pwd);
        return;
    fi

    for addons_path in $@; do
        # Look for addons
        if [ -d $addons_path ]; then
            if is_odoo_module $addons_path; then
                if _addons_list_in_directory_filter "$addons_path" "$installable_only" "$not_linked_only" "$linked_only" "$filter_expr"; then
                    _addons_list_in_directory_display "$addons_path" $name_mode $color_mode;
                fi
            fi

            for addon in "$addons_path"/*; do
                if is_odoo_module $addon; then
                    if _addons_list_in_directory_filter "$addon" "$installable_only" "$not_linked_only" "$linked_only" "$filter_expr"; then
                        _addons_list_in_directory_display "$addon" $name_mode $color_mode;
                    fi
                elif [ -n "$recursive" ] && [ -d "$addon" ] && [ "$(basename $addon)" != "setup" ]; then
                    addons_list_in_directory $recursive_options "$addon";
                fi
            done
        fi
    done | sort -u
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
    local usage="
    Usage

        $SCRIPT_NAME addons generate-requirements [addons dir]

    Description

        parse *addons dir*, find all addons that are
        git repositories and print *odoo-requirements.txt* content
        if *addons dir* is not set, then all addons available
        for this instance will be parsed.
        file content suitable for *fetch* subcommand.
        for example:
            $SCRIPT_NAME addons generate-requirements > odoo_requirements.txt
        and you can use generated file for fetch subcommand:
            $SCRIPT_NAME fetch --requirements odoo_requirements.txt
    ";
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echoe -e "${REDC}ERROR${NC}: Unknown option ${YELLOWC}${key}${NC}";
                return 1;
            ;;
        esac
        shift
    done

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
# addons_git_pull_updates
function addons_git_pull_updates {
    local addons_dir=${ADDONS_DIR};
    local usage="
    Usage

        $SCRIPT_NAME addons pull-updates [options]

    Options:
        --addons-dir          - directory to search addons in. By default used one from
                                project config
        --ual                 - update list of addons in all databases
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
            --ual)
                local opt_ual=1;
            ;;
            *)
                echoe "Unknown option: $key";
                return 1;
            ;;
        esac;
        shift;
    done;

    echo -e "${BLUEC}Checking for updates...${NC}";
    addons_git_fetch_updates "$addons_dir";
    echo -e "${BLUEC}Applying updates...${NC}";

    for addon_repo in $(addons_list_repositories $addons_dir); do
        IFS=$'\n' git_status=( $(git_parse_status $addon_repo || echo '') );
        local git_remote_status=${git_status[1]};
        if [[ $git_remote_status == _BEHIND_* ]] && [[ $git_remote_status != *_AHEAD_* ]]; then
            # link module (not forced)
            (cd $addon_repo && \
                echoe -e "${BLUEC}Pulling updates for ${YELLOWC}${addon_repo}${BLUEC}...${NC}" && \
                git pull && \
                echoe -e "${BLUEC}Linking repository ${YELLOWC}${addon_repo}${BLUEC}...${NC}" && \
                link_module off . && \
                echoe -e "${BLUEC}Pull ${YELLOWC}${addon_repo}${BLUEC}: ${GREENC}OK${NC}");
        fi
    done

    # update list available modules for all databases
    if [ -n "$opt_ual" ]; then
        addons_update_module_list;
    fi
    echo -e "${GREENC}DONE${NC}";
}


# Show git status for each addon
# show_addons_status
function addons_show_status {
    local addons_dir=$ADDONS_DIR;
    local cdir=$(pwd);

    local usage="
    Usage

        $SCRIPT_NAME addons status [options]

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
                echoe "Unknown option: $key";
                return 1;
            ;;
        esac;
        shift;
    done;

    local git_status=;
    for addon_repo in $(addons_list_repositories $addons_dir); do
        IFS=$'\n' git_status=( $(git_parse_status $addon_repo || echo '') );
        if [ -z $git_status ]; then
            echoe -e "No info available for addon $addon_repo";
            continue;
        fi

        # if '--only-unclean' specified, skip addons that are clean
        if [ -n "$only_unclean" ] && [ ${git_status[3]} -eq 1 ]; then
            continue
        fi

        # if '--only-git-updates' specified, skip addons which is up to date
        if [ -n "$only_git_updates" ] && [ ${git_status[1]} == "." ]; then
            continue
        fi

        # Display addon status
        echoe -e "Addon status for ${BLUEC}$addon_repo${NC}'";
        echoe -e "\tRepo branch:          ${git_status[0]}";
        echoe -e "\tRepo remote:          $(git_get_remote_url $addon_repo)";
        [ ${git_status[1]} != "." ] && echoe -e "\t${YELLOWC}Remote: ${git_status[1]}${NC}";
        [ ${git_status[1]} != "." ] && echoe -e "\t${YELLOWC}Upstream: ${git_status[2]}${NC}";
        [ ${git_status[3]} -eq 1 ]  && echoe -e "\t${GREENC}Repo is clean!${NC}";
        [ ${git_status[4]} -gt 0 ]  && echoe -e "\t${YELLOWC}${git_status[4]} files staged for commit${NC}";
        [ ${git_status[5]} -gt 0 ]  && echoe -e "\t${YELLOWC}${git_status[5]} files changed${NC}";
        [ ${git_status[6]} -gt 0 ]  && echoe -e "\t${REDC}${git_status[6]} conflicts${NC}";
        [ ${git_status[7]} -gt 0 ]  && echoe -e "\t${YELLOWC}${git_status[7]} untracked files${NC}";
        [ ${git_status[8]} -gt 0 ]  && echoe -e "\t${YELLOWC}${git_status[8]} stashed${NC}";

    done;

    if [ -z $ignore_no_git_repo ]; then
        for addon_path in $(addons_list_no_repository $addons_dir); do
            echoe -e "Addon status for ${BLUEC}$addon_path${NC}'";
            echoe -e "\t${REDC}Warning: not under git controll${NC}";
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
        server_run -- -d $db -i $todo_addons --stop-after-init --no-xmlrpc;
        return $?
    elif [ "$cmd" == "update" ]; then
        server_run -- -d $db -u $todo_addons --stop-after-init --no-xmlrpc;
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
            echoe -e "${GREENC}OK${NC}: Following addons successfully uninstalled:\n${addons_uninstalled};\n";
        fi
        return 0;
    else
        echoe -e "${REDC}ERROR: Wrong command '$cmd'${NC}";
        return 1;
    fi
}

# Install or update addons
# addons_install_update <install|update|uninstall>
function addons_install_update {
    local cmd="$1";
    shift;
    local usage="Usage:

        $SCRIPT_NAME addons $cmd [options] <addons>    - $cmd some addons
        $SCRIPT_NAME addons $cmd [options] all         - $cmd all addons
        $SCRIPT_NAME addons $cmd --help

    Options

        -d|--db <database>     - database to $cmd addons on.
                                 may be specified multiple times.
                                 If not specified, then command applied to
                                 all databases available for
                                 this odoo instance
        --cdb|--conf-db        - default database from config file
        --tdb|--test-db        - database used for tests
        --no-restart           - do not restart server during addons update
                                 By default server will be stopped before
                                 command and restarted after command finishes.
                                 If command return non-zero exit code, then
                                 server will not be restarted.
        --start                - Start odoo server on $cmd success.
        --log                  - Open log after $cmd
        --dir <addon path>     - directory to $cmd addons from.
                                 Searches for all installable addons
                                 in specified directory.
                                 May be specified multiple times
        --dir-r <addon path>   - Same as --dir, but searches for addons recursively.
                                 May be specified multiple times
        -m|--module <addon>    - $cmd addon name. This option is added
                                 to be consistend with *odoo-helper test* command.
                                 Could be specified multiple times
        --ual                  - update apps list first.
                                 Sync new addons available for Odoo to database.
                                 This is usualy required on install of addon
                                 that was just fetched from repository,
                                 and is not yet present in Odoo database
    ";
    local need_start=;
    local update_addons_list=0;
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
            --cdb|--conf-db)
                dbs=$(odoo_get_conf_val db_name);
            ;;
            --tdb|--test-db)
                dbs=$(odoo_get_conf_val db_name $ODOO_TEST_CONF_FILE);
            ;;
            --dir)
                todo_addons="$todo_addons,$(join_by , $(addons_list_in_directory --installable --by-name $2))";
                shift;
            ;;
            --dir-r)
                todo_addons="$todo_addons,$(join_by , $(addons_list_in_directory --recursive --installable --by-name $2))";
                shift;
            ;;
            --no-restart)
                local no_restart_server=1;
            ;;
            --start)
                need_start=1;
            ;;
            --log)
                local open_logs=1;
            ;;
            -m|--module)
                # To be consistent with *odoo-helper test* command
                if ! addons_is_odoo_addon "$2"; then
                    echoe -e "${REDC}ERROR${NC}: Cannot $cmd ${YELLOWC}${2}${NC} is not Odoo addon!";
                    return 1;
                else
                    todo_addons="$todo_addons,$(addons_get_addon_name $2)";
                fi
                shift;
            ;;
            --ual)
                local update_addons_list=1;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -*)
                echoe -e "${REDC}ERROR${NC}: Unknown option ${YELLOWC}${1}${NC}!"
                return 1;
            ;;
            all)
                if [ "$cmd" == "uninstall" ]; then
                    echoe -e "${REDC}ERROR${NC}: Cannot uninstall all addons!";
                    return 1;
                else
                    todo_addons="all";
                fi
            ;;
            *)
                if [ "$cmd" != "uninstall" ] && ! addons_is_odoo_addon "$1"; then
                    echoe -e "${REDC}ERROR${NC}: Cannot ${cmd} ${YELLOWC}${1}${NC} - it is not Odoo addon!";
                    return 1;
                else
                    todo_addons="$todo_addons,$(addons_get_addon_name $1)";
                fi
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

    if [ "$update_addons_list" -eq 1 ]; then
        addons_update_module_list $dbs;
    fi

    for db in $dbs; do
        if addons_install_update_internal $cmd $db $todo_addons; then
            echoe -e "${LBLUEC}${cmd} for ${YELLOWC}$db${LBLUEC}:${NC} ${GREENC}OK${NC}";
        else
            echoe -e "${LBLUEC}${cmd} for ${YELLOWC}$db${LBLUEC}:${NC} ${REDC}FAIL${NC}";
            if [ -n "$open_logs" ]; then
                server_log;
            fi
            return 1;
        fi
    done

    # Start server again if it was stopped
    if [ -n "$need_start" ] && ! server_is_running; then
        server_start;
    fi
    if [ -n "$open_logs" ]; then
        server_log;
    fi
}


# This function test what databases have this addon installed
# addons_test_installed <addon>
function addons_test_installed {
    local usage="
    Usage

        $SCRIPT_NAME addons test-installed <addon>

    Description

        test if addon is installed in at least one database
        and print names of databases where this addon is installed

    Options

        -h|--help|help  - show this help message

    ";
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echoe -e "${REDC}ERROR${NC}: Unknown option ${YELLOWC}${key}${NC}";
                return 1;
            ;;
        esac
        shift
    done
    local addon_name="$1";

    available_databases=( $(odoo_db_list) );
    for db in "${available_databases[@]}"; do
        local addon_count;
        addon_count=$(postgres_psql -d "$db" -tA -c "SELECT count(*) FROM ir_module_module WHERE state = 'installed' AND name = '$addon_name';");
        if [ "$addon_count" -eq 1 ]; then
            echo "$db";
        fi
    done | sort;
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

    for addon in $(addons_list_in_directory $ADDONS_DIR); do
        if [ -f "$addon/requirements.txt" ]; then
            echoe -e "${BLUEC}Installing dependencies for ${YELLOWC}$(basename $addon)${BLUEC}... ${NC}";
            exec_pip install -r $addon/requirements.txt;
        fi
    done
}


function addons_find_installed {
    local usage="
    Usage

        $SCRIPT_NAME addons find-installed

    Description

        Find all addons that installed in at least one database

    Options

        -h|--help|help  - show this help message

    ";
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echoe -e "${REDC}ERROR${NC}: Unknown option ${YELLOWC}${key}${NC}";
                return 1;
            ;;
        esac
        shift
    done
    local addons_list;
    local addons_list_pg_str;
    addons_list=( $(addons_list_in_directory --by-name "$ADDONS_DIR") );
    for addon_name in "${addons_list[@]}"; do
        addons_list_pg_str="$addons_list_pg_str, '$addon_name'";
    done
    addons_list_pg_str="${addons_list_pg_str#, }";

    declare -A installed_addons_map;
    local available_databases;
    available_databases=( $(odoo_db_list) );
    for db in "${available_databases[@]}"; do
        local db_installed_addons;
        db_installed_addons=$(postgres_psql -d "$db" -tA -c "SELECT name FROM ir_module_module WHERE state = 'installed' AND name IN (${addons_list_pg_str})");
        db_installed_addons=( $db_installed_addons );
        for installed_addon in "${db_installed_addons[@]}"; do
            installed_addons_map["$installed_addon"]=1;
        done
    done

    for addon in "${!installed_addons_map[@]}"; do
        echo "$addon";
    done | sort;
}


function addons_command {
    local usage="
    Usage:

        $SCRIPT_NAME addons list --help                 - list addons in specified directory
        $SCRIPT_NAME addons list-repos [addons path]    - list git repositories
        $SCRIPT_NAME addons list-no-repo [addons path]  - list addons not under git repo
        $SCRIPT_NAME addons check-updates [addons path] - Check for git updates of addons and displays status
        $SCRIPT_NAME addons pull-updates --help         - Pull changes from git repos
        $SCRIPT_NAME addons status --help               - show addons status
        $SCRIPT_NAME addons update --help               - update some addon[s]
        $SCRIPT_NAME addons install --help              - install some addon[s]
        $SCRIPT_NAME addons uninstall --help            - uninstall some addon[s]
        $SCRIPT_NAME addons update-list --help          - update list of addons
        $SCRIPT_NAME addons test-installed --help       - lists databases this addon is installed in
        $SCRIPT_NAME addons find-installed              - print list of addons installed in at least one db
        $SCRIPT_NAME addons update-py-deps              - update python dependencies of addons
        $SCRIPT_NAME addons generate-requirements       - generate odoo_requirements.txt for this instance
        $SCRIPT_NAME addons --help                      - show this help message

    Shortcuts:

        $SCRIPT_NAME addons ls  -> $SCRIPT_NAME addons list

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            list|ls)
                shift;
                addons_list_in_directory --by-name $@;
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
                addons_git_pull_updates "$@";
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
                addons_test_installed "$@";
                return 0;
            ;;
            find-installed)
                shift;
                addons_find_installed $@;
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
