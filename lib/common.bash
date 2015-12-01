# Odoo-helper mark that common module is imported
ODOO_HELPER_COMMON_IMPORTED=1;

declare -A ODOO_HELPER_IMPORTED_MODULES;
ODOO_HELPER_IMPORTED_MODULES[common]=1

# Define version number
ODOO_HELPER_VERSION="0.0.2"

# predefined filenames
CONF_FILE_NAME="odoo-helper.conf";

# Color related definitions
function allow_colors {
    NC='\e[0m';
    REDC='\e[31m';
    GREENC='\e[32m';
    YELLOWC='\e[33m';
    BLUEC='\e[34m';
    LBLUEC='\e[94m';
}

# could be used to hide colors in output
function deny_colors {
    NC='';
    REDC='';
    GREENC='';
    YELLOWC='';
    BLUEC='';
    LBLUEC='';
}

# Allow colors by default
allow_colors;
# -------------------------

# Simplify import controll
# oh_require <module_name>
function ohelper_require {
    local mod_name=$1;
    if [ -z ${ODOO_HELPER_IMPORTED_MODULES[$mod_name]} ]; then
        source $ODOO_HELPER_LIB/$mod_name.bash;
        ODOO_HELPER_IMPORTED_MODULES[$mod_name]=1;
    fi
}


# simply pass all args to exec or unbuffer
# depending on 'USE_UNBUFFER variable
# Also take in account virtualenv
function execu {
    if [ ! -z $VENV_DIR ]; then
        source $VENV_DIR/bin/activate;
    fi

    # Check unbuffer option
    if [ ! -z $USE_UNBUFFER ] && ! command -v unbuffer >/dev/null 2>&1; then
        echo -e "${REDC}Command 'unbuffer' not found. Install it to use --use-unbuffer option";
        echo -e "It could be installed by installing package expect-dev";
        echo -e "Using standard behavior${NC}";
        USE_UNBUFFER=;
    fi

    if [ -z $USE_UNBUFFER ]; then
        eval "$@";
        local res=$?;
    else
        eval unbuffer "$@";
        local res=$?;
    fi

    if [ ! -z $VENV_DIR ]; then
        deactivate;
    fi
    return $res
}


# Simple function to create directories passed as arguments
# create_dirs [dir1] [dir2] ... [dir_n]
function create_dirs {
    for dir in $@; do
        if [ ! -d $dir ]; then
            mkdir -p "$dir";
        fi
    done;
}


# Simple function to check if at least one command exists.
# Returns first existing command
function check_command {
    for test_cmd in $@; do
        if execu command -v "$test_cmd" >/dev/null 2>&1; then
            echo "$test_cmd";
            return 0;
        fi;
    done
    return -1;
}


# echov $@
# echo if verbose is on
function echov {
    if [ ! -z "$VERBOSE" ]; then
        echo "$@";
    fi
}

# random_string [length]
# default length = 8
function random_string {
    < /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-8};
}

# search_file_up <start path> <file name>
function search_file_up {
    local path=$1;
    while [[ "$path" != "/" ]];
    do
        if [ -e "$path/$2" ]; then
            echo "$path/$2";
            return 0;
        fi
        path=`dirname $path`;
    done
}

