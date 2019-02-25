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

# Require libs
ohelper_require 'git';
ohelper_require 'recursion';
ohelper_require 'addons';
ohelper_require 'link';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# Define veriables
REQUIREMENTS_FILE_NAME="odoo_requirements.txt";
PIP_REQUIREMENTS_FILE_NAME="requirements.txt";
OCA_REQUIREMENTS_FILE_NAME="oca_dependencies.txt";


# fetch_requirements <file_name|path_name>
function fetch_requirements {
    local REQUIREMENTS_FILE=${1:-$WORKDIR};
    local line=;

    # If passed requirement_file is directory, then check for requirements file inside
    if [ -d "$REQUIREMENTS_FILE" ]; then
        REQUIREMENTS_FILE=$REQUIREMENTS_FILE/$REQUIREMENTS_FILE_NAME;
    fi

    # Get absolute path to requirements file
    REQUIREMENTS_FILE=$(readlink -f "$REQUIREMENTS_FILE");

    # Stop if file does not exists
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        echov "Requirements file '$REQUIREMENTS_FILE' not found!";
        return 0;
    fi

    # recursion protection
    local recursion_key=fetch_odoo_requirements;
    if ! recursion_protection_easy_check "$recursion_key" "$REQUIREMENTS_FILE"; then
        echoe -e "${YELLOWC}WARN${NC}: File $REQUIREMENTS_FILE already had been processed. skipping...";
        return 0
    fi

    # Process requirements file and run fetch_module subcomand for each line
    if [ -f "$REQUIREMENTS_FILE" ] && [ ! -d "$REQUIREMENTS_FILE" ]; then
        echov "Processing requirements file $REQUIREMENTS_FILE";
        while read -r line || [[ -n "$line" ]]; do
            if [ -n "$line" ] && [[ ! "$line" == "#"* ]]; then
                if eval "fetch_module $line"; then
                    echoe -e "Line ${GREENC}OK${NC}: $line";
                else
                    echoe -e "Line ${REDC}FAIL${NC}: $line";
                fi
            fi
        done < "$REQUIREMENTS_FILE";
    fi
}

# fetch_pip_requirements <filepath>
function fetch_pip_requirements {
    local pip_requirements=${1:-$WORKDIR};
    if [ -d "$pip_requirements" ]; then
        pip_requirements=$pip_requirements/$PIP_REQUIREMENTS_FILE_NAME;
    fi

    if [ ! -f "$pip_requirements" ]; then
        return 0;
    fi

    # Check recursion
    local recursion_key=fetch_pip_requirements;
    if ! recursion_protection_easy_check "$recursion_key" "$pip_requirements"; then
        echoe -e "${YELLOWC}WARN${NC}: File $pip_requirements already had been processed. skipping...";
        return 0
    fi

    # Do pip install
    #
    # Here we set workdir to directory that conains requirements file,
    # before running pip install, to allow usage of relative requirements.
    # This is useful in case, when addon depends on python module,
    # that is not on pip or github, but placed directly in addon directory,
    # and should be installed via setup.py
    #
    # Example requirements.txt:
    #
    # -e ./lib/python-project
    #
    local req_dir;
    req_dir=$(dirname "$pip_requirements");
    (cd "$req_dir" && exec_pip -q install -r "$pip_requirements");
}

