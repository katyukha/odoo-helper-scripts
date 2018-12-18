# Copyright © 2015-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------
ohelper_require "config";
ohelper_require "postgres";
ohelper_require "odoo";


set -e; # fail on errors

DEFAULT_ODOO_REPO="https://github.com/odoo/odoo.git";

# Set-up defaul values for environment variables
function install_preconfigure_env {
    ODOO_REPO=${ODOO_REPO:-$DEFAULT_ODOO_REPO};
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
    local odoo_path=${ODOO_PATH};
    local odoo_branch=${ODOO_BRANCH};
    local odoo_repo=${ODOO_REPO:-$DEFAULT_ODOO_REPO};
    local branch_opt=;

    if [ ! -z $odoo_branch ]; then
        branch_opt="$branch_opt --branch $odoo_branch";
    fi

    if [ "$CLONE_SINGLE_BRANCH" == "on" ]; then
        branch_opt="$branch_opt --single-branch";
    fi

    git clone -q $branch_opt $odoo_repo $odoo_path;
}

# install_download_odoo
function install_download_odoo {
    local odoo_path=${ODOO_PATH};
    local odoo_branch=${ODOO_BRANCH};
    local odoo_repo=${ODOO_REPO:-$DEFAULT_ODOO_REPO};

    local odoo_archive=/tmp/odoo.$ODOO_BRANCH.tar.gz
    if [ -f $odoo_archive ]; then
        rm $odoo_archive;
    fi

    if [[ $ODOO_REPO == "https://github.com"* ]]; then
        local repo=${odoo_repo%.git};
        local repo_base=$(basename $repo);
        wget -q -T 2 -O $odoo_archive $repo/archive/$ODOO_BRANCH.tar.gz;
        tar -zxf $odoo_archive;
        mv ${repo_base}-${ODOO_BRANCH} $ODOO_PATH;
        rm $odoo_archive;
    else
        echoe -e "${REDC}ERROR${NC}: Cannot download Odoo. Download option supported only for github repositories!";
        return 1;
    fi
}


# fetch odoo source code clone|download
function install_fetch_odoo {
    local odoo_action=$1;

    if [ "$odoo_action" == 'clone' ]; then
        install_clone_odoo;
    elif [ "$odoo_action" == 'download' ]; then
        install_download_odoo;
    else
        echoe -e "${REDC}ERROR${NC}: *install_fetch_odoo* - unknown action '$odoo_action'!";
        return 1;
    fi
}

# get download link for wkhtmltopdf install
#
# install_wkhtmltopdf_get_dw_link <os_release_name> [wkhtmltopdf version]
function install_wkhtmltopdf_get_dw_link {
    local os_release_name=$1;
    local version=${2:-0.12.5};
    local system_arch=$(dpkg --print-architecture);

    echo "https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/$version/wkhtmltox_${version}-1.${os_release_name}_${system_arch}.deb"
}


# Download wkhtmltopdf to specified path
#
# install_wkhtmltopdf_download <path>
function install_wkhtmltopdf_download {
    local wkhtmltox_path=$1;
    local release=$(lsb_release -sc);
    local download_link=$(install_wkhtmltopdf_get_dw_link $release);

    if ! wget -q -T 2 $download_link -O $wkhtmltox_path; then
        local old_release=$release;

        if [ "$(lsb_release -si)" == "Ubuntu" ]; then
            # fallback to trusty release for ubuntu systems
            local release=bionic;
        elif [ "$(lsb_release -si)" == "Debian" ]; then
            local release=stretch;
        else
            echoe -e "${REDC}ERROR:${NC} Cannot install ${BLUEC}wkhtmltopdf${NC}! Not supported OS";
            return 2;
        fi

        echoe -e "${YELLOWC}WARNING${NC}: Cannot find wkhtmltopdf for ${BLUEC}${old_release}${NC}. trying to install fallback for ${BLUEC}${release}${NC}.";
        local download_link=$(install_wkhtmltopdf_get_dw_link $release);
        if ! wget -q -T 2 $download_link -O $wkhtmltox_path; then
            echoe -e "${REDC}ERROR:${NC} Cannot install ${BLUEC}wkhtmltopdf${NC}! cannot download package $download_link";
            return 1;
        fi
    fi
}

