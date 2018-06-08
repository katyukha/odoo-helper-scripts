if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# git_is_git_repo <repo_path>
function git_is_git_repo {
    if [ -d ${1}/.git ] || (cd ${1} && git rev-parse --git-dir > /dev/null 2>&1); then
        return 0;   # it is git repository
    else
        return 1;   # It is not git repository
    fi
}

# git_get_abs_repo_path <path>
function git_get_abs_repo_path {
    echo "$(cd $1 && git rev-parse --show-toplevel)";
}

# git_get_current_commit <path>
function git_get_current_commit {
    (cd $1 && git rev-parse --verify --short HEAD);
}

# git_get_branch_name [repo_path]
function git_get_branch_name {
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

# git_get_remote_url [repo_path]
function git_get_remote_url {
    local cdir=`pwd`;
    if [ ! -z "$1" ]; then
        cd $1;
    fi

    local current_branch=`git_get_branch_name`;
    local git_remote=`git config --local --get branch.$current_branch.remote`;
    echo "`git config --local --get remote.$git_remote.url`";

    if [ ! -z "$1" ]; then
        cd $cdir;
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
    while IFS='' read -r line; do
      if [ -z $line ]; then
          continue;
      fi

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

    if [[ -z "$branch" ]]; then
        branch=$(git_get_branch_name)
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


# git_is_clean <repo path>
# Check if repository is clean (no uncommited changes)
function git_is_clean {
    local git_status=;
    IFS=$'\n' git_status=( $(git_parse_status $1 || echo '') );
    if (( ${git_status[4]} == 0 && ${git_status[5]} == 0 && ${git_status[6]} == 0 && ${git_status[7]} == 0 )) ; then
        return 0;  # repo is clean
    else
        return 1;  # repo is dirty
    fi
}