# fetch_oca_requirements <filepath>
function fetch_oca_requirements {
    local oca_requirements=${1:-$WORKDIR};
    if [ -d "$oca_requirements" ]; then
        oca_requirements=$oca_requirements/$OCA_REQUIREMENTS_FILE_NAME;
    fi

    if [ ! -f "$oca_requirements" ]; then
        echov "No oca file: $oca_requirements";
        return 0;
    fi

    oca_requirements=$(readlink -f "$oca_requirements");

    # Check recursion
    local recursion_key=fetch_oca_requirements;
    if ! recursion_protection_easy_check "$recursion_key" "$oca_requirements"; then
        echoe -e "${YELLOWC}WARN${NC}: File $oca_requirements already had been processed. skipping...";
        return 0
    fi

    local is_read_finished=0;
    while true; do
       # TODO: rwerite with while: IFS='' read -r line || [[ -n "$line" ]]; do
       if ! read -ra line; then
           is_read_finished=1;
       fi
       if [ -n "$line" ] && [[ ! "$line" == "#"* ]]; then
           local opt=""; #"--name ${line[0]}";

           # if there are no url specified then use --oca shortcut
           if [ -z "${line[1]}" ]; then
               opt="$opt --oca ${line[0]}";
           else
               # else, specify url directly
               opt="$opt --repo ${line[1]}";
           fi

           # add branch if it spcified in file
           if [ -n "${line[2]}" ]; then
               opt="$opt --branch ${line[2]}";
           fi
           
           if eval "fetch_module $opt"; then
               echo -e "Line ${GREENC}OK${NC}: $opt";
           else
               echo -e "Line ${GREENC}FAIL${NC}: $opt";
           fi
       fi
       if [ "$is_read_finished" -ne 0 ]; then
           break;
       fi
    done < "$oca_requirements";
}

# get_repo_name <repository> [<desired name>]
# converts for example https://github.com/katyukha/base_tags.git to
# base_tags
function get_repo_name {
    if [ -z "$2" ]; then
        local R;
        R=$(basename "$1");  # get repository name
        R=${R%.git};  # remove .git suffix from name
        echo "$R";
    else
        echo "$2";
    fi
}

# Clone git repository.
#
# fetch_clone_repo <url> <dest> [branch]
function fetch_clone_repo_git {
    local repo_url=$1; shift;
    local repo_dest=$1; shift;

    local extra_git_opt;
    local git_clone_opt;
    local repo_branch_opt;
    local git_cmd;

    if [ -n "$1" ]; then
        repo_branch_opt="-b $1";
        git_clone_opt="$git_clone_opt $repo_branch_opt";
    fi

    if [ -n "$CI_JOB_TOKEN_GIT_HOST" ] && [ -n "$GITLAB_CI" ] && [ -n "$CI_JOB_TOKEN" ]; then
        extra_git_opt="$extra_git_opt -c url.\"https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_JOB_TOKEN_GIT_HOST}/\".insteadOf=\"git@${CI_JOB_TOKEN_GIT_HOST}:\"";
        extra_git_opt="$extra_git_opt -c url.\"https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_JOB_TOKEN_GIT_HOST}/\".insteadOf=\"https://${CI_JOB_TOKEN_GIT_HOST}/\"";
        extra_git_opt="$extra_git_opt -c url.\"https://gitlab-ci-token:${CI_JOB_TOKEN}@${CI_JOB_TOKEN_GIT_HOST}/\".insteadOf=\"${CI_JOB_TOKEN_GIT_HOST}/\"";
        echoe -e "${BLUEC}Use ${YELLOWC}gitlab-ci-token${BLUEC} for auth to repository ${YELLOWC}${CI_JOB_TOKEN_GIT_HOST}${NC}";
    fi

    [ -z "$VERBOSE" ] && git_clone_opt="$git_clone_opt -q "
    git_cmd="git $extra_git_opt clone --recurse-submodules $git_clone_opt $repo_url $repo_dest";
    if ! eval "$git_cmd"; then
        echo -e "${REDC}Cannot clone [git] '$repo_url to $repo_dest'!${NC}";
    elif [ -z "$repo_branch_opt" ]; then
        # IF repo clonned successfuly, and not branch specified then
        # try to checkout to ODOO_VERSION branch if it exists.
        (
            cd "$repo_dest";
            if [ "$(git_get_branch_name)" != "${ODOO_VERSION:-$ODOO_BRANCH}" ] && [[ -n $(git branch --list -a "origin/${ODOO_VERSION:-$ODOO_BRANCH}") ]]; then
                git checkout -q "${ODOO_VERSION:-$ODOO_BRANCH}";
            fi
        )
    fi
}