# get_git_branch_name [repo_path]
function get_git_branch_name {
    local cdir=`pwd`;
    if [ ! -z "$1" ]; then
        cd $1;
    fi

    local branch_name=$(git symbolic-ref -q HEAD);
    branch_name=${branch_name##refs/heads/};
    branch_name=${branch_name:-HEAD};
    
    echo "$branch_name"

    if [ ! -z "$1" ]; then
        cd $cdir;
    fi
}

# get_git_remote_url [repo_path]
function get_git_remote_url {
    local cdir=`pwd`;
    if [ ! -z "$1" ]; then
        cd $1;
    fi

    local current_branch=`get_git_branch_name`;
    local git_remote=`git config --local --get branch.$current_branch.remote`;
    echo "`git config --local --get remote.$git_remote.url`";

    if [ ! -z "$1" ]; then
        cd $cdir;
    fi
}


# function to print odoo-helper config
function print_helper_config {
    echo "ODOO_BRANCH=$ODOO_BRANCH;";
    echo "PROJECT_ROOT_DIR=$PROJECT_ROOT_DIR;";
    echo "CONF_DIR=$CONF_DIR;";
    echo "LOG_DIR=$LOG_DIR;";
    echo "LOG_FILE=$LOG_FILE;";
    echo "LIBS_DIR=$LIBS_DIR;";
    echo "DOWNLOADS_DIR=$DOWNLOADS_DIR;";
    echo "ADDONS_DIR=$ADDONS_DIR;";
    echo "DATA_DIR=$DATA_DIR;";
    echo "BIN_DIR=$BIN_DIR;";
    echo "VENV_DIR=$VENV_DIR;";
    echo "ODOO_PATH=$ODOO_PATH;";
    echo "ODOO_CONF_FILE=$ODOO_CONF_FILE;";
    echo "ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;";
    echo "ODOO_PID_FILE=$ODOO_PID_FILE;";
    echo "BACKUP_DIR=$BACKUP_DIR;";
}


# Function to configure default variables
function config_default_vars {
    if [ -z $PROJECT_ROOT_DIR ]; then
        echo -e "${REDC}There is no PROJECT_ROOT_DIR set!${NC}";
        return 1;
    fi
    CONF_DIR=${CONF_DIR:-$PROJECT_ROOT_DIR/conf};
    ODOO_CONF_FILE=${ODOO_CONF_FILE:-$CONF_DIR/odoo.conf};
    ODOO_TEST_CONF_FILE=${ODOO_TEST_CONF_FILE:-$CONF_DIR/odoo.test.conf};
    LOG_DIR=${LOG_DIR:-$PROJECT_ROOT_DIR/logs};
    LOG_FILE=${LOG_FILE:-$LOG_DIR/odoo.log};
    LIBS_DIR=${LIBS_DIR:-$PROJECT_ROOT_DIR/libs};
    DOWNLOADS_DIR=${DOWNLOADS_DIR:-$PROJECT_ROOT_DIR/downloads};
    ADDONS_DIR=${ADDONS_DIR:-$PROJECT_ROOT_DIR/custom_addons};
    DATA_DIR=${DATA_DIR:-$PROJECT_ROOT_DIR/data_dir};
    BIN_DIR=${BIN_DIR:-$PROJECT_ROOT_DIR/bin};
    VENV_DIR=${VENV_DIR:-$PROJECT_ROOT_DIR/venv};
    ODOO_PID_FILE=${ODOO_PID_FILE:-$PROJECT_ROOT_DIR/odoo.pid};
    ODOO_PATH=${ODOO_PATH:-$PROJECT_ROOT_DIR/odoo};
    BACKUP_DIR=${BACKUP_DIR:-$PROJECT_ROOT_DIR/backups};
}


# is_odoo_module <module_path>
function is_odoo_module {
    if [ ! -d $1 ]; then
       return 1;
    elif [ -f "$1/__openerp__.py" ] || [ -f "$1/__odoo__.py" ] || [ -f "$1/__terp__.py" ]; then
        return 0;
    else
        return 1;
    fi
}


# Load project configuration. No args prowided
function load_project_conf {
    local project_conf=`search_file_up $WORKDIR $CONF_FILE_NAME`;
    if [ -f "$project_conf" ] && [ ! "$project_conf" == "$HOME/odoo-helper.conf" ]; then
        echov -e "${LBLUEC}Loading conf${NC}: $project_conf";
        source $project_conf;
    fi

    if [ -z $PROJECT_ROOT_DIR ]; then
        echo -e "${REDC}WARNING: no project config file found${NC}";
    fi
}



# Code is based on https://github.com/magicmonty/bash-git-prompt/blob/master/gitstatus.sh
# Parses git status output, and print parsed values line by line, making it availble
# to be used in way like:
#    git_status = $(git_parse_status)
#    echo "Repo branch ${git_status[0]}
#    echo "Repo clean status ${git_status[3]}
# result contains folowing values:
#    0 - branch name
#    1 - remote status
#    2 - upstream info
#    3 - clean status (0 - not clena, 1 - clean)
#    4 - number of staged files
#    5 - number of changed files
#    6 - number of conflicts
#    7 - number of untracked files
#    8 - number of stashes
# git_parse_status <path to repo>
function git_parse_status {
    local path_to_repo=$1;
    local cdir=$(pwd);

    # Go to repository directory
    cd $path_to_repo

    local gitstatus=$( LC_ALL=C git status --untracked-files=all --porcelain --branch )

    # if the status is fatal, exit now
    if [[ "$?" -ne 0 ]]; then
        echo "Cannot get git status for $path_to_repo";
        return 1;
    fi

    local num_staged=0
    local num_changed=0
    local num_conflicts=0
    local num_untracked=0
    while IFS='' read -r line || [[ -n "$line" ]]; do
      local status=${line:0:2}
      case "$status" in
        \#\#)
            local branch_line="${line/\.\.\./^}";
        ;;
        ?M)
            ((num_changed++))
        ;;
        U?)
            ((num_conflicts++))
        ;;
        \?\?)
            ((num_untracked++))
        ;;
        *)
            ((num_staged++))
        ;;
      esac
    done <<< "$gitstatus"

    local num_stashed=0
    local stash_file="$( git rev-parse --git-dir )/logs/refs/stash"
    if [[ -e "${stash_file}" ]]; then
        while IFS='' read -r wcline || [[ -n "$wcline" ]]; do
          ((num_stashed++));
        done < ${stash_file}
    fi

    local clean=0
    if (( num_changed == 0 && num_staged == 0 && num_untracked == 0 && num_stashed == 0 )) ; then
      clean=1
    fi

    # ---
    IFS="^" read -ra branch_fields <<< "${branch_line/\#\# }"
    local branch="${branch_fields[0]}"
    local remote=
    local upstream=

    if [[ "$branch" == *"Initial commit on"* ]]; then
      IFS=" " read -ra fields <<< "$branch"
      branch="${fields[3]}"
      remote="_NO_REMOTE_TRACKING_"
    elif [[ "$branch" == *"no branch"* ]]; then
      local tag=$( git describe --exact-match )
      if [[ -n "$tag" ]]; then
        branch="$tag"
      else
        branch="_PREHASH_$( git rev-parse --short HEAD )"
      fi
    else
      if [[ "${#branch_fields[@]}" -eq 1 ]]; then
        remote="_NO_REMOTE_TRACKING_"
      else
        IFS="[,]" read -ra remote_fields <<< "${branch_fields[1]}"
        upstream="${remote_fields[0]}"
        for remote_field in "${remote_fields[@]}"; do
          if [[ "$remote_field" == *ahead* ]]; then
            num_ahead=${remote_field:6}
            ahead="_AHEAD_${num_ahead}"
          fi
          if [[ "$remote_field" == *behind* ]]; then
            num_behind=${remote_field:7}
            behind="_BEHIND_${num_behind# }"
          fi
        done
        remote="${behind}${ahead}"
      fi
    fi

    if [[ -z "$remote" ]] ; then
      remote='.'
    fi

    if [[ -z "$upstream" ]] ; then
      upstream='^'
    fi

    # ---

    # Print parse result
    echo -e "$branch\n$remote\n$upstream\n$clean\n$num_staged\n$num_changed\n$num_conflicts\n$num_untracked\n$num_stashed\n"

    # Go back to working dir
    cd $cdir;
}
