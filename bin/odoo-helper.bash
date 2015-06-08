#!/bin/bash

# Use odoo-helper --help for a documentation

SCRIPT=$0;
SCRIPT_NAME=`basename $SCRIPT`;
F=`readlink -f $SCRIPT`;  # full script path;
WORKDIR=`pwd`;

REQUIREMENTS_FILE_NAME="odoo_requirements.txt";
CONF_FILE_NAME="odoo-helper.conf";

set -e;

# random_string [length]
# default length = 8
function random_string {
    < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-8};
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

# load_conf <conf file> <conf file> ...
function load_conf {
    for conf_file in $@; do
        if [ -f $conf_file ]; then
            echo "Loading conf: $conf_file";
            source $conf_file;
        fi
    done
}

load_conf "/etc/default/$CONF_FILE_NAME" \
          "$HOME/$CONF_FILE_NAME" \
          `search_file_up $WORKDIR $CONF_FILE_NAME`;

function print_usage {
    echo "
    Usage:
        $SCRIPT_NAME [global options] command [command options]

    Current project directory:
        ${PROJECT_ROOT_DIR:-'No project found'};

    Available commands:
        fetch_module [--help]
        link_module <repo_path> [<module_name>]
        fetch_requirements <file name>
        run_server [args passed to server]
        test_module [--help]
        env                                         - export environment variables
        create_db <db_name> [cofig file to use]
        drop_db <db_name> [cofig file to use]
        help
    
    Global options:
        --addons_dir <addons_directory>
        --downloads_dir <downloads_directory>
        --virtual_env <virtual_env_dir>       - optional, if specified, python dependencies
                                                will be installed in that virtual env
        --use_copy                            - if set, then downloaded modules, repositories will
                                                be copied instead of being symlinked
        --no-clean-up                         - disable cleanup. usualy used if joining few calls to this script
                                                this option disables cleanup actions such as remove temporary file and so.

    Also global options may be set up using configuration files.
    Folowing file paths will be searched for file $CONF_FILE_NAME:
        - /etc/default/$CONF_FILE_NAME  - Default conf. there may be some general settings placed
        - $HOME/$CONF_FILE_NAME         - User specific oconf  (overwrites previous conf)
        - Project specific conf         - File $CONF_FILE_NAME will be searched in $WORKDIR and all parent
                                          directories. First one found will be used

    Configuration files are simple bash scripts that sets environment variables

    Available environment variables:
        DOWNLOADS_DIR                   - Directory where all downloads hould be placed
        ADDONS_DIR                      - directory to place addons fetched (thats one in odoo's addons_path)
        VENV_DIR                        - Directory of virtual environment, if virtualenv is used
                                        - Note, that if VENV_DIR not set, than system will think that odoo is installed system-wide.
        USE_COPY                        - If set, then addons will be coppied in addons dir, instead of standard symlinking
        ODOO_BRANCH                     - used in run_server command to decide how to run it
        ODOO_TEST_CONF_FILE             - used to run tests. this configuration file will be used for it
";
}

# fetch_requirements <file_name>
function fetch_requirements {
    # Process requirements file and run fetch_module subcomand for each line
    local REQUIREMENTS_FILE=$1;
    if [ -d "$REQUIREMENTS_FILE" ]; then
        REQUIREMENTS_FILE=$REQUIREMENTS_FILE/$REQUIREMENTS_FILE_NAME;
    fi
    if [ -f "$REQUIREMENTS_FILE" ] && [ ! -d "$REQUIREMENTS_FILE" ]; then
        echo "Processing requirements file $REQUIREMENTS_FILE";
        while read -r line; do
            if [ ! -z "$line" ] && [[ ! "$line" == "#"* ]]; then
                if fetch_module $line; then
                    echo "Line OK: $line";
                else
                    echo "Line FAIL: $line";
                fi
            fi
        done < $REQUIREMENTS_FILE;
    else
        echo "Requirements file '$REQUIREMENTS_FILE' not found!"
    fi
}

# is_odoo_module <module_path>
function is_odoo_module {
    if [ -d $1 ] && [ -f "$1/__openerp__.py" ]; then
        return 0
    else
        return 1
    fi
}

# get_repo_name <repository> [<desired name>]
function get_repo_name {
    if [ -z "$2" ]; then
        local R=`basename $1`;
        R=${R%.git};
        echo $R;
    else
        echo $2;
    fi
}

# link_module_impl <source_path> <dest_path>
function link_module_impl {
    local SOURCE=`readlink -f $1`;
    local DEST=`readlink -f $2`;

    if [ ! -d $DEST ]; then
        if [ -z $USE_COPY ]; then
            ln -s $SOURCE $DEST ;
        else
            rm -rf $DEST;
            cp -r $SOURCE $DEST;
        fi
        fetch_requirements $DEST;
    else
        echo "Module $SOURCE already linked to $DEST";
    fi
}

# link_module <repo_path> [<module_name>]
function link_module {
    local REPO_PATH=$1;
    local MODULE_NAME=$2;

    echo "Linking module $1 [$2] ...";

    # Guess repository type
    if is_odoo_module $REPO_PATH; then
        # single module repo
        link_module_impl $REPO_PATH $ADDONS_DIR/${MODULE_NAME:-`basename $REPO_PATH`} 
    else
        # multi module repo
        if [ -z $MODULE_NAME ]; then
            # No module name specified, then all modules in repository should be linked
            for file in "$REPO_PATH"/*; do
                if is_odoo_module $file; then
                    link_module_impl $file $ADDONS_DIR/`basename $file`
                    # recursivly link module
                fi
            done
        else
            # Module name specified, then only single module should be linked
            link_module_impl $REPO_PATH/$MODULE_NAME $ADDONS_DIR/$MODULE_NAME;
        fi
    fi
}

# fetch_python_dep <python module>
function fetch_python_dep {
    if [ -z $VENV_DIR ]; then
        pip install --user $1;
    else
        source $VENV_DIR/bin/activate && pip install $1 && deactivate;
    fi
}

# fetch_module -r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>] [--requirements <requirements file>]
# fetch_module -p <python module> [-p <python module>] ...
function fetch_module {
    local usage="Usage:
        $SCRIPT_NAME fetch_module -r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
        $SCRIPT_NAME fetch_module --requirements <requirements file>
        $SCRIPT_NAME fetch_module -p|--python <python module>
        Options:
            -r|--repo       - git repository to get module from
            -m|--module     - module name to be fetched from repository
            -n|--name       - repository name. this name is used for directory to clone repository in
            -b|--branch     - name fo repository branch to clone
            --requirements  - path to requirements file to fetch required modules
            -p|--python     - fetch python dependency
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
                REPO_BRANCH_OPT="-b $REPO_BRANCH";
                shift;
            ;;
            -p|--python)
                PYTHON_INSTALL=1;
                fetch_python_dep $2
                shift;
            ;;
            -h|--help)
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

    if [ -z $REPOSITORY ]; then
        if [ ! -z $PYTHON_INSTALL ]; then
            exit 0;
        fi

        echo "No git repository supplied to fetch module from!";
        echo "";
        print_usage;
        exit 2;
    fi

    REPO_NAME=${REPO_NAME:-`get_repo_name $REPOSITORY`};
    local REPO_PATH=$DOWNLOADS_DIR/$REPO_NAME;

    # Clone or pull repository
    if [ ! -d $REPO_PATH ]; then
        git clone -q $REPO_BRANCH_OPT $REPOSITORY $REPO_PATH;
    else
        (
            cd $REPO_PATH;
            local branch_name=$(git symbolic-ref -q HEAD);
            branch_name=${branch_name##refs/heads/};
            branch_name=${branch_name:-HEAD};

            if [ "$branch_name" = "$REPO_BRANCH" ]; then
                git pull;
            else
                git fetch;
                git stash;  # TODO: seems to be not correct behavior. think about workaround
                git checkout $REPO_BRANCH;
            fi
        )
    fi

    link_module $REPO_PATH $MODULE
}

# Prints server script name
# (depends on ODOO_BRANCH environment variable,
#  which should be placed in project config)
# Now it simply returns openerp-server
function get_server_script {
    echo "openerp-server";
    #case $ODOO_BRANCH in
        #8.0|7.0|6.0)
            #echo "openerp-server";
        #;;
        #*)
            #echo "unknown server version";
            #exit 1;
        #;;
    #esac;
}

# Internal function to run odoo server
function run_server_impl {
    local SERVER=`get_server_script`;
    if [ -z $VENV_DIR ]; then
        echo "Running server: $SERVER $@";
        exec $SERVER $@;
    else
        echo "Running server: (source $VENV_DIR/bin/activate && exec $SERVER $@ && deactivate)";
        (source $VENV_DIR/bin/activate && exec $SERVER $@ && deactivate);
    fi
}

# run_server <arg1> .. <argN>
# all arguments will be passed to odoo server
function run_server {
    run_server_impl -c $ODOO_CONF_FILE $@;
}

# odoo_create_db <name> [odoo_conf_file]
function odoo_create_db {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};
    local python_cmd="import openerp;";
    
    python_cmd="$python_cmd openerp.tools.config.parse_config(['-c', '$conf_file']);";
    python_cmd="$python_cmd openerp.service.start_internal();"
    python_cmd="$python_cmd openerp.cli.server.setup_signal_handlers();"
    python_cmd="$python_cmd openerp.netsvc.dispatch_rpc('db', 'create_database', (openerp.tools.config['admin_passwd'], '$db_name', True, 'en_US'));"

    if [ -z $VENV_DIR ]; then
        exec python -c "$python_cmd";
    else
        (source $VENV_DIR/bin/activate && exec python -c "$python_cmd" && deactivate);
    fi

}

# odoo_drop_db <name> [odoo_conf_file]
function odoo_drop_db {
    local db_name=$1;
    local conf_file=${2:-$ODOO_CONF_FILE};
    local python_cmd="import openerp;";
    python_cmd="$python_cmd openerp.tools.config.parse_config(['-c', '$conf_file']);";
    python_cmd="$python_cmd openerp.service.start_internal();"
    python_cmd="$python_cmd openerp.cli.server.setup_signal_handlers();"
    python_cmd="$python_cmd openerp.netsvc.dispatch_rpc('db', 'drop', (openerp.tools.config['admin_passwd'], '$db_name'));"

    if [ -z $VENV_DIR ]; then
        exec python -c "$python_cmd";
    else
        (source $VENV_DIR/bin/activate && exec python -c "$python_cmd" && deactivate);
    fi
}

# create_tmp_dirs
function create_tmp_dirs {
    TMP_ROOT_DIR="/tmp/odoo-tmp-`random_string 16`";
    echo "Temporary dir created: $TMP_ROOT_DIR";

    OLD_ADDONS_DIR=$ADDONS_DIR;
    OLD_DOWNLOADS_DIR=$DOWNLOADS_DIR;
    OLD_ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;
    ADDONS_DIR=$TMP_ROOT_DIR/addons;
    DOWNLOADS_DIR=$TMP_ROOT_DIR/downloads;
    ODOO_TEST_CONF_FILE=$TMP_ROOT_DIR/odoo.test.conf;
    
    mkdir -p $ADDONS_DIR;
    mkdir -p $DOWNLOADS_DIR;
    sed -r "s@addons_path(.*)@addons_path\1,$ADDONS_DIR@" $OLD_ODOO_TEST_CONF_FILE > $ODOO_TEST_CONF_FILE
}

# remove_tmp_dirs
function remove_tmp_dirs {
    if [ -z $TMP_ROOT_DIR ]; then
        exit -1;  # no tmp root was created
    fi

    ADDONS_DIR=$OLD_ADDONS_DIR;
    DOWNLOADS_DIR=$OLD_DOWNLOADS_DIR;
    ODOO_TEST_CONF_FILE=$OLD_ODOO_TEST_CONF_FILE;
    rm -r $TMP_ROOT_DIR;

    echo "Temporary dir removed: $TMP_ROOT_DIR";
    TMP_ROOT_DIR=;
    OLD_ADDONS_DIR=;
    OLD_DOWNLOADS_DIR=;
    OLD_ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;
}

# test_module_impl <module> [extra_options]
# example: test_module_impl base -d test1
function test_module_impl {
    local module=$1
    shift;  # all next arguments will be passed to server

    set +e; # do not fail on errors
    # Install module
    run_server_impl -c $ODOO_TEST_CONF_FILE --init=$module --log-level=warn --stop-after-init \
        --no-xmlrpc --no-xmlrpcs $@;
    # Test module
    run_server_impl -c $ODOO_TEST_CONF_FILE --update=$module --log-level=test --test-enable --stop-after-init \
        --no-xmlrpc --no-xmlrpcs $@;
    set -e; # Fail on any error
}

# test_module [--create-test-db] -m <module_name>
# test_module [--tmp-dirs] [--create-test-db] -m <module name> -m <module name>
function test_module {
    local modules="";
    local link_module_args="";
    local test_log_file="${LOG_DIR:-.}/odoo.test.log";
    local odoo_extra_options="";
    local usage="
    Usage 

        $SCRIPT_NAME test_module [options] [-m <module_name>] [-m <module name>] ...

    Options:
        --create-test-db    - Creates temporary database to run tests in
        --remove-log-file   - If set, then log file will be removed after tests finished
        --link <repo>:[module_name]
        --tmp-dirs          - use temporary dirs for test related downloads and addons
        --no-tee            - disable duplication test odutput to log file. this options anables colored test output
    ";

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options/commands supplied $#: $@";
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            --create-test-db)
                local create_test_db=1;
            ;;
            --remove-log-file)
                local remove_log_file=1;
            ;;
            -m|--module)
                modules=$modules$'\n'$2;  # add module to module list
                shift;
            ;;
            --link)
                link_module_args=$link_module_args$'\n'$2;
                shift;
            ;;
            --tmp-dirs)
                local tmp_dirs=1
            ;;
            --no-tee)
                local no_tee=1;
            ;;
            *)
                echo "Unknown option: $key";
                exit 1;
            ;;
        esac;
        shift;
    done;

    if [ ! -z $tmp_dirs ]; then
        create_tmp_dirs;
    fi

    if [ ! -z "$link_module_args" ]; then
        for lm_arg in $link_module_args; do
            local lm_arg_x=`echo $lm_arg | tr ':' ' '`;
            link_module $lm_arg_x;
        done
    fi

    if [ ! -z $create_test_db ]; then
        local test_db_name=`random_string 24`;
        test_log_file="${LOG_DIR:-.}/odoo.test.$test_db_name.log";
        echo "Creating test database: $test_db_name";
        odoo_create_db $test_db_name $ODOO_TEST_CONF_FILE;
        odoo_extra_options="$odoo_extra_options -d $test_db_name";
    fi


    for module in $modules; do
        echo "Testing module $module...";
        if [ -z $no_tee ]; then
            test_module_impl $module $odoo_extra_options | tee -a $test_log_file;
        else
            test_module_impl $module $odoo_extra_options;
        fi

    done


    if [ ! -z $create_test_db ]; then
        echo "Droping test database: $test_db_name";
        odoo_drop_db $test_db_name $ODOO_TEST_CONF_FILE
    fi


    if grep -q -e "CRITICAL" \
               -e "ERROR $test_db_name" \
               -e "At least one test failed" \
               -e "no access rules, consider adding one" \
               -e "invalid module names, ignored" \
               -e "OperationalError: FATAL" \
               "$test_log_file"; then
        echo "Test result: FAIL";
        local res=1;
    else
        echo "Test result: OK";
        local res=0;
    fi

    if [ ! -z $remove_log_file ]; then
        rm $test_log_file;
    fi

    if [ ! -z tmp_dirs ]; then
        remove_tmp_dirs;
    fi

    return $res;
}

# do_export_vars
# exports global env vars got from config
function do_export_vars {
    export DOWNLOADS_DIR;
    export ADDONS_DIR;
    export VENV_DIR;
    export USE_COPY;
    export ODOO_BRANCH;
    export ODOO_TEST_CONF_FILE;
}

# Parse command line options and run commands
if [[ $# -lt 1 ]]; then
    echo "No options/commands supplied $#: $@";
    print_usage;
    exit 0;
fi

while [[ $# -gt 0 ]]
do
    key="$1";
    case $key in
        -h|--help|help)
            print_usage;
            exit 0;
        ;;
        --downloads_dir)
            DOWNLOADS_DIR=$2;
            shift;
        ;;
        --addons_dir)
            ADDONS_DIR=$2;
            shift;
        ;;
        --virtual_env)
            VENV_DIR=$2;
            shift;
        ;;
        --use_copy)
            USE_COPY=1;
        ;;
        env)
            do_export_vars;
            exit;
        ;;
        fetch_module)
            shift;
            fetch_module $@;
            exit
        ;;
        fetch_requirements)
            fetch_requirements $2;
            exit;
        ;;
        link_module)
            shift;
            link_module $@
            exit;
        ;;
        run_server)
            shift;
            run_server $@;
            exit;
        ;;
        test_module)
            shift;
            test_module $@;
            exit;
        ;;
        create_db)
            shift;
            odoo_create_db $@;
            exit;
        ;;
        drop_db)
            shift;
            odoo_drop_db $@;
            exit;
        ;;
        *)
            echo "Unknown option global option /command $key";
            exit 1;
        ;;
    esac
    shift
done