# Clone hg repository.
#
# fetch_clone_repo <url> <dest> [branch]
function fetch_clone_repo_hg {
    local repo_url=$1; shift;
    local repo_dest=$1; shift;

    # optional branch arg
    if [ -n "$1" ]; then
        local repo_branch_opt="-r $1"; shift;
    fi

    if ! check_command hg; then
        echoe -e "${REDC}ERROR${NC}: Mercurial is not installed. Install it via ${BLUEC}odoo-helper pip install Mercurial${NC}."
    elif ! execv hg clone "$repo_branch_opt" "$repo_url" "$repo_dest"; then
        echoe -e "${REDC}ERROR${NC}: Cannot clone [hg] ${BLUEC}$repo_url${NC} to ${BLUEC}$repo_dest${NC}!${NC}";
    elif [ -z "$repo_branch_opt" ]; then
        # IF repo clonned successfuly, and not branch specified then
        # try to checkout to ODOO_VERSION branch if it exists.
        (
            cd "$repo_dest";
            if [ "$(HGPLAIN=1 hg branch)" != "${ODOO_VERSION:-$ODOO_BRANCH}" ] && HGPLAIN=1 execv hg branches | grep "^${ODOO_VERSION:-$ODOO_BRANCH}\s" > /dev/null; then
                execv hg update "${ODOO_VERSION:-$ODOO_BRANCH}";
            fi;
        )
    fi
}

# Clone repository. Supported types: git, hg
#
# fetch_clone_repo <type> <url> <dest> [branch]
# fetch_clone_repo git <url> <dest> [branch]
# fetch_clone_repo hg <url> <dest> [branch]
function fetch_clone_repo {
    local repo_type=$1; shift;
    local repo_url=$1; shift;
    local repo_dest=$1; shift;

    # optional branch arg
    if [ -n "$1" ]; then
        local repo_branch=$1; shift;
    fi

    echoe -e "${BLUEC}Clonning [${YELLOWC}$repo_type${BLUEC}]:${NC} ${YELLOWC}$repo_url${BLUEC} to ${YELLOWC}$repo_dest${BLUEC} (branch ${YELLOWC}$repo_branch${BLUEC})${NC}";
    if [ "$repo_type" == "git" ]; then
        fetch_clone_repo_git "$repo_url" "$repo_dest" "$repo_branch";
    elif [ "$repo_type" == "hg" ]; then
        fetch_clone_repo_hg "$repo_url" "$repo_dest" "$repo_branch";
    else
        echoe -e "${REDC}ERROR${NC}:Unknown repo type: ${YELLOWC}$repo_type${NC}";
    fi

}


