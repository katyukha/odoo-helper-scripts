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

# ---------------------------------------------------------------------

ohelper_require 'git';
ohelper_require 'utils';

set -e; # fail on errors

# ci_ensure_versions_ok <version1> <version2>
# ensure that version2 is greater than version1
function ci_ensure_versions_ok {
    local version1="$1"; shift;
    local version2="$1"; shift;

    # NOTE: here we inverse pythons True to bash zero status code
    if ! execv python -c "from pkg_resources import parse_version as V; exit(V('${version1}') < V('${version2}'));"; then
        return 0;
    else
        return 1;
    fi
}

# ci_validate_version <version>
# validate specified version
# version must look like x.x.y.y.y
# where x.x is odoo version and y.y.y repository version
function ci_validate_version {
    local version="$1";
    if ! [[ "$version" =~ ^${ODOO_VERSION}\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1;
    fi
    return 0;
}

# ci_fix_version_serie <version>
# Attempt to fix version serie (to be same as current odoo version)
function ci_fix_version_serie {
    local version="$1";
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        echo "${ODOO_VERSION}.${BASH_REMATCH[1]}";
    else
        return 1;
    fi
        #echo "${ODOO_VERSION}.${BASH_REMATCH[1]}.$((${BASH_REMATCH[2]} + 1))";
}

# ci_fix_version_number <version>
# Attempt to fix version number (increase patch part)
function ci_fix_version_number {
    local version="$1";
    if [[ "$version" =~ ^${ODOO_VERSION}\.([0-9]+\.[0-9]+)\.([0-9]+)$ ]]; then
        echo "${ODOO_VERSION}.${BASH_REMATCH[1]}.$(( BASH_REMATCH[2] + 1))";
    else
        return 1;
    fi
}

# ci_fix_version_minor <version>
# Attempt to fix version number (increase minor part)
function ci_fix_version_minor {
    local version="$1";
    if [[ "$version" =~ ^${ODOO_VERSION}\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${ODOO_VERSION}.${BASH_REMATCH[1]}.$(( BASH_REMATCH[2] + 1)).0";
    else
        return 1;
    fi
}

# ci_fix_version_major <version>
# Attempt to fix version number (increase major part)
function ci_fix_version_major {
    local version="$1";
    if [[ "$version" =~ ^${ODOO_VERSION}\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${ODOO_VERSION}.$(( BASH_REMATCH[1] + 1)).0.0";
    else
        return 1;
    fi
}

# ci_git_get_repo_version_by_ref [-q] <repo path> <ref>
function ci_git_get_repo_version_by_ref {
    if [ "$1" == "-q" ]; then
        local quiet=1;
        shift;
    fi

    local version;
    local repo_path="$1"; shift;
    local git_ref="$1"; shift;
    local cdir;
    cdir="$(pwd)";

    cd "$repo_path";
    if [ "$git_ref" == "-working-tree-" ]; then
        version=$(cat ./VERSION 2>/dev/null);
    else
        version=$(git show -q "${git_ref}:./VERSION" 2>/dev/null);
    fi
    # shellcheck disable=SC2181
    if [ "$?" -ne 0 ] || [ -z "$version" ]; then
        [ -z "$quiet" ] && echoe -e "${YELLOWC}WARNING${NC}: repository version file (${BLUEC}${repo_path}/VERSION${NC}) not found or empty (revision ${BLUEC}${git_ref}${NC}! Using default version ${BLUEC}${ODOO_VERSION}.0.0.0${NC}";
        echo "${ODOO_VERSION}.0.0.0"
        return 1;
    else
        echo "$version";
    fi

    cd "$cdir";
}

# ci_git_get_addon_version_by_ref [-q] <addon path> <ref>
function ci_git_get_addon_version_by_ref {
    if [ "$1" == "-q" ]; then
        local quiet=1;
        shift;
    fi

    local addon_path="$1"; shift;
    local git_ref="$1"; shift;
    local cdir;
    cdir="$(pwd)";

    local manifest_content;
    local version="${ODOO_VERSION}.0.0.0";

    cd "$addon_path";

    # Get manifest content at start revision
    if [ "$git_ref" == "-working-tree-" ]; then
        version=$(cat ./VERSION 2>/dev/null);
        manifest_content=$(cat ./__manifest__.py 2>/dev/null);
        if [ -z "$manifest_content" ]; then
            manifest_content=$(cat ./__openerp__.py 2>/dev/null);
        fi
    else
        manifest_content=$(git show -q "${git_ref}:./__manifest__.py" 2>/dev/null);
        if [ -z "$manifest_content" ]; then
            manifest_content=$(git show -q "${git_ref}:./__openerp__.py" 2>/dev/null);
        fi
    fi

    # Get version in first revision
    if [ -z "$manifest_content" ]; then
        version="${ODOO_VERSION}.0.0.0";
    else
        version=$(echo "$manifest_content" | execv python -c "import sys; print(eval(sys.stdin.read()).get('version', '${ODOO_VERSION}.1.0.0'))");
        # shellcheck disable=SC2181
        if [ "$?" -ne 0 ]; then
            [ -z "$quiet" ] && echoe -e "${YELLOWC}WARNING${NC} Cannot read version from manifest in first revision! Using ${BLUEC}${ODOO_VERSION}.0.0.0${NC} as default.";
        fi
    fi
    echo "$version";
    cd "$cdir";
}

# ci_check_versions_git <repo> [ref start] [ref end]
function ci_check_versions_git {
    local usage="
    Check that versions of changed addons have been updated

    Usage:
        $SCRIPT_NAME ci check-versions-git [options] [repo] [start] [end]

    Options:
        --ignore-trans      - ignore translations
                              Note: this option may not work on old git versions
        --repo-version      - ensure repository version updated.
                              Repository version have to be specified in
                              file named VERSION placed in repository root.
                              Version have to be string of
                              5 numbers separated by dots.
                              For example: 11.0.1.0.0
                              Version number have to be updated if at least one
                              addon changed
        --fix-serie         - [experimental] Fix module serie only
        --fix-version       - [experimental] Attempt to fix versions in changed
                              addons. By default, it changes 'patch' part of version.
        --fix-version-minor - [experimental] Attempt to fix versions in changed
                              addons. Increases minor part of version number
        --fix-version-major - [experimental] Attempt to fix versions in changed
                              addons. Increases major part of version number
        --fix-version-fp    - [experimental] Fix version conflicts during
                              forwardport
        -h|--help|help      - print this help message end exit

    Parametrs:
        [repo]    - path to git repository to search for changed addons in
        [start]   - git start revision
        [end]     - [optional] git end revision.
                    if not set then working tree used as end revision
    ";
    local git_changed_extra_opts=( );
    local repo_path;
    local ref_start;
    local ref_end;
    local check_repo_version=0;
    local opt_fix_serie=0;
    local opt_fix_version=0;
    local opt_fix_version_minor=0;
    local opt_fix_version_major=0;
    local opt_fix_version_fp=0;
    local cdir;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                shift;
                return 0;
            ;;
            --ignore-trans)
                git_changed_extra_opts+=( --ignore-trans );
                shift;
            ;;
            --repo-version)
                check_repo_version=1;
                shift;
            ;;
            --fix-serie)
                opt_fix_serie=1;
                shift;
            ;;
            --fix-version)
                opt_fix_serie=1;
                opt_fix_version=1;
                shift;
            ;;
            --fix-version-minor)
                opt_fix_serie=1;
                opt_fix_version=1;
                opt_fix_version_minor=1;
                shift;
            ;;
            --fix-version-major)
                opt_fix_serie=1;
                opt_fix_version=1;
                opt_fix_version_major=1;
                shift;
            ;;
            --fix-version-fp)
                opt_fix_serie=1;
                opt_fix_version=1;
                opt_fix_version_fp=1;
                shift;
            ;;
            *)
                break;
            ;;
        esac
    done

    if [ -n "$1" ]; then
        repo_path=$(readlink -f "$1"); shift;
    else
        repo_path=$(pwd);
    fi
    if ! git_is_git_repo "$repo_path"; then
        echoe -e "${RED}ERROR${NC}: ${YELLOWC}${repo_path}${NC} is not git repository!";
        return 3;
    fi
    if [ -n "$1" ]; then
        ref_start="$1"; shift;
    else
        ref_start="origin/$ODOO_VERSION"
    fi

    if [ -n "$1" ]; then
        ref_end="$1"; shift;
    else
        ref_end="-working-tree-";
    fi
    cdir=$(pwd);

    # Check addons versions
    local result=0;
    local changed_addons;
    mapfile -t changed_addons < <(git_get_addons_changed "${git_changed_extra_opts[@]}" "$repo_path" "$ref_start" "$ref_end" | sed '/^$/d')
    local addon_path;
    for addon_path in "${changed_addons[@]}"; do
        if [ "$opt_fix_version_fp" -eq 1 ] && git_is_merging "$addon_path"; then
            local manifest_path;
            manifest_path=$(addons_get_manifest_file "$addon_path")
            if git_file_has_conflicts "$addon_path" "$manifest_path"; then
                exec_py "$ODOO_HELPER_LIB/pylib/ci_fix_version.py" "$manifest_path";
            fi
        fi
        if ! addons_is_installable "$addon_path"; then
            continue;
        fi
        cd "$addon_path";
        local addon_name;
        addon_name=$(basename "$addon_path");
 
        echoe -e "${BLUEC}Checking version of ${YELLOWC}${addon_name}${BLUEC} addon ...${NC}";
        local version_after;
        local version_before;
        version_before=$(ci_git_get_addon_version_by_ref -q "$addon_path" "${ref_start}");
        version_after=$(ci_git_get_addon_version_by_ref "$addon_path" "${ref_end}");

        if ! ci_validate_version "$version_after"; then
            if [ "$opt_fix_serie" -eq 1 ]; then
                local new_version;
                new_version=$(ci_fix_version_serie "$version_after");
                # shellcheck disable=SC2181
                if [ "$?" -eq 0 ]; then
                    local addon_manifest_file;
                    addon_manifest_file=$(addons_get_manifest_file "$addon_path");
                    sed -i "s/$version_after/$new_version/g" "$addon_manifest_file";
                    version_after="$new_version";
                    echoe -e "${GREENC}OK${NC}: version serie fixed for addon ${YELLOWC}${addon_name}${NC}";
                else
                    echoe -e "${REDC}ERROR${NC}: Cannot fix version serie ${YELLOWC}${version_after}${NC}. Skipping...";
                fi
            else
                echoe -e "${REDC}FAIL${NC}: Wrong version format. Correct version must match format: ${YELLOWC}${ODOO_VERSION}.X.Y.Z${NC}. Got ${YELLOWC}${version_after}${NC}";
                result=1;
                continue;
            fi
        fi

        # Compare version
        if ci_ensure_versions_ok "$version_before" "$version_after"; then
            # version before is less that version_after
            echoe -e "${GREENC}OK${NC}";
        else
            if [ "$opt_fix_version" -eq 1 ]; then
                local new_version;
                new_version=$(ci_fix_version_serie "$version_after");
                if [ "$opt_fix_version_minor" -eq 1 ]; then
                    new_version=$(ci_fix_version_minor "$new_version");
                elif [ "$opt_fix_version_major" -eq 1 ]; then
                    new_version=$(ci_fix_version_major "$new_version");
                else
                    new_version=$(ci_fix_version_number "$new_version");
                fi
                # shellcheck disable=SC2181
                if [ "$?" -eq 0 ]; then
                    local addon_manifest_file;
                    addon_manifest_file=$(addons_get_manifest_file "$addon_path");
                    sed -i "s/$version_after/$new_version/g" "$addon_manifest_file";
                    echoe -e "${GREENC}OK${NC}: version number fixed for addon ${YELLOWC}${addon_name}${NC}";
                else
                    echoe -e "${REDC}ERROR${NC}: Cannot fix version number ${YELLOWC}${version_after}${NC}. Skipping...";
                fi
            else
                echoe -e "${REDC}FAIL${NC}: ${YELLOWC}${addon_name}${NC} have incorrect new version!"
                echoe -e "${BLUEC}-----${NC} new version ${YELLOWC}${version_after}${NC} must be greater than old version ${YELLOWC}${version_before}${NC}";
                result=1;
            fi
        fi

    done;

    # Check repo version
    if [ "$check_repo_version" -eq 1 ] && [ ${#changed_addons[@]} -gt 0 ]; then
        local repo_version_before;
        local repo_version_after;
        repo_version_before=$(ci_git_get_repo_version_by_ref -q "$repo_path" "$ref_start");
        repo_version_after=$(ci_git_get_repo_version_by_ref "$repo_path" "$ref_end");
        if [ -z "$repo_version_after" ]; then
            echoe -e "${REDC}ERROR${NC}: repository version not specified! Please, specify repository version in ${YELLOWC}${repo_path}/VERSION${NC} file.";
            return 2;
        fi
        if ! ci_validate_version "$repo_version_after"; then
            echoe -e "${REDC}ERROR${NC}: Wrong repo version format. Correct version must match format: ${YELLOWC}${ODOO_VERSION}.X.Y.Z${NC}. Got ${YELLOWC}${repo_version_after}${NC}"
            return 2;
        fi
        if ci_ensure_versions_ok "$repo_version_before" "$repo_version_after"; then
            echoe -e "Repository version: ${GREENC}OK${NC}";
        else
            echoe -e "${REDC}FAIL${NC}: incorrect new repository version!"
            echoe -e "${BLUEC}-----${NC} new reposotory version ${YELLOWC}${repo_version_after}${NC} must be greater than old version ${YELLOWC}${repo_version_before}${NC}";
            result=1;
        fi
    fi
    cd "$cdir";
    return $result;
}


function ci_cmd_git_fix_versions {
    local usage="
    Fix (increase) versions of changed addons.

    WARNING: this command is experimental

    Usage:
        $SCRIPT_NAME ci fix-versions [options] [repo] [start] [end]

    Options:
        -p|--patch         - Attempt to fix versions in changed
                             addons. By default, it changes 'patch' part of version.
        -m|--minor         - Attempt to fix versions in changed
                             addons. Increases minor part of version number
        -M|--major         - Attempt to fix versions in changed
                             addons. Increases major part of version number
        -h|--help|help     - print this help message end exit

    Parametrs:
        [repo]    - path to git repository to search for changed addons in
        [start]   - git start revision
        [end]     - git end revision.
                    if not set then working tree used as end revision
    ";
    local git_check_versions_opts=( );
    local repo_path;
    local ref_start;
    local ref_end;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                shift;
                return 0;
            ;;
            -p|--patch)
                git_check_versions_opts+=( --fix-version );
                shift;
            ;;
            -m|--minor)
                git_check_versions_opts+=( --fix-version-minor );
                shift;
            ;;
            -M|--major)
                git_check_versions_opts+=( --fix-version-major );
                shift;
            ;;
            *)
                break;
            ;;
        esac
    done

    # Repo path
    if [ -n "$1" ]; then
        git_check_versions_opts+=( "$1" );
        shift;
    fi
    # Start revision
    if [ -n "$1" ]; then
        git_check_versions_opts+=( "$1" );
        shift;
    fi
    # End revision
    if [ -n "$1" ]; then
        git_check_versions_opts+=( "$1" );
        shift;
    fi
    ci_check_versions_git "${git_check_versions_opts[@]}"
}