# install_wkhtmltopdf
function install_wkhtmltopdf {
    local usage="
    Install wkhtmltopdf. It is required to print PDF reports.


    Usage:

        $SCRIPT_NAME install wkhtmltopdf [options]
        $SCRIPT_NAME install wkhtmltopdf --help - show this help message

    Options:

        --update   - install even if it is already installed
    ";

    local force_install;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            --update)
                force_install=1;
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echo -e "${REDC}ERROR${NC}: Unknown command $key";
                return 1;
            ;;
        esac
        shift
    done
    if ! check_command wkhtmltopdf > /dev/null || [ -n "$force_install" ]; then
        # if wkhtmltox is not installed yet
        local wkhtmltox_path=${DOWNLOADS_DIR:-/tmp}/wkhtmltox.deb;
        if [ ! -f $wkhtmltox_path ]; then
            echoe -e "${BLUEC}Downloading ${YELLOWC}wkhtmltopdf${BLUEC}...${NC}";
            install_wkhtmltopdf_download $wkhtmltox_path;
        fi
        echoe -e "${BLUEC}Installing ${YELLOWC}wkhtmltopdf${BLUEC}...${NC}";
        local wkhtmltox_deps=$(dpkg -f $wkhtmltox_path Depends | sed -r 's/,//g');
        if ! (install_sys_deps_internal $wkhtmltox_deps && with_sudo dpkg -i $wkhtmltox_path); then
            echoe -e "${REDC}ERROR:${NC} Error caught while installing ${BLUEC}wkhtmltopdf${NC}.";
        fi

        rm $wkhtmltox_path || true;  # try to remove downloaded file, ignore errors

        echoe -e "${GREENC}OK${NC}:${YELLOWC}wkhtmltopdf${NC} installed successfully!";
    else
        echoe -e "${GREENC}OK${NC}:${YELLOWC}wkhtmltopdf${NC} seems to be installed!";
    fi
}


# install_sys_deps_internal dep_1 dep_2 ... dep_n
function install_sys_deps_internal {
    # Odoo's debian/control file usualy contains this in 'Depends' section 
    # so we need to skip it before running apt-get
    echoe -e "${BLUEC}Installing system dependencies${NC}: $@";
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-yq";
    fi
    with_sudo apt-get install $opt_apt_always_yes --no-install-recommends "$@";
}

# install_parse_debian_control_file <control file>
# parse debian control file to fetch odoo dependencies
function install_parse_debian_control_file {
    local file_path=$1;
    local sys_deps=;

    local python_cmd="import re; RE_DEPS=re.compile(r'.*Depends:(?P<deps>(\n [^,]+,)+).*', re.MULTILINE | re.DOTALL);";
    python_cmd="$python_cmd m = RE_DEPS.match(open('$file_path').read());";
    python_cmd="$python_cmd deps = m and m.groupdict().get('deps', '');";
    python_cmd="$python_cmd deps = deps.replace(',', '').replace(' ', '').split('\n');";
    python_cmd="$python_cmd print('\n'.join(filter(lambda l: l and not l.startswith('\\\${'), deps)))";

    local sys_deps_raw=$(run_python_cmd "$python_cmd");

    # Preprocess odoo dependencies
    # TODO: create list of packages that should not be installed via apt
    for dep in $sys_deps_raw; do
        case $dep in
            '${misc:Depends}')
                continue
            ;;
            '${python3:Depends}')
                continue
            ;;
            \$\{*)
                # Skip dependencies stared with ${
                continue
            ;;
            node-less)
                # Will be installed into virtual env via node-env
                continue
            ;;
            python-pypdf|python-pypdf2|python3-pypdf2)
                # Will be installed by pip from requirements.txt
                continue
            ;;
            python-pybabel|python-babel|python-babel-localedata|python3-babel)
                # Will be installed by setup.py or pip
                continue
            ;;
            python-feedparser|python3-feedparser)
                # Seems to be pure-python dependency
                continue
            ;;
            python-requests|python3-requests)
                # Seems to be pure-python dependency
                continue
            ;;
            python-urllib3)
                # Seems to be pure-python dependency
                continue
            ;;
            python-vobject|python3-vobject)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-decorator|python3-decorator)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-pydot|python3-pydot)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-mock|python3-mock)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-pyparsing|python3-pyparsing)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-vatnumber|python3-vatnumber)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-yaml|python3-yaml)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-xlwt|python3-xlwt)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-dateutil|python3-dateutil)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-openid|python3-openid)
                # Will be installed by setup.py or requirements
                continue
            ;;
            python-mako|python-jinja2|python3-mako|python3-jinja2)
                # Will be installed by setup.py or requirements
                continue
            ;;
            #-----
            python-lxml|python-libxml2|python-imaging|python-psycopg2|python-docutils|python-ldap|python-passlib|python-psutil)
                continue
            ;;
            python3-lxml|python3-pil|python3-psycopg2|python3-docutils|python3-ldap|python3-passlib|python3-psutil)
                continue
            ;;
            python-six|python-pychart|python-reportlab|python-tz|python-werkzeug|python-suds|python-xlsxwriter)
                continue
            ;;
            python3-six|python3-pychart|python3-reportlab|python3-tz|python3-werkzeug|python3-suds|python3-xlsxwriter|python3-html2text|python3-chardet|python3-libsass)
                continue
            ;;
            python-libxslt1|python-simplejson|python-unittest2)
                continue
            ;;
            *)
            sys_deps="$sys_deps $dep";
        esac;

    done

    echo "$sys_deps";
}