# Download module from Odoo Market
function fetch_download_odoo_app {
    local app_name=$1;
    local tmp_dir;
    local app_tmp_path;
    local app_tmp_name;
    local download_path;
    local download_url;
    download_url="https://apps.odoo.com/loempia/download/${app_name}/${ODOO_VERSION}/${app_name}.zip?deps";
    tmp_dir=$(mktemp -d);
    download_path="${tmp_dir}/${app_name}"

    echo -e "${LBLUEC}INFO: ${BLUEC}Downloading addon ${YELLOWC}${app_name}${BLUEC}...${NC}";
    if ! wget -q -T 15 "$download_url" -O "${download_path}.zip"; then
        echoe -e "${REDC}ERROR${NC}: Cannot download app ${YELLOWC}${app_name}${NC}";
        rm -r "$tmp_dir";
        return 2;
    fi

    echo -e "${LBLUEC}INFO: ${BLUEC}Unpacking addon ${YELLOWC}${app_name}${BLUEC}...${NC}";
    if ! (cd "$tmp_dir" && unzip -q "$app_name.zip"); then
        echoe -e "${REDC}ERROR${NC}: Cannot unzip app ${YELLOWC}${app_name}${NC}";
        rm -r "$tmp_dir";
        return 3;
    else
        rm "$download_path.zip";
    fi

    echo -e "${LBLUEC}INFO: ${BLUEC}Checking addon ${YELLOWC}${app_name}${BLUEC}...${NC}";
    if ! is_odoo_module "$download_path"; then
        echoe -e "${REDC}ERROR${NC}: Download app is not odoo module!";
        rm -r "$tmp_dir";
        return 4;
    fi

    for app in "$tmp_dir"/*; do
        app_tmp_path=$(readlink -f "$app");
        if ! is_odoo_module "$app"; then
            echoe -e "${LBLUEC}INFO: ${BLUEC}Skipping ${YELLOWC}${app_tmp_path}${BLUEC}: it is not Odoo addon...${NC}";
            continue;
        fi
        app_tmp_name=$(basename "$app_tmp_path");
        if [ -e "$DOWNLOADS_DIR/$app_tmp_name" ]; then
            local manifest_file;
            local version_installed;
            manifest_file=$(addons_get_manifest_file "$DOWNLOADS_DIR/$app_tmp_name");
            version_installed=$(run_python_cmd "print(eval(open('$manifest_file', 'rt').read()).get('version', '$ODOO_VERSION.0.0.0'))");
            manifest_file=$(addons_get_manifest_file "$app_tmp_path");
            version_downloaded=$(run_python_cmd "print(eval(open('$manifest_file', 'rt').read()).get('version', '$ODOO_VERSION.0.0.0'))");
            if version_cmp_gte "$version_installed" "$version_downloaded"; then
                echoe -e "${YELLOWC}WARNING:${BLUEC} you have new version of ${YELLOWC}${app_tmp_name}${BLUEC} installed. Skipping...${NC}";
                continue;
            else
                local backup_addon_path;
                backup_addon_path=$DOWNLOADS_DIR/$app_tmp_name.bkp.$(date +'%Y-%m-%d.%H-%M-%S');
                echoe -e "${YELLOWC}WARNING:${BLUEC} you have older version of ${YELLOWC}${app_tmp_name}${BLUEC} installed. Replacing...${NC}";
                mv "$DOWNLOADS_DIR/$app_tmp_name" "$backup_addon_path";
                echoe -e "${LBLUEC}INFO:${BLUEC} old version of ${YELLOWC}${app_tmp_name}${BLUEC} backed up at ${YELLOWC}${backup_addon_path}${BLUEC}.${NC}";
            fi
        fi
        mv "$app_tmp_path" "$DOWNLOADS_DIR/$app_tmp_name";
        echoe -e "${LBLUEC}INFO: ${BLUEC}Linking addon ${YELLOWC}${app_tmp_name}${BLUEC}...${NC}";
        link_module off "$DOWNLOADS_DIR/$app_tmp_name";
    done

    rm -r "$tmp_dir";
    echoe -e "${GREENC}OK:${BLUEC} App ${YELLOWC}${app_name}${BLUEC} fetchec successfully...${NC}";
    echoe "";
    echoe -e "${LBLUEC}TIP:${BLUEC} Run ${YELLOWC}odoo-helper addons update-list${BLUEC} to update list of addons in databases${NC}";
}

# fetch_module -r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
# fetch_module --hg <hg repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
# fetch_module --requirements <requirements file>
function fetch_module {
    # TODO: simplify this function. remove unneccessary options
    local usage="
    Usage:
        $SCRIPT_NAME fetch -r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch --github <github username/reponame> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch --oca <OCA reponame> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch --requirements <requirements file>

    Options:
        -r|--repo <repo>         - git repository to get module from
        --github <user/repo>     - allows to specify repository located on github in short format
        --oca <repo name>        - allows to specify Odoo Comunity Association module in simpler format
        --hg <repo>              - mercurial repository to get addon from.
        --odoo-app <app_name>    - [experimental] fetch module from Odoo Apps Market.
                                   Works only for free modules.
                                   Does not download dependencies.
        -m|--module <module>     - module name to be fetched from repository
        -n|--name <repo name>    - repository name. this name is used for directory to clone repository in.
                                   Usualy not required
        -b|--branch <branch>     - name fo repository branch to clone
        --requirements <file>    - path to requirements file to fetch required modules
                                   NOTE: requirements file must end with newline.

    Note that in one call only one option of (-r, --github, --oca) must be present in one line.

    Examples:
       # fetch default branch of base_tags repository, link all modules placed in repository
       $SCRIPT_NAME fetch -r https://github.com/crnd-inc/generic-addons

       # same as previous but via --github option
       $SCRIPT_NAME fetch --github crnd-inc/generic-addons

       # fetch project_description module from project repository of OCA
       $SCRIPT_NAME fetch --oca project -m project_description

       # fetch bureaucrat_helpdesk_lite module from Odoo Apps
       $SCRIPT_NAME fetch --odoo-app bureaucrat_helpdesk_lite
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    local REPOSITORY=;
    local MODULE=;
    local REPO_NAME=;
    local REPO_BRANCH=;
    local REPO_BRANCH_OPT=;
    local REPO_TYPE=git;

    # Check if first argument is git repository
    if [[ "$1" != -* ]] && git ls-remote "$1" > /dev/null 2>&1; then
        REPOSITORY="$1";
        shift;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -r|--repo)
                if [ -n "$REPOSITORY" ]; then
                    echoe -e "${REDC}ERROR${NC}: Attempt to specify multiple repos on one call...";
                    return 1;
                fi
                REPOSITORY="$2";
                shift;
            ;;
            --hg)
                if [ -n "$REPOSITORY" ]; then
                    echoe -e "${REDC}ERROR${NC}: Attempt to specify multiple repos on one call...";
                    return 2;
                fi
                REPOSITORY="$2";
                REPO_TYPE=hg;
                shift;
            ;;
            --github)
                if [ -n "$REPOSITORY" ]; then
                    echoe -e "${REDC}ERROR${NC}: Attempt to specify multiple repos on one call...";
                    return 3;
                fi
                REPOSITORY="https://github.com/$2";
                shift;
            ;;
            --oca)
                if [ -n "$REPOSITORY" ]; then
                    echoe -e "${REDC}ERROR${NC}: Attempt to specify multiple repos on one call...";
                    return 4;
                fi
                REPOSITORY="https://github.com/OCA/$2";
                # for backward compatability (if odoo version not defined,
                # then use odoo branch
                REPO_BRANCH=${REPO_BRANCH:-${ODOO_VERSION:-$ODOO_BRANCH}};
                shift;
            ;;
            --odoo-app)
                fetch_download_odoo_app "$2";
                return;
            ;;
            -m|--module)
                MODULE="$2";
                shift;
            ;;
            -n|--name)
                REPO_NAME="$2";
                shift;
            ;;
            -b|--branch)
                REPO_BRANCH="$2";
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --requirements)
                if [ -f "$2" ]; then
                    fetch_requirements "$2";
                    return 0;
                else
                    echoe -e "${REDC}ERROR${NC}: Requirements file '${YELLOWC}${2}${NC}' does not exists!";
                    return 1
                fi
            ;;
            *)
                echoe -e "${REDC}ERROR${NC}: Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done

    if [ -z "$REPOSITORY" ]; then
        echo "No git repository supplied to fetch module from!";
        echo "";
        print_usage;
        return 2;
    fi

    REPO_NAME=${REPO_NAME:-$(get_repo_name "$REPOSITORY")};
    local REPO_PATH=$REPOSITORIES_DIR/$REPO_NAME;

    local recursion_key="fetch_module";
    if ! recursion_protection_easy_check "$recursion_key" "${REPO_TYPE}__${REPO_PATH}__${MODULE:-all}"; then
        echov -e "${YELLOWC}WARNING${NC}: fetch REPO__MODULE ${REPO_TYPE}__${REPO_PATH}__${MODULE:-all} already had been processed. skipping...";
        return 0
    fi
    # Conditions:
    # - repo dir not exists and no module name specified
    #    - clone
    # - repo dir not exists and module name specified
    #    - module present in addons
    #        - warn and return
    #    - module absent in addons
    #        - clone and link
    # - repo dir exists:
    #    - repository is already clonned

    # Clone
    if [ ! -d "$REPO_PATH" ]; then
        if [ -n "$MODULE" ] && [ -d "$ADDONS_DIR/$MODULE" ]; then
            echoe -e "${YELLOWC}WARNING${NC}: The module ${BLUEC}$MODULE${NC} already present in addons dir";
            return 0;
        else
            fetch_clone_repo "$REPO_TYPE" "$REPOSITORY" "$REPO_PATH" "$REPO_BRANCH";
        fi
    fi

    if [ -d "$REPO_PATH" ]; then
        # Link repo only if it exists
        link_module off "$REPO_PATH" "$MODULE";
    fi
}