# Ensure that all addons in specified directory have icons
# ci_ensure_addons_have_icons <addon path>
function ci_ensure_addons_have_icons {
    local usage="
    Ensure that all addons in specified directory have icons.

    Usage:

        $SCRIPT_NAME ci ensure-icons <addon path>  - ensure addons have icons
        $SCRIPT_NAME ci ensure-icons --help        - print this help message
    ";

    # Parse options
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    local addons_path="$1";
    if [ ! -d "$addons_path" ]; then
        echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${addons_path}${NC} is not a directory!";
        return 1;
    fi

    local res=0;
    local addons_list;
    mapfile -t addons_list < <(addons_list_in_directory --installable "$1")

    local addon;
    for addon in "${addons_list[@]}"; do
        if [ ! -f "$addon/static/description/icon.png" ]; then
            echoe -e "${REDC}ERROR${NC}: addon ${YELLOWC}${addon}${NC} have no icon!";
            res=1;
        fi
    done

    return $res;
}

# Commit and push changes added to index.
# NOTE: it is required to call 'git add' before this command
#
# ci_push_changes <commit_name>
function ci_push_changes {
    local usage="
    Push changes (added to git index) to this repo to same branch.
    Have to be used in Continious Integration pipelines.
    Have to be ran only in Gitlab

    This command could be used in automated flows that modifies repository code

    WARNING: this command is experimental, and have to be used carefully

    Usage:

        $SCRIPT_NAME ci push-changes <commit msg>  - push changes 
        $SCRIPT_NAME ci push-changes --help        - print this help message
    ";

    # Parse options
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    if [ -z "$CI_JOB_TOKEN_GIT_HOST" ] || [ -z "$GITLAB_CI" ]; then
        echoe -e "${REDC}ERROR${NC}: this command available only on gitlab. And it is required to define 'CI_JOB_TOKEN_GIT_HOST' variable with gitlab repository hostname."
        return 1;
    fi
    if [ -z "$CI_SSH_PRIVATE_KEY" ] || [ -z "$CI_SSH_PUBLIC_KEY" ]; then
        echoe -e "${REDC}ERROR${NC}: It is required to define private and public ssh keys with write access in variables 'CI_SSH_PRIVATE_KEY'and 'CI_SSH_PUBLIC_KEY'!";
        return 2;
    fi
    if [ -z "${CI_COMMIT_BRANCH}" ]; then
        echoe -e "${REDC}ERROR${NC}: There is no 'CI_COMMIT_BRANCH' variable defined!";
        return 3;
    fi

    local commit_name=${1};
    if [ -z "$commit_name" ]; then
        echoe -e "${REDC}ERROR${NC}: Please, specify commit name to push changes!";
        return 4;
    fi

    # Compute remote url to push changes to
    local git_remote_url="git@${CI_JOB_TOKEN_GIT_HOST}:${CI_PROJECT_PATH}";

    echoe -e "${LBLUEC}INFO${NC}: committing as user (name=${GITLAB_USER_NAME}, email=${GITLAB_USER_EMAIL})";
    git -c "user.name='${GITLAB_USER_NAME}'" -c "user.email='${GITLAB_USER_EMAIL}'" commit -m "${commit_name}";
    echo "$CI_SSH_PRIVATE_KEY" > /tmp/push_key;
    echo "$CI_SSH_PUBLIC_KEY" > /tmp/push_key.pub;
    echo "" > /tmp/pushsshconfig;
    chmod 600 /tmp/push_key;
    chmod 600 /tmp/push_key.pub;
    chmod 600 /tmp/pushsshconfig;
    echoe -e "${LBLUEC}INFO${NC}: setting remote url to ${git_remote_url}";
    git remote set-url --push origin "${git_remote_url}";
    echoe -e "${LBLUEC}INFO${NC}: pushing changes to ${CI_COMMIT_BRANCH}";
    git -c core.sshCommand='ssh -T -o PasswordAuthentication=no -o StrictHostKeyChecking=no -F /tmp/pushsshconfig -i /tmp/push_key' \
        push origin "HEAD:${CI_COMMIT_BRANCH}";
}

