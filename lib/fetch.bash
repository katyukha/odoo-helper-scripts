if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------

# Defin veriables
REQUIREMENTS_FILE_NAME="odoo_requirements.txt";


# fetch_requirements <file_name>
function fetch_requirements {
    local REQUIREMENTS_FILE=${1:-$WORKDIR};
    local line=;

    # Store here all requirements files processed to deal with circle dependencies
    if [ -z $REQ_FILES_PROCESSED ]; then
        REQ_FILES_PROCESSED[0]=$REQUIREMENTS_FILE;
    else
        # Check if file have been processed, and if so, return from function
        for processed_file in ${REQ_FILES_PROCESSED[*]}; do
            if [ "$processed_file" == "$REQUIREMENTS_FILE" ]; then
                echo -e "${YELLOWC}WARN${NC}: File $REQUIREMENTS_FILE already had been processed. skipping...";
                return 0;
            fi
        done;
        # If file have not been processed yet, add it to array with processed files
        # and process it
        REQ_FILES_PROCESSED[${#REQ_FILES_PROCESSED[*]}]=$REQUIREMENTS_FILE;
    fi

    # Process requirements file and run fetch_module subcomand for each line
    if [ -d "$REQUIREMENTS_FILE" ]; then
        REQUIREMENTS_FILE=$REQUIREMENTS_FILE/$REQUIREMENTS_FILE_NAME;
    fi
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
    else
        echov "Requirements file '$REQUIREMENTS_FILE' not found!";
    fi
}

# get_repo_name <repository> [<desired name>]
function get_repo_name {
    if [ -z "$2" ]; then
        local R=`basename $1`;  # get repository name
        R=${R%.git};  # remove .git suffix from name
        echo $R;
    else
        echo $2;
    fi
}

# link_module_impl <source_path> <dest_path> <force>
function link_module_impl {
    local SOURCE=`readlink -f $1`;
    local DEST="$2";
    local force=$3;

    if [ ! -z $force ] && [ -d $DEST ]; then
        echov "Rewriting module $DEST...";
        rm -rf $DEST;
    fi

    if [ ! -d $DEST ]; then
        if [ -z $USE_COPY ]; then
            ln -s $SOURCE $DEST ;
        else
            cp -r $SOURCE $DEST;
        fi
    else
        echov "Module $SOURCE already linked to $DEST";
    fi
    fetch_requirements $DEST;
}

# link_module [-f|--force] <repo_path> [<module_name>]
function link_module {
    local usage="
    Usage: 

        $SCRIPT_NAME link [-f|--force] <repo_path> [<module_name>]
    ";

    local force=;

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options supplied $#: $@";
        echo "";
        echo "$usage";
        exit 0;
    fi

    while [[ $1 == -* ]]
    do
        key="$1";
        case $key in
            -h|--help)
                echo "$usage";
                exit 0;
            ;;
            -f|--force)
                force=1;
            ;;
            *)
                echo "Unknown option $key";
                exit 1;
            ;;
        esac
        shift
    done


    local REPO_PATH=$1;
    local MODULE_NAME=$2;

    echov "Linking module $1 [$2] ...";

    # Guess repository type
    if is_odoo_module $REPO_PATH; then
        # single module repo
        link_module_impl $REPO_PATH $ADDONS_DIR/${MODULE_NAME:-`basename $REPO_PATH`} "$force";
    else
        # multi module repo
        if [ -z $MODULE_NAME ]; then
            # No module name specified, then all modules in repository should be linked
            for file in "$REPO_PATH"/*; do
                if is_odoo_module $file; then
                    link_module_impl $file $ADDONS_DIR/`basename $file` "$force";
                    # recursivly link module
                fi
            done
        else
            # Module name specified, then only single module should be linked
            link_module_impl $REPO_PATH/$MODULE_NAME $ADDONS_DIR/$MODULE_NAME "$force";
        fi
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
                REPO_BRANCH=${REPO_BRANCH:-$ODOO_BRANCH};  # Here we could use same branch as branch of odoo installed
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

    REPO_NAME=${REPO_NAME:-`get_repo_name $REPOSITORY`};
    local REPO_PATH=$DOWNLOADS_DIR/$REPO_NAME;

    # Conditions:
    # - repo dir not exists and no module name specified
    #    - clone
    # - repo dir not exists and module name specified
    #    - module present in addons
    #        - warn and return
    #    - module absent in addons
    #        - clone and link
    # - repo dir
    #    - pull 

    # Clone or pull repository
    if [ ! -d $REPO_PATH ]; then
        if [ ! -z $MODULE ] && [ -d "$ADDONS_DIR/$MODULE" ]; then
            echo "The module $MODULE already present in addons dir";
            return 0;
        else
            if [ -z $VERBOSE ]; then
                git clone -q $REPO_BRANCH_OPT $REPOSITORY $REPO_PATH;
            else
                git clone $REPO_BRANCH_OPT $REPOSITORY $REPO_PATH;
            fi
        fi
    else
        (
            cd $REPO_PATH;
            if [ -z $VERBOSE ]; then local verbose_opt="";
            else local verbose_opt=" -q "; fi
            if [ "$(get_git_branch_name)" == "$REPO_BRANCH" ]; then
                    git pull $verbose_opt;
            else
                git fetch $verbose_opt;
                git stash $verbose_opt;  # TODO: seems to be not correct behavior. think about workaround
                git checkout $verbose_opt $REPO_BRANCH;
            fi
        )
    fi

    link_module $REPO_PATH $MODULE
}