# install_sys_deps_for_odoo_version <odoo version>
# Note that odoo version here is branch of official odoo repository
function install_sys_deps_for_odoo_version {
    local usage="
    Install system dependencies for specific Odoo version.

    Usage:

        $SCRIPT_NAME install sys-deps [options] <odoo-version> - install deps
        $SCRIPT_NAME install sys-deps --help                   - show help msg

    Options:

        -y|--yes     - Always answer yes

    ";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -y|--yes)
                ALWAYS_ANSWER_YES=1;
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

    local odoo_version=$1;
    if [ -z "$odoo_version" ]; then
        echoe -e "${REDC}ERROR${NC}: Odoo version is not specified!";
        return 1;
    fi

    local control_url="https://raw.githubusercontent.com/odoo/odoo/$odoo_version/debian/control";
    local tmp_control=$(mktemp);
    wget -q -T 2 $control_url -O $tmp_control;
    local sys_deps=$(ODOO_VERSION=$odoo_version install_parse_debian_control_file $tmp_control);
    install_sys_deps_internal $sys_deps;
    rm $tmp_control;
}

# install python requirements for specified odoo version via PIP requirements.txt
# NOTE: not supported for odoo 7.0 and lower.
function install_odoo_py_requirements_for_version {
    local usage="
    Install python dependencies for specific Odoo version.

    Usage:

        $SCRIPT_NAME install py-deps <odoo-version> - install python dependencies
        $SCRIPT_NAME install py-deps --help         - show this help message

    ";
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

    local odoo_version=${1:-$ODOO_VERSION};
    local odoo_major_version="${odoo_version%.*}";
    local requirements_url="https://raw.githubusercontent.com/odoo/odoo/$odoo_version/requirements.txt";
    local tmp_requirements=$(mktemp);
    local tmp_requirements_post=$(mktemp);
    if wget -q -T 2 "$requirements_url" -O "$tmp_requirements"; then
        # Preprocess requirements to avoid known bugs
        while read dependency; do
            dependency_stripped="$(echo "${dependency}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [[ "$dependency_stripped" =~ pyparsing* ]]; then
                # Pyparsing is used by new versions of setuptools, so it is bad idea to update it,
                # especialy to versions lower than that used by setuptools
                continue
            elif [[ "$dependency_stripped" =~ pychart* ]]; then
                # Pychart is not downloadable. Use Python-Chart package
                echo "Python-Chart";
            elif [ "$odoo_major_version" -lt 10 ] && [[ "$dependency_stripped" =~ gevent* ]]; then
                # Install last gevent, because old gevent versions (ex. 1.0.2)
                # cause build errors.
                # Instead last gevent (1.1.0+) have already prebuild wheels.
                # Note that gevent (1.3.1) may break odoo 10.0, 11.0
                # and in Odoo 10.0, 11.0 working version of gevent is placed in requirements
                echo "gevent==1.1.0";
            elif [ "$odoo_major_version" -lt 10 ] && [[ "$dependency_stripped" =~ greenlet* ]]; then
                # Install correct version of greenlet for for gevent.
                echo "greenlet==0.4.9";
            else
                # Echo dependency line unchanged to rmp file
                echo $dependency;
            fi
        done < "$tmp_requirements" > "$tmp_requirements_post";
        exec_pip -q install -r "$tmp_requirements_post";
    fi

    if [ -f "$tmp_requirements" ]; then
        rm $tmp_requirements;
    fi

    if [ -f "$tmp_requirements_post" ]; then
        rm $tmp_requirements_post;
    fi
}