function ci_do_forwardport {
    local git_path;
    local current_dir;
    git_path="$(pwd)";
    current_dir="$(pwd)";
    local git_remote_name="origin";
    local usage="

    Initiate forwardport of changes from one stable branch to another.
    This command will create new git branch based on destination branch,
    then it will apply missing changes from source branch.
    Also, it will automatically try to fix versions.
    After all automated actions completed, it will stop, for human review.

    This command must be executed in destination odoo version.
    For example, if we plan to forwardport changes from 11.0 to 12.0,
    then we have to call this command on 12.0 branch

    ${YELLOWC}WARNING${NC}: this command is experimental, and have to be used carefully

    Usage:

        $SCRIPT_NAME ci do-forward-port [options]  - do forwardport
        $SCRIPT_NAME ci do-forward-port --help     - print this help message

    Options:
        -s|--src-branch <branch>         - [required] source branch to take changes from
        --path <path>                    - path to git repository. default current ($git_path)
        -r|--remote <name>               - name of git remote. Default: $git_remote_name
        --fm|--forward-migrations        - Rename all migrations for source version
                                           to new odoo-version. Now it is enabled by default.
        --no-fm|--no-forward-migrations  - Do not forward-port migrations
        --mm|--migrate-modules           - [experimental] Migrate module's code

        --help                           - show this help message
    ";

    # Parse options
    if [[ $# -lt 1 ]]; then
        echo -e "$usage";
        return 0;
    fi

    local tmp_branch;
    local src_branch;
    local dst_branch="$ODOO_VERSION";
    local forward_migrations=1;
    local migrate_modules=0;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -s|--src-branch)
                src_branch=$2;
                shift;
            ;;
            -r|--remote)
                git_remote_name="$2";
                shift;
            ;;
            --path)
                git_path=$2
                shift;
            ;;
            --fm|--forward-migrations)
                forward_migrations=1;
            ;;
            --no-fm|--no-forward-migrations)
                forward_migrations=0;
            ;;
            --mm|--migrate-modules)
                migrate_modules=1;
            ;;
            -h|--help|help)
                echo -e "$usage";
                return 0;
            ;;
            *)
                echoe -e "${REDC}ERROR${NC}: Unknown option - '$key'";
                return 1;
            ;;
        esac
        shift
    done

    if ! git_is_git_repo "$git_path"; then
        echoe -e "${REDC}ERROR${NC}: '$git_path' is not git repository!";
        return 2;
    fi
    if [ -z "$src_branch" ]; then
        echoe -e "${REDC}ERROR${NC}: src-branch option is required!";
        return 3;
    fi
    if ! git_is_clean "$git_path"; then
        echoe -e "${REDC}ERROR${NC}: This operation could be applied only on clean repo!";
        return 3;
    fi

    tmp_branch="$dst_branch-oh-forward-port-from-$src_branch-x-$(random_string 4)";
    git --git-dir "$git_path/.git" fetch --all;
    git --git-dir "$git_path/.git" checkout --no-track -b "$tmp_branch" "$git_remote_name/$dst_branch";

    # Merge, but do not fail on error
    if ! git --git-dir "$git_path/.git" merge --no-ff --no-commit --edit "$git_remote_name/$src_branch"; then
        echoe -e "${YELLOWC}WARNING${NC}: Merge command was not successfull, it seems that there was conflicts during merge. Please, resolve them manually";
    fi

    git status;
    # Do not forwardport changes in ADDONS.md
    if [ -f "$git_path/ADDONS.md" ]; then
        git --git-dir "$git_path/.git" reset -q -- "$git_path/ADDONS.md";
        git --git-dir "$git_path/.git" clean -fdx -- "$git_path/ADDONS.md";
        [ -f "$git_path/ADDONS.md" ] && git --git-dir "$git_path/.git" checkout --ours "$git_path/ADDONS.md";
        [ -f "$git_path/ADDONS.md" ] && git --git-dir "$git_path/.git" add "$git_path/ADDONS.md";
    fi
    
    # Do not forwardport changes in ADDONS.csv
    if [ -f "$git_path/ADDONS.csv" ]; then
        git --git-dir "$git_path/.git" reset -q -- "$git_path/ADDONS.csv";
        git --git-dir "$git_path/.git" clean -fdx -- "$git_path/ADDONS.csv";
        [ -f "$git_path/ADDONS.csv" ] && git --git-dir "$git_path/.git" checkout --ours "$git_path/ADDONS.csv";
        [ -f "$git_path/ADDONS.csv" ] && git --git-dir "$git_path/.git" add "$git_path/ADDONS.csv";
    fi

    # Do not forwardport translations
    git --git-dir "$git_path/.git" reset -q -- "*.po" "*.pot"
    git --git-dir "$git_path/.git" clean -fdx -- "*.po" "*.pot"
    git --git-dir "$git_path/.git" checkout --ours "*.po" "*.pot" || true;
    git --git-dir "$git_path/.git" add "*.po" "*.pot" || true;

    # Attempt tot fix versions of modules
    ci_check_versions_git --fix-version-fp "$git_path" "$git_remote_name/$dst_branch";

    # Forward migrations if needed
    local changed_addons;
    mapfile -t changed_addons < <(git_get_addons_changed "$git_path" "$git_remote_name/$dst_branch" "-working-tree-" | sed '/^$/d')
    for addon_path in "${changed_addons[@]}"; do
        local addon_name;
        local manifest_path;
        addon_name=$(addons_get_addon_name "$addon_path");
        manifest_path=$(addons_get_manifest_file "$addon_path")
        # Add to index manifest files with fixed versions if there is no conflicts
        if ! git_file_has_conflicts "$addon_path" "$manifest_path"; then
            git --git-dir "$git_path/.git" add "$manifest_path";
        fi

        if [ -d "$addon_path/migrations" ]; then
            local migration_src_prefix="$addon_path/migrations/$src_branch.";
            local migration_dst_prefix="$addon_path/migrations/$dst_branch.";
            for migration_src in "$migration_src_prefix"*; do
                local migration_name=${migration_src#"$migration_src_prefix"};
                if [[ "$migration_name" == "0.0.0" ]]; then
                    # We do not need to forward port odoo serie specific
                    # migrations.
                    continue;
                fi

                local migration_dst=${migration_dst_prefix}${migration_name};
                if [ -d "$migration_src" ] && [ ! -d "${migration_dst}" ]; then
                    if [ "$forward_migrations" -eq 1 ]; then
                        echoe -e "${LBLUEC}INFO${NC}: Forwarding migration ${YELLOWC}${addon_name}${NC} (${BLUEC}${migration_name}${NC}) from ${YELLOWC}${src_branch}${NC}.${BLUEC}${migration_name}${NC} to ${YELLOWC}${dst_branch}${NC}.${BLUEC}${migration_name}${NC}!";
                        if ! git mv "$migration_src" "${migration_dst_prefix}${migration_name}"; then
                            echoe -e "${REDC}ERROR${NC}: Cannot forward migration ${YELLOWC}${addon_name}${NC} (${BLUEC}${migration_name}${NC}) from ${YELLOWC}${src_branch}${NC}.${BLUEC}${migration_name}${NC} to ${YELLOWC}${dst_branch}${NC}.${BLUEC}${migration_name}${NC}!";
                        fi
                    else
                        echoe -e "${YELLOWC}WARNING${NC}: There is chaged migrations for add ${BLUEC}${addon_name}${NC} in this forwardport, but automitic forwardport of migrations disables.";
                    fi
                fi
            done
        fi
    done

    if [ "$migrate_modules" -eq 1 ]; then
        for addon_path in "${changed_addons[@]}"; do
            local addon_name;
            addon_name=$(addons_get_addon_name "$addon_path");
            echoe -e "${BLUEC}Migrating addon ${YELLOWC}${addon_name}${BLUEC} ...${NC}";
            exec_py "${ODOO_HELPER_LIB}/pylib/ci_fw_postfixes.py" --version="$ODOO_VERSION" --path="$addon_path";
            echoe -e "${BLUEC}Migrated addon ${YELLOWC}${addon_name}${BLUEC}: ${GREENC}OK${NC}";
        done
    fi

    # Show resulting message
    if git_is_clean "$git_path"; then
        echoe -e "${YELLOWC}WARNING${NC}: It seems that there is no changes to forwardport!";
    else
        echoe -e "${GREENC}DONE${NC}: forwardport seems to be completed.";
        echoe -e "${YELLOWC}TODO${NC}: Review changes via command: ${BLUEC}git diff${NC}";
        echoe -e "${LBLUEC}HINT${NC}: Use following commands to push changes after review:\n" \
                 "    - ${BLUEC}git add -u${NC}\n" \
                 "    - ${BLUEC}git commit${NC}\n" \
                 "    - ${BLUEC}git push \"$git_remote_name\" \"$tmp_branch\"${NC}";
        echoe -e "${LBLUEC}HINT${NC}: If you want to cancel this forwardport, then run following commands:\n" \
                 "    - ${BLUEC}git add .${NC}\n" \
                 "    - ${BLUEC}git merge --abort${NC}\n";
    fi
}

