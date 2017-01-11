if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
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
    REQUIREMENTS_FILE=$(readlink -f $REQUIREMENTS_FILE);

    # Stop if file does not exists
    if [ ! -f "$REQUIREMENTS_FILE" ]; then
        echov "Requirements file '$REQUIREMENTS_FILE' not found!";
        return 0;
    fi

    # recursion protection
    local recursion_key=fetch_odoo_requirements;
    if ! recursion_protection_easy_check $recursion_key $REQUIREMENTS_FILE; then
        echo -e "${YELLOWC}WARN${NC}: File $REQUIREMENTS_FILE already had been processed. skipping...";
        return 0
    fi

    # Process requirements file and run fetch_module subcomand for each line
    if [ -f "$REQUIREMENTS_FILE" ] && [ ! -d "$REQUIREMENTS_FILE" ]; then
        echov "Processing requirements file $REQUIREMENTS_FILE";
        while read -r line; do
            if [ ! -z "$line" ] && [[ ! "$line" == "#"* ]]; then
                if fetch_module $line; then
                    echo -e "Line ${GREENC}OK${NC}: $line";
                else
                    echo -e "Line ${GREENC}FAIL${NC}: $line";
                fi
            fi
        done < $REQUIREMENTS_FILE;
    fi
}

# fetch_pip_requirements <filepath>
function fetch_pip_requirements {
    local pip_requirements=${1:-$WORKDIR};
    if [ -d $pip_requirements ]; then
        pip_requirements=$pip_requirements/$PIP_REQUIREMENTS_FILE_NAME;
    fi

    if [ ! -f $pip_requirements ]; then
        return 0;
    fi

    # Check recursion
    local recursion_key=fetch_pip_requirements;
    if ! recursion_protection_easy_check $recursion_key $pip_requirements; then
        echo -e "${YELLOWC}WARN${NC}: File $pip_requirements already had been processed. skipping...";
        return 0
    fi

    # Do pip install
    execu pip install -r $pip_requirements;
}

# fetch_oca_requirements <filepath>
function fetch_oca_requirements {
    local oca_requirements=${1:-$WORKDIR};
    if [ -d $oca_requirements ]; then
        oca_requirements=$oca_requirements/$OCA_REQUIREMENTS_FILE_NAME;
    fi

    if [ ! -f "$oca_requirements" ]; then
        echov "No oca file: $oca_requirements";
        return 0;
    fi

    oca_requirements=$(readlink -f $oca_requirements);

    # Check recursion
    local recursion_key=fetch_oca_requirements;
    if ! recursion_protection_easy_check $recursion_key $oca_requirements; then
        echo -e "${YELLOWC}WARN${NC}: File $oca_requirements already had been processed. skipping...";
        return 0
    fi

    while read -ra line; do
       if [ ! -z "$line" ] && [[ ! "$line" == "#"* ]]; then
           local opt=""; #"--name ${line[0]}";

           # if there are no url specified then use --oca shortcut
           if [ -z ${line[1]} ]; then
               opt="$opt --oca ${line[0]}";
           else
               # else, specify url directly
               opt="$opt --repo ${line[1]}";
           fi

           # add branch if it spcified in file
           if [ ! -z ${line[2]} ]; then
               opt="$opt --branch ${line[2]}";
           fi
           
           if fetch_module $opt; then
               echo -e "Line ${GREENC}OK${NC}: $opt";
           else
               echo -e "Line ${GREENC}FAIL${NC}: $opt";
           fi
       fi
    done < $oca_requirements;
}

# get_repo_name <repository> [<desired name>]
# converts for example https://github.com/katyukha/base_tags.git to
# base_tags
function get_repo_name {
    if [ -z "$2" ]; then
        local R=`basename $1`;  # get repository name
        R=${R%.git};  # remove .git suffix from name
        echo $R;
    else
        echo $2;
    fi
}

# Install python dependencies
# fetch_python_dep <python module>
function fetch_python_dep {
    # Check if python dependency is vcs url like git+https://github.com/smth/smth
    # And if it is VCS dependency install it as editable via pip
    if [[ $1 =~ .*\+.* ]]; then
        local install_opt="-e $1";
    else
        local install_opt="$1";
    fi

    execu pip install $install_opt;
}