function install_and_configure_postgresql {
    local usage="
    Install postgresql server and optionaly automatically create postgres user
    for this Odoo instance.

    Usage:

        Install postgresql only:
            $SCRIPT_NAME install postgres                   

        Install postgresql and create postgres user:
            $SCRIPT_NAME install postgres <user> <password>

    ";
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
    local db_user=${1:-$DB_USER};
    local db_password=${2:-DB_PASSWORD};
    # Check if postgres is installed on this machine. If not, install it
    if ! postgres_is_installed; then
        postgres_install_postgresql;
        echo -e "${GREENC}Postgres installed${NC}";
    else
        echo -e "${YELLOWC}It seems that postgresql is already installed... Skipping this step...${NC}";
    fi

    if [ ! -z $db_user ] && [ ! -z $db_password ]; then
        postgres_user_create $db_user $db_password;
    fi
}


# install_system_prerequirements
function install_system_prerequirements {
    local usage="
    Install system dependencies for odoo-helper-scripts itself and
    common dependencies for Odoo.

    Usage:

        $SCRIPT_NAME install pre-requirements [options]  - install requirements
        $SCRIPT_NAME install pre-requirements --help     - show this help message

    Options:

        -y|--yes     - Always answer yes

    ";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -y|--yes)
                ALWAYS_ANSWER_YES=1;
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

    echoe -e "${BLUEC}Updating package list...${NC}"
    with_sudo apt-get update -qq || true;

    echoe -e "${BLUEC}Installing system preprequirements...${NC}";
    install_sys_deps_internal git wget lsb-release procps \
        python-setuptools libevent-dev g++ libpq-dev libsass-dev \
        python-dev python3-dev libjpeg-dev libyaml-dev \
        libfreetype6-dev zlib1g-dev libxml2-dev libxslt-dev bzip2 \
        libsasl2-dev libldap2-dev libssl-dev libffi-dev fontconfig;

    if ! install_wkhtmltopdf; then
        echoe -e "${YELLOWC}WARNING:${NC} Cannot install ${BLUEC}wkhtmltopdf${NC}!!! Skipping...";
    fi

    with_sudo python -m easy_install 'virtualenv>=15.1.0';
}

# Install virtual environment. All options will be passed directly to
# virtualenv command. one exception is DEST_DIR, which this script provides.
#
# install_virtual_env [opts]
function install_virtual_env {
    if [ ! -z $VENV_DIR ] && [ ! -d $VENV_DIR ]; then
        if [ -z $VIRTUALENV_PYTHON ]; then
            VIRTUALENV_PYTHON=$(odoo_get_python_version) virtualenv $@ $VENV_DIR;
        else
            VIRTUALENV_PYTHON=$VIRTUALENV_PYTHON virtualenv $@ $VENV_DIR;
        fi
        exec_pip -q install nodeenv;
        execv nodeenv --python-virtualenv;  # Install node environment

        exec_npm set user 0;
        exec_npm set unsafe-perm true;
    fi
}

# Install bin tools
#
# At this moment just installs expect-dev package, that provides 'unbuffer' tool
function install_bin_tools {
    local usage="
    Install extra tools.
    This command installs expect-dev package that brings 'unbuffer' program.
    'unbuffer' program allow to run command without buffering.
    This is required to make odoo show collors in log.

    Usage:

        $SCRIPT_NAME install bin-tools [options]  - install extra tools
        $SCRIPT_NAME install bin-tools --help     - show this help message

    Options:

        -y|--yes     - Always answer yes

    ";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -y|--yes)
                ALWAYS_ANSWER_YES=1;
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
    local deps="expect-dev tcl8.6";
    if ! check_command 'google-chrome' 'chromium' 'chromium-browser' > /dev/null; then
        echoe -e "${YELLOWC}Google Chrome${BLUEC} seems to be not installed. ${YELLOWC}chromium-browser${BLUEC} will be installed.${NC}";
        deps="$deps chromium-browser";
    fi
    install_sys_deps_internal $deps;
}