# Ensure that all changed addons in specified directory have changelog entries
# ci_ensure_addons_have_changelog <addon path>
function ci_ensure_addons_have_changelog {
    local usage="
    Ensure that all addons in specified directory have changelog entries.

    Changelog entries have to be located in 'changelog' directory inside addon.
    Each entry is file named in following format:
        changelog.X.Y.Z.md
    Where:
        X.Y.Z is addon version without Odoo version

    Usage:

        $SCRIPT_NAME ci ensure-changelog [options] <path> <start> [end]

    Options:

        --ignore-trans     - ignore translations
                             Note: this option may not work on old git versions
        --format <md|rst>  - changelog format: Markdown(md) or ReStructuredText (rst).
                             default: md
        --help             - print this help message

    Parametrs:
        <repo>    - path to git repository to search for changed addons in
        <start>   - git start revision
        [end]     - [optional] git end revision.
                    if not set then working tree used as end revision
    ";

    local ref_start;
    local ref_end;
    local git_changed_extra_opts=( );
    local changelog_format="md";

    # Parse options
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --ignore-trans)
                git_changed_extra_opts+=( --ignore-trans );
                shift;
            ;;
            --format)
                changelog_format="$2";
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    # Compute addons path
    local addons_path="$1"; shift;
    if [ ! -d "$addons_path" ]; then
        echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${addons_path}${NC} is not a directory!";
        return 1;
    fi

    # Guess git revisions
    ref_start="$1"; shift;
    if [ -n "$1" ]; then
        ref_end="$1"; shift;
    else
        ref_end="-working-tree-";
    fi

    # Find changed addons
    local changed_addons;
    mapfile -t changed_addons < <(git_get_addons_changed "${git_changed_extra_opts[@]}" "$addons_path" "$ref_start" "$ref_end" | sed '/^$/d')

    local res=0;
    local addon;
    local addon_name;
    local addon_version;
    local addon_version_short;
    for addon in "${changed_addons[@]}"; do
        addon_name=$(addons_get_addon_name "$addon");
        addon_version=$(ci_git_get_addon_version_by_ref -q "$addon" "$ref_end");
        if [ -z "$addon_version" ]; then
            echee -e "${REDC}WARNING${NC}: It seems that addon ${YELLOWC}${addon_name}${NC} removed. skipping...";
            continue;
        fi
        addon_version_short=${addon_version##"$ODOO_VERSION".};
        if [ ! -f "$addon/changelog/changelog.$addon_version_short.$changelog_format" ]; then
            echoe -e "${REDC}ERROR${NC}: addon ${YELLOWC}${addon_name}${NC} have no changelog entry! (format: ${YELLOWC}${changelog_format}${NC})";
            res=1;
        fi
    done

    return $res;
}

