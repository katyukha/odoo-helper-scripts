if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------
ohelper_require "postgres";


set -e; # fail on errors

# Set-up defaul values for environment variables
function install_preconfigure_env {
    ODOO_REPO=${ODOO_REPO:-https://github.com/odoo/odoo.git};
    ODOO_VERSION=${ODOO_VERSION:-9.0};
    ODOO_BRANCH=${ODOO_BRANCH:-$ODOO_VERSION};
    DOWNLOAD_ARCHIVE=${ODOO_DOWNLOAD_ARCHIVE:-${DOWNLOAD_ARCHIVE:-on}};
    CLONE_SINGLE_BRANCH=${CLONE_SINGLE_BRANCH:-on};
    DB_USER=${DB_USER:-${ODOO_DBUSER:-odoo}};
    DB_PASSWORD=${DB_PASSWORD:-${ODOO_DBPASSWORD:-odoo}};
    DB_HOST=${DB_HOST:-${ODOO_DBHOST:-localhost}};
    DB_PORT=${DB_PORT:-${ODOO_DBPORT:-5432}};
}

# create directory tree for project
function install_create_project_dir_tree {
    # create dirs is imported from common module
    create_dirs $PROJECT_ROOT_DIR \
        $ADDONS_DIR \
        $CONF_DIR \
        $LOG_DIR \
        $LIBS_DIR \
        $DOWNLOADS_DIR \
        $BACKUP_DIR \
        $REPOSITORIES_DIR \
        $BIN_DIR \
        $DATA_DIR;
}

# install_clone_odoo [path [branch [repo]]]
function install_clone_odoo {
    local odoo_path=${1:-$ODOO_PATH};
    local odoo_branch=${2:-$ODOO_BRANCH};
    local odoo_repo=${3:-${ODOO_REPO:-https://github.com/odoo/odoo.git}};
    local branch_opt=;

    if [ ! -z $odoo_branch ]; then
        branch_opt="$branch_opt --branch $odoo_branch";
    fi

    if [ "$CLONE_SINGLE_BRANCH" == "on" ]; then
        branch_opt="$branch_opt --single-branch";
    fi

    git clone $branch_opt $odoo_repo $odoo_path;
}

# install_download_odoo [path [branch [repo]]]
function install_download_odoo {
    local odoo_path=${1:-$ODOO_PATH};
    local odoo_branch=${2:-$ODOO_BRANCH};
    local odoo_repo=${3:-${ODOO_REPO:-https://github.com/odoo/odoo.git}};

    local odoo_archive=/tmp/odoo.$ODOO_BRANCH.tar.gz
    if [ -f $odoo_archive ]; then
        rm $odoo_archive;
    fi

    if [[ $ODOO_REPO == "https://github.com"* ]]; then
        local repo=${odoo_repo%.git};
        local repo_base=$(basename $repo);
        wget -O $odoo_archive $repo/archive/$ODOO_BRANCH.tar.gz;
        tar -zxf $odoo_archive;
        mv ${repo_base}-${ODOO_BRANCH} $ODOO_PATH;
        rm $odoo_archive;
    fi
}


# install_wkhtmltopdf
function install_wkhtmltopdf {
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-y";
    fi
    # Install wkhtmltopdf
    if ! check_command wkhtmltopdf > /dev/null; then
        local wkhtmltox_path=${DOWNLOADS_DIR:-/tmp}/wkhtmltox.deb;
        if [ ! -f $wkhtmltox_path ]; then
            local system_arch=$(dpkg --print-architecture);
            local release=$(lsb_release -sc);
            local release=${release:-trusty};  # try to install trusty version
            local download_link="https://downloads.wkhtmltopdf.org/0.12/0.12.2/wkhtmltox-0.12.2_linux-$release-$system_arch.deb"
            wget -q $download_link -O $wkhtmltox_path;
        fi
        with_sudo dpkg --force-depends -i $wkhtmltox_path  # install ignoring dependencies
        with_sudo apt-get -f install $opt_apt_always_yes;   # fix broken packages
        rm $wkhtmltox_path || true;  # try to remove downloaded file, ignore errors
    fi
}


# install_sys_deps_internal dep_1 dep_2 ... dep_n
function install_sys_deps_internal {
    # Odoo's debian/contol file usualy contains this in 'Depends' section 
    # so we need to skip it before running apt-get
    if [ "$1" == '${misc:Depends}' ]; then
        shift;
    fi
    echo "Installing system dependencies: $@";
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-y";
    fi
    with_sudo apt-get install $opt_apt_always_yes "$@";
}

# install_parse_debian_control_file <control file>
# parse debian control file to fetch odoo dependencies
function install_parse_debian_control_file {
    local file_path=$1;
    local sys_deps=$(perl -ne 'next if /^#/; $p=(s/^Depends:\s*/ / or (/^ / and $p)); s/,|\n|\([^)]+\)//mg; print if $p' < $file_path);
    echo "$sys_deps";
}

# install_sys_deps_for_odoo_version <odoo version>
# Note that odoo version here is branch of official odoo repository
function install_sys_deps_for_odoo_version {
    local odoo_version=$1;
    local control_url="https://raw.githubusercontent.com/odoo/odoo/$odoo_version/debian/control";
    local tmp_control=$(mktemp);
    wget $control_url -O $tmp_control;
    local sys_deps=$(install_parse_debian_control_file $tmp_control);
    install_sys_deps_internal $sys_deps;
    rm $tmp_control;
}

# Get dependencies from odoo's debian/control file
function install_sys_deps {
    local control_file=$ODOO_PATH/debian/control;

    if [ ! -f "$control_file" ] && [ ! -z $ODOO_VERSION ]; then
        # If odoo not installed, then fetch this file from odoo repository
        install_sys_deps_for_odoo_version $ODOO_VERSION;
    elif [ -f "$control_file" ]; then
        # Parse control file and install system dependencies
        local sys_deps=$(install_parse_debian_control_file $control_file);
        echo -e "${BLUEC}Sys deps to be installed:${NC} $sys_deps";
        install_sys_deps_internal $sys_deps;
    else
        echo -e "${REDC}ERROR! Cannot find debian/control file${NC}";
    fi
}

function install_and_configure_postgresql {
    local db_user=${1:-$DB_USER};
    local db_password=${2:-DB_PASSWORD};
    # Check if postgres is installed on this machine. If not, install it
    if ! postgres_is_installed; then
        postgres_install_postgresql;
        echo -e "${GREENC}Postgres installed${NC}";
    else
        echo -e "${YELLOWC}It seems that postgresql is already installed, so not installing it, just configuring...${NC}";
    fi

    if [ ! -z $db_user ] && [ ! -z $db_password ]; then
        postgres_user_create $db_user $db_password;
        echo -e "${GREENC}Postgres user $db_user created${NC}";
    fi
}


# install_system_prerequirements
function install_system_prerequirements {
    echo "Updating package list..."
    with_sudo apt-get update || true;

    echo "Installing system preprequirements...";
    install_sys_deps_internal git wget python-setuptools python-pip \
        perl g++ libpq-dev python-dev expect-dev libevent-dev libjpeg-dev \
        libfreetype6-dev zlib1g-dev libxml2-dev libxslt-dev \
        libsasl2-dev libldap2-dev libssl-dev libffi-dev;

    if ! install_wkhtmltopdf; then
        echo "Cannot install wkhtmltopdf!!! Skipping...";
    fi

    with_sudo pip install --upgrade virtualenv cffi;
}


# Install virtual environment. All options will be passed directly to
# virtualenv command. one exception is DEST_DIR, which this script provides.
#
# install_virtual_env [opts]
function install_virtual_env {
    # To enable system site packages, just set env variable:
    #   VIRTUALENV_SYSTEM_SITE_PACKAGES=1
    if [ ! -z $VENV_DIR ] &&[ ! -d $VENV_DIR ]; then
        virtualenv $@ $VENV_DIR;
    fi
}

# install_python_prerequirements
function install_python_prerequirements {
    # required to make odoo.py work correctly when setuptools too old
    execu easy_install --upgrade setuptools;
    execu pip install --upgrade pip erppeek \
        setproctitle python-slugify watchdog pylint pylint-odoo coverage \
        flake8 flake8-colors setuptools-odoo cffi;

    if ! execv "python -c 'import pychart' >/dev/null 2>&1" ; then
        execv pip install http://download.gna.org/pychart/PyChart-1.39.tar.gz;
    fi

}

# Generate configuration file fo odoo
# this function looks into ODOO_CONF_OPTIONS environment variable,
# which should be associative array with options to be written to file
# install_generate_odoo_conf <file_path>
function install_generate_odoo_conf {
    local conf_file=$1;

    # default addonspath
    local addons_path="$ODOO_PATH/addons,$ADDONS_DIR";
    if [ -e "$ODOO_PATH/odoo/addons" ]; then
        addons_path="$ODOO_PATH/odoo/addons,$addons_path";
    elif [ -e "$ODOO_PATH/openerp/addons" ]; then
        addons_path="$ODOO_PATH/openerp/addons,$addons_path";
    fi

    # default values
    ODOO_CONF_OPTIONS[addons_path]="${ODOO_CONF_OPTIONS['addons_path']:-$addons_path}";
    ODOO_CONF_OPTIONS[admin_passwd]="${ODOO_CONF_OPTIONS['admin_passwd']:-admin}";
    ODOO_CONF_OPTIONS[data_dir]="${ODOO_CONF_OPTIONS['data_dir']:-$DATA_DIR}";
    ODOO_CONF_OPTIONS[logfile]="${ODOO_CONF_OPTIONS['logfile']:-$LOG_FILE}";
    ODOO_CONF_OPTIONS[pidfile]="${ODOO_CONF_OPTIONS['pidfile']:-$ODOO_PID_FILE}";
    ODOO_CONF_OPTIONS[db_host]="${ODOO_CONF_OPTIONS['db_host']:-False}";
    ODOO_CONF_OPTIONS[db_port]="${ODOO_CONF_OPTIONS['db_port']:-False}";
    ODOO_CONF_OPTIONS[db_user]="${ODOO_CONF_OPTIONS['db_user']:-odoo}";
    ODOO_CONF_OPTIONS[db_password]="${ODOO_CONF_OPTIONS['db_password']:-False}";

    local conf_file_data="[options]";
    for key in ${!ODOO_CONF_OPTIONS[@]}; do
        conf_file_data="$conf_file_data\n$key = ${ODOO_CONF_OPTIONS[$key]}";
    done

    echo -e "$conf_file_data" > $conf_file;
}


# Workaround for situation when setup does not install openerp-gevent script.
function odoo_gevent_install_workaround {
    if [ -f "$ODOO_PATH/openerp-gevent" ] && grep -q -e "scripts=\['openerp-server', 'odoo.py'\]," "$ODOO_PATH/setup.py";
    then
        echov -e "${YELLOWC}There is openerp-gevent in used in odoo, but it is not specified in setup.py${NC}"
        echov -e "${YELLOWC}Fix will be applied${NC}"
        cp $ODOO_PATH/setup.py $ODOO_PATH/setup.py.backup
        sed -i -r "s/scripts=\['openerp-server', 'odoo.py'\],/scripts=\['openerp-server', 'openerp-gevent', 'odoo.py'\],/" \
            $ODOO_PATH/setup.py;

        odoo_gevent_fix_applied=1;
    fi
}


function install_odoo_workaround_70 {
    # Fix odoo 7.0 setup tools dependencies, to limit their versions
    # because new versions have api changes, since odoo 7.0 released
    execv pip install 'vobject\<0.9.0' 'psutil\<2' 'reportlab\<=3.0';

    # Link libraries to virtualenv/lib dir
    local lib_dir=/usr/lib/$(uname -m)-linux-gnu;
    if [ ! -z $VENV_DIR ] && [ -f $lib_dir/libjpeg.so ] && [ ! -f $VENV_DIR/lib/libjpeg.so ]; then
        ln -s $lib_dir/libjpeg.so $VENV_DIR/lib;
    fi
    if [ ! -z $VENV_DIR ] && [ -f $lib_dir/libfreetype.so ] && [ ! -f $VENV_DIR/lib/libfreetype.so ]; then
        ln -s $lib_dir/libfreetype.so $VENV_DIR/lib;
    fi
    if [ ! -z $VENV_DIR ] && [ -f /usr/include/freetype2/fterrors.h ] && [ ! -d $VENV_DIR/include/freetype ]; then
        # For ubuntu 14.04
        ln -s /usr/include/freetype2 $VENV_DIR/include/freetype;
    fi
    if [ ! -z $VENV_DIR ] && [ -f $lib_dir/libz.so ] && [ ! -f $VENV_DIR/lib/libz.so ]; then
        ln -s $lib_dir/libz.so $VENV_DIR/lib;
    fi

    # Force use Pillow, because PIL is too old.
    execv pip install Pillow;
    cp $ODOO_PATH/setup.py $ODOO_PATH/setup.py.7.0.backup
    sed -i -r "s/PIL/Pillow/" $ODOO_PATH/setup.py;
    #execv pip install http://effbot.org/media/downloads/PIL-1.1.7.tar.gz;
}

function odoo_gevent_install_workaround_cleanup {
    if [ ! -z $odoo_gevent_fix_applied ]; then
        mv -f $ODOO_PATH/setup.py.backup $ODOO_PATH/setup.py
        unset odoo_gevent_fix_applied;
    fi
}


# odoo_run_setup_py [setup.py develop arguments]
function odoo_run_setup_py {
    # Workaround for situation when setup does not install openerp-gevent script.
    odoo_gevent_install_workaround;

    if [ "$ODOO_VERSION" == "7.0" ]; then
        install_odoo_workaround_70;
    fi

    # Install dependencies via pip (it is faster if they are cached)
    if [ -f "$ODOO_PATH/requirements.txt" ]; then
        # Based on http://stackoverflow.com/questions/22250483/stop-pip-from-failing-on-single-package-when-installing-with-requirements-txt
        # This is done to install as much deps as possible via pip. thus they are cached, and got correct versions
        # If some package could not be installed, show a warning with name of that package
		while read dependency; do
			dependency_stripped="$(echo "${dependency}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
			if [[ "$dependency_stripped" =~ pyparsing* ]]; then
                # Pyparsing is used by new versions of setuptools, so it is bad idea to update it,
                # especialy to versions lower than that used by setuptools
                continue
			else
                # Echo dependency line unchanged to rmp file
                echo $dependency;
			fi
		done < "$ODOO_PATH/requirements.txt" > /tmp/odoo_install_requirements.txt;
        execv pip install -r /tmp/odoo_install_requirements.txt;
    fi

    # Install odoo
    (cd $ODOO_PATH && execu python setup.py develop $@);

     
    # Workaround for situation when setup does not install openerp-gevent script.
    # (Restore modified setup.py)
    odoo_gevent_install_workaround_cleanup;
}


# Reinstall virtual environment.
function install_reinstall_venv {
    if [ -z $VENV_DIR ]; then
        echo -e "${YELLOWC}This project does not use virtualenv! Do nothing...${NC}";
        return 0;
    fi

    if [ "$1" == '--help' ] || [ "$1" == '-h' ]; then
        virtualenv --help;
        return 0
    fi

    # Backup old venv
    if [ -d $VENV_DIR ]; then
        mv $VENV_DIR $PROJECT_ROOT_DIR/venv_backup_$(random_string 4);
    fi

    install_virtual_env $@;
    install_python_prerequirements;
    odoo_run_setup_py;
}


# Entry point for install subcommand
function install_entry_point {
    local usage="Usage:

        $SCRIPT_NAME install pre-requirements [-y]         - install system preprequirements
        $SCRIPT_NAME install sys-deps [-y] <odoo-version>  - install system dependencies for odoo version
        $SCRIPT_NAME install postgres [user] [password]    - install postgres.
                                                             and if user/password specified, create it
        $SCRIPT_NAME install reinstall-venv [opts|--help]  - reinstall virtual environment (with python requirements and odoo).
                                                             all options will be passed to virtualenv cmd directly
        $SCRIPT_NAME install --help                        - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            pre-requirements)
                shift
                if [ "$1" == "-y" ]; then
                    ALWAYS_ANSWER_YES=1;
                    shift;
                fi
                install_system_prerequirements;
                exit 0;
            ;;
            sys-deps)
                shift;
                if [ "$1" == "-y" ]; then
                    ALWAYS_ANSWER_YES=1;
                    shift;
                fi
                install_sys_deps_for_odoo_version "$@";
                exit 0;
            ;;
            reinstall-venv)
                shift;
                load_project_conf;
                install_reinstall_venv "$@";
                exit 0;
            ;;
            postgres)
                shift;
                install_and_configure_postgresql "$@";
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