# Install extra python tools
function install_python_tools {
    local usage="
    Install extra python tools.

    Following packages will be installed:

        - setproctitle
        - watchdog
        - pylint-odoo
        - coverage
        - flake8
        - flake8-colors
        - websocket-client  (required for tests in Odoo 12.0)

    Usage:

        $SCRIPT_NAME install py-tools [options]  - install extra tools
        $SCRIPT_NAME install py-tools --help     - show this help message

    Options:

        -q|--quiet     - quiet mode. reduce output

    ";
    local pip_options;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -q|--quiet)
                pip_options="$pip_options --quiet"
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
    exec_pip $pip_options install setproctitle watchdog pylint-odoo coverage \
        flake8 flake8-colors websocket-client;
}

# Install extra javascript tools
function install_js_tools {
    local usage="
    Install extra javascript tools.

    Following packages will be installed:

        - eslint
        - phantomjs-prebuilt
        - stylelint
        - stylelint-config-standard

    Usage:

        $SCRIPT_NAME install js-tools        - install extra tools
        $SCRIPT_NAME install js-tools --help - show this help message

    ";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
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
    exec_npm install -g eslint phantomjs-prebuilt \
        stylelint stylelint-config-standard;
}

# install_python_prerequirements
function install_python_prerequirements {
    # virtualenv >= 15.1.0 automaticaly installs last versions of pip and
    # setuptools, so we do not need to upgrade them
    exec_pip -q install phonenumbers python-slugify setuptools-odoo cffi jinja2;

    if ! run_python_cmd "import pychart" >/dev/null 2>&1 ; then
        exec_pip -q install Python-Chart;
    fi
}

# Install javascript pre-requirements.
# Now it is less compiler. install if it is not installed yet
function install_js_prerequirements {
    if ! check_command lessc > /dev/null; then
        execu npm install -g less;
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

    # Installing requirements via pip. This should improve performance
    exec_pip -q install -r $ODOO_HELPER_LIB/data/odoo_70_requirements.txt;

    # Force use Pillow, because PIL is too old.
    cp $ODOO_PATH/setup.py $ODOO_PATH/setup.py.7.0.backup
    sed -i -r "s/PIL/Pillow/" $ODOO_PATH/setup.py;
    sed -i -r "s/pychart/Python-Chart/" $ODOO_PATH/setup.py;
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
        echoe -e "${YELLOWC}WARNING${NC}: Support of Odoo 7.0 now is deprecated and will be removed in one of next releases";
        install_odoo_workaround_70;
    fi

    # Install dependencies via pip (it is faster if they are cached)
    install_odoo_py_requirements_for_version;

    # Install odoo
    (cd $ODOO_PATH && exec_py setup.py -q develop $@);

     
    # Workaround for situation when setup does not install openerp-gevent script.
    # (Restore modified setup.py)
    odoo_gevent_install_workaround_cleanup;
}


# Install odoo intself.
# Require that odoo is downloaded and directory tree structure created
function install_odoo_install {
    # Install virtual environment
    echoe -e "${BLUEC}Installing virtualenv...${NC}";
    install_virtual_env;

    # Install python requirements
    echoe -e "${BLUEC}Installing python pre-requirements...${NC}";
    install_python_prerequirements;

    # Install js requirements
    echoe -e "${BLUEC}Installing js pre-requirements...${NC}";
    install_js_prerequirements;

    # Run setup.py with gevent workaround applied.
    echoe -e "${BLUEC}Installing odoo...${NC}";
    odoo_run_setup_py;  # imported from 'install' module
}


# Reinstall virtual environment.
function install_reinstall_venv {
    local usage="
    Recreate virtualenv environment.

    Usage:

        $SCRIPT_NAME install reinstall-venv [options] - reinstall virtualenv
        $SCRIPT_NAME install reinstall-venv --help    - show this help message

    Options:

        -p|--python <python ver>  - python version to recreate virtualenv with.
                                    Same as --python option of virtualenv
    ";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -p|--python)
                VIRTUALENV_PYTHON="$2";
                shift;
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

    if [ -z "$VENV_DIR" ]; then
        echo -e "${YELLOWC}This project does not use virtualenv! Do nothing...${NC}";
        return 0;
    fi

    # Backup old venv
    if [ -d "$VENV_DIR" ]; then
        local venv_backup_path="$PROJECT_ROOT_DIR/venv-backup-$(random_string 4)";
        mv "$VENV_DIR" "$venv_backup_path";
        echoe -e "${BLUEC}Old ${YELLOWC}virtualenv${BLUEC} backed up at ${YELLOWC}${venv_backup_path}${NC}";
    fi

    # Install odoo
    install_odoo_install;

    # Update python dependencies for addons
    addons_update_py_deps;
}