function ci_auto_migrate_modules {
    local usage="
    Try to automatically migrate modules to current odoo version.
    It is not full migration, but just some predefined actions, that
    could simplify migrations. The changes made by this command does not
    change or update logic. Currently it is only set of find-and-replace rules
    applied to module.

    Usage:

        $SCRIPT_NAME ci auto-migrate-modules [options] [args]

    Options:
        --help             - print this help message

    Args:
        Same arguments as passed to odoo-helper addons list

    Example:

        # Command below will try to migrate all installable modules in
        # current directory
        $SCRIPT_NAME ci auto-migrate-modules --installable .
    ";
    # Parse options
    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    local addons_to_migrate
    mapfile -t addons_to_migrate < <(addons_list_in_directory --by-path "$@");
    for addon_path in "${addons_to_migrate[@]}"; do
        local addon_name;
        addon_name=$(addons_get_addon_name "$addon_path");
        echoe -e "${BLUEC}Migrating addon ${YELLOWC}${addon_name}${BLUEC} ...${NC}";
        exec_py "${ODOO_HELPER_LIB}/pylib/ci_fw_postfixes.py" --version="$ODOO_VERSION" --path="$addon_path";
        echoe -e "${BLUEC}Migrated addon ${YELLOWC}${addon_name}${BLUEC}: ${GREENC}OK${NC}";
    done
}