# fetch_module -r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
# fetch_module --requirements <requirements file>
# fetch_module -p <python module> [-p <python module>] ...
function fetch_module {
    # TODO: simplify this function. remove unneccessary options
    local usage="Usage:
        $SCRIPT_NAME fetch -r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch --github <github username/reponame> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch --oca <OCA reponame> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch --requirements <requirements file>
        $SCRIPT_NAME fetch -p|--python <python module>

        Options:
            -r|--repo <repo>         - git repository to get module from
            --github <user/repo>     - allows to specify repository located on github in short format
            --oca <repo name>        - allows to specify Odoo Comunity Association module in simpler format

            -m|--module <module>     - module name to be fetched from repository
            -n|--name <repo name>    - repository name. this name is used for directory to clone repository in.
                                       Usualy not required
            -b|--branch <branch>     - name fo repository branch to clone
            --requirements <file>    - path to requirements file to fetch required modules
            -p|--python <package>    - fetch python dependency. (it use pip to install package)
            -p|--python <vcs>+<repository>  - install python dependency directly from VCS

        Note that in one call only one option of (-r, --github, --oca) must be present in one line.

        Examples:
           # fetch default branch of base_tags repository, link all modules placed in repository
           $SCRIPT_NAME fetch -r https://github.com/katyukha/base_tags 

           # same as previous but via --github option
           $SCRIPT_NAME fetch --github katyukha/base_tags

           # fetch project_sla module from project-service repository of OCA using branch 7.0
           $SCRIPT_NAME fetch --oca project-service -m project_sla -b 7.0

        Also note that if using -p or --python option, You may install packages directly from vcs
        using syntax like

           $SCRIPT_NAME fetch -p <vcs>
    ";

    if [[ $# -lt 2 ]]; then
        echo "$usage";
        exit 0;
    fi

    local REPOSITORY=;
    local MODULE=;
    local REPO_NAME=;
    local REPO_BRANCH=;
    local REPO_BRANCH_OPT=;
    local PYTHON_INSTALL=;

    while [[ $# -gt 1 ]]
    do
        local key="$1";
        case $key in
            -r|--repo)
                REPOSITORY="$2";
                shift;
            ;;
            --github)
                REPOSITORY="https://github.com/$2";
                shift;
            ;;
            --oca)
                REPOSITORY="https://github.com/OCA/$2";
                # for backward compatability (if odoo version not defined,
                # then use odoo branch
                REPO_BRANCH=${REPO_BRANCH:-${ODOO_VERSION:-$ODOO_BRANCH}};
                shift;
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
            -p|--python)
                PYTHON_INSTALL=1;
                fetch_python_dep $2
                shift;
            ;;
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            --requirements)
                fetch_requirements $2;
                exit 0;
            ;;
            *)
                echo "Unknown option $key";
                exit 1;
            ;;
        esac
        shift
    done

    if [ ! -z $REPO_BRANCH ]; then
        REPO_BRANCH_OPT="-b $REPO_BRANCH";
    fi

    if [ -z $REPOSITORY ]; then
        if [ ! -z $PYTHON_INSTALL ]; then
            return 0;
        fi

        echo "No git repository supplied to fetch module from!";
        echo "";
        print_usage;
        exit 2;
    fi

    REPO_NAME=${REPO_NAME:-$(get_repo_name $REPOSITORY)};
    local REPO_PATH=$REPOSITORIES_DIR/$REPO_NAME;

    local recursion_key="fetch_module";
    if ! recursion_protection_easy_check $recursion_key "${REPO_PATH}__${MODULE:-all}"; then
        echo -e "${YELLOWC}WARN${NC}: fetch REPO__MODULE ${REPO_PATH}__${MODULE:-all} already had been processed. skipping...";
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
    if [ ! -d $REPO_PATH ]; then
        if [ ! -z $MODULE ] && [ -d "$ADDONS_DIR/$MODULE" ]; then
            echo "The module $MODULE already present in addons dir";
            return 0;
        else
            [ -z $VERBOSE ] && local git_clone_opt=" -q "
            if ! git clone $git_clone_opt $REPO_BRANCH_OPT $REPOSITORY $REPO_PATH; then
                echo -e "${REDC}Cannot clone '$REPOSITORY to $REPO_PATH'!${NC}";
            elif [ -z "$REPO_BRANCH_OPT" ]; then
                # IF repo clonned successfuly, and not branch specified then
                # try to checkout to ODOO_VERSION branch if it exists.
                (
                    cd $REPO_PATH && \
                    [ "$(git_get_branch_name)" != "${ODOO_VERSION:-$ODOO_BRANCH}" ] && \
                    [ $(git branch --list -a "origin/${ODOO_VERSION:-$ODOO_BRANCH}") ] && \
                    git checkout -q ${ODOO_VERSION:-$ODOO_BRANCH} || true
                )
            fi
        fi
    fi

    if [ -d $REPO_PATH ]; then
        # Link repo only if it exists
        link_module off $REPO_PATH $MODULE;
    fi
}