function install_reinstall_odoo {
    local usage="
    Reinstall odoo. Usualy used when initialy odoo was installed as archive,
    but we want to reinstall it as git repository to better track updates.

    Usage:

        $SCRIPT_NAME install reinstall-odoo <type> - reinstall odoo
        $SCRIPT_NAME install reinstall-odoo --help - show this help message

    <type> could be:
        clone     - reinstall Odoo as git repository.
        download  - reinstall Odoo from archive.
    ";

    local reinstall_action;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            clone|git)
                reinstall_action="clone";
            ;;
            download|archive)
                reinstall_action="download";
            ;;
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echo -e "${REDC}ERROR${NC}: Unknown command $key";
                return 1;
            ;;
        esac
        shift
    done
    if [ -z "$reinstall_action" ]; then
        echo -e "${REDC}ERROR${NC}: Please specify reinstall type!";
        echo "";
        echo "$usage";
        return 1;
    fi

    if [ -d $ODOO_PATH ]; then
        mv $ODOO_PATH $ODOO_PATH-backup-$(random_string 4);
    fi

    install_fetch_odoo $reinstall_action;
    install_reinstall_venv;
}


# Entry point for install subcommand
function install_entry_point {
    local usage="
    Usage:

        $SCRIPT_NAME install pre-requirements [--help]   - [sudo] install system pre-requirements
        $SCRIPT_NAME install sys-deps [--help]           - [sudo] install system dependencies for odoo version
        $SCRIPT_NAME install py-deps [--help]            - install python dependencies for odoo version (requirements.txt)
        $SCRIPT_NAME install py-tools [--help]           - install python tools (pylint, flake8, ...)
        $SCRIPT_NAME install js-tools [--help]           - install javascript tools (jshint, phantomjs)
        $SCRIPT_NAME install bin-tools [--help]          - [sudo] install binary tools. at this moment it is *unbuffer*,
                                                           which is in *expect-dev* package
        $SCRIPT_NAME install wkhtmltopdf                 - [sudo] install wkhtmtopdf
        $SCRIPT_NAME install postgres [user] [password]  - [sudo] install postgres.
                                                           and if user/password specified, create it
        $SCRIPT_NAME install reinstall-venv [--help]     - reinstall virtual environment
        $SCRIPT_NAME install reinstall-odoo [--help]     - completly reinstall odoo
                                                           (downlload or clone new sources, create new virtualenv, etc).
                                                           Options are:
                                                              - clone odoo as git repository
                                                              - download odoo archieve and unpack source
        $SCRIPT_NAME install --help                      - show this help message

    ";

    if [[ $# -lt 1 ]]; then
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            pre-requirements)
                shift
                install_system_prerequirements $@;
                return 0;
            ;;
            sys-deps)
                shift;
                install_sys_deps_for_odoo_version "$@";
                return 0;
            ;;
            py-deps)
                shift;
                config_load_project;
                install_odoo_py_requirements_for_version $@;
                return 0;
            ;;
            py-tools)
                shift;
                config_load_project;
                install_python_tools $@;
                return 0;
            ;;
            js-tools)
                shift;
                config_load_project;
                install_js_tools $@;
                return 0;
            ;;
            bin-tools)
                shift;
                install_bin_tools $@;
                return 0;
            ;;
            wkhtmltopdf)
                shift;
                install_wkhtmltopdf $@;
                return
            ;;
            reinstall-venv)
                shift;
                config_load_project;
                install_reinstall_venv "$@";
                return 0;
            ;;
            reinstall-odoo)
                shift;
                config_load_project;
                install_reinstall_odoo $@;
                return 0;
            ;;
            postgres)
                shift;
                install_and_configure_postgresql "$@";
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