function ci_command {
    local usage="
    This command provides subcommands useful in CI (Continious Integration) process

    NOTE: This command is experimental and everything may be changed.

    Usage:
        $SCRIPT_NAME ci check-versions-git [--help]   - ensure versions of changed addons were updated
        $SCRIPT_NAME ci fix-versions [--help]         - fix versions of changed addons
        $SCRIPT_NAME ci ensure-icons [--help]         - ensure all addons in specified directory have icons
        $SCRIPT_NAME ci ensure-changelog [--help]     - ensure that changes described in changelog
        $SCRIPT_NAME ci push-changes [--help]         - push changes to same branch
        $SCRIPT_NAME ci do-forward-port [--help]      - do forwardport
        $SCRIPT_NAME ci do-fwp [--help]               - alias to 'do-forward-port'
        $SCRIPT_NAME ci do-fp [--help]                - alias to 'do-forward-port'
        $SCRIPT_NAME ci do-fw [--help]                - alias to 'do-forward-port'
        $SCRIPT_NAME ci auto-migrate-modules [--help] - automatically try to migrate modules to current version
        $SCRIPT_NAME ci -h|--help|help                - show this help message
    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            check-versions-git)
                shift;
                ci_check_versions_git "$@";
                return;
            ;;
            fix-versions)
                shift;
                ci_cmd_git_fix_versions "$@";
                return;
            ;;
            ensure-icons)
                shift;
                ci_ensure_addons_have_icons "$@";
                return;
            ;;
            ensure-changelog)
                shift;
                ci_ensure_addons_have_changelog "$@";
                return;
            ;;
            push-changes)
                shift;
                ci_push_changes "$@";
                return;
            ;;
            do-forward-port|do-fp|do-fw|do-fwp)
                shift;
                ci_do_forwardport "$@";
                return;
            ;;
            auto-migrate-modules)
                shift;
                ci_auto_migrate_modules "$@";
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
    done
}
