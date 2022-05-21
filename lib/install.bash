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

# ----------------------------------------------------------------------------------------
ohelper_require "config";
ohelper_require "postgres";
ohelper_require "odoo";
ohelper_require "addons";


set -e; # fail on errors

DEFAULT_ODOO_REPO="https://github.com/odoo/odoo.git";

# Set-up defaul values for environment variables
function install_preconfigure_env {
    ODOO_REPO=${ODOO_REPO:-$DEFAULT_ODOO_REPO};
    ODOO_VERSION=${ODOO_VERSION:-12.0};
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
    create_dirs "$PROJECT_ROOT_DIR" \
        "$ADDONS_DIR" \
        "$CONF_DIR" \
        "$LOG_DIR" \
        "$LIBS_DIR" \
        "$DOWNLOADS_DIR" \
        "$BACKUP_DIR" \
        "$REPOSITORIES_DIR" \
        "$BIN_DIR" \
        "$DATA_DIR";
}

# install_clone_odoo [path [branch [repo]]]
function install_clone_odoo {
    local git_opt=( );

    if [ -n "$ODOO_BRANCH" ]; then
        git_opt+=( --branch "$ODOO_BRANCH" );
    fi

    if [ "$CLONE_SINGLE_BRANCH" == "on" ]; then
        git_opt+=( --single-branch );
    fi

    git clone -q "${git_opt[@]}" \
        "${ODOO_REPO:-$DEFAULT_ODOO_REPO}" \
        "$ODOO_PATH";
}

# install_download_odoo
function install_download_odoo {
    local clone_odoo_repo=${ODOO_REPO:-$DEFAULT_ODOO_REPO};

    local odoo_archive=/tmp/odoo.$ODOO_BRANCH.tar.gz
    if [ -f "$odoo_archive" ]; then
        rm "$odoo_archive";
    fi

    if [[ "$ODOO_REPO" == "https://github.com"* ]]; then
        local repo=${clone_odoo_repo%.git};
        local repo_base;
        repo_base=$(basename "$repo");
        echov -e "${LBLUEC}Downloading from ${YELLOWC}${repo}/archive/${ODOO_BRANCH}.tar.gz${NC}";
        if ! wget -q -T 15 -O "$odoo_archive" "$repo/archive/$ODOO_BRANCH.tar.gz"; then
            echoe -e "${REDC}ERROR${NC}: Cannot download Odoo from ${YELLOWC}${repo}/archive/${ODOO_BRANCH}.tar.gz${NC}."
            echoe -e "Remove broken download (if it is exists) ${YELLOWC}${odoo_archive}${NC}."
            echoe -e "and try to run command below: ";
            echoe -e "    ${BLUEC}wget --debug -T 15 -O \"$odoo_archive\" \"$repo/archive/$ODOO_BRANCH.tar.gz\"${NC}"
            echoe  -e "and analyze its output";
            return 2;
        fi
        if ! tar -zxf "$odoo_archive"; then
            echoe -e "${REDC}ERROR${NC}: Cannot unpack downloaded archive ${YELLOWC}${odoo_archive}${NC}."
            return 3;
        fi
        mv "${repo_base}-${ODOO_BRANCH}" "$ODOO_PATH";
        rm "$odoo_archive";
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
    local system_arch;
    system_arch=$(dpkg --print-architecture);

    echo "https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/$version/wkhtmltox_${version}-1.${os_release_name}_${system_arch}.deb"
}


# Download wkhtmltopdf to specified path
#
# install_wkhtmltopdf_download <path>
function install_wkhtmltopdf_download {
    local wkhtmltox_path=$1;
    local release;
    local download_link;
    release=$(lsb_release -sc);
    download_link=$(install_wkhtmltopdf_get_dw_link "$release");

    if ! wget -q -T 15 "$download_link" -O "$wkhtmltox_path"; then
        local old_release=$release;

        if [ "$(lsb_release -si)" == "Ubuntu" ]; then
            # fallback to trusty release for ubuntu systems
            release=bionic;
        elif [ "$(lsb_release -si)" == "Debian" ]; then
            release=stretch;
        else
            echoe -e "${REDC}ERROR:${NC} Cannot install ${BLUEC}wkhtmltopdf${NC}! Not supported OS";
            return 2;
        fi

        echoe -e "${YELLOWC}WARNING${NC}: Cannot find wkhtmltopdf for ${BLUEC}${old_release}${NC}. trying to install fallback for ${BLUEC}${release}${NC}.";
        download_link=$(install_wkhtmltopdf_get_dw_link "$release");
        if ! wget -q -T 15 "$download_link" -O "$wkhtmltox_path"; then
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

    Options:

        --update   - install even if it is already installed
        --help     - show this help message
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
        if [ ! -f "$wkhtmltox_path" ]; then
            echoe -e "${BLUEC}Downloading ${YELLOWC}wkhtmltopdf${BLUEC}...${NC}";
            install_wkhtmltopdf_download "$wkhtmltox_path";
        fi
        echoe -e "${BLUEC}Installing ${YELLOWC}wkhtmltopdf${BLUEC}...${NC}";
        local wkhtmltox_deps;
        read -ra wkhtmltox_deps < <(dpkg -f "$wkhtmltox_path" Depends | sed -r 's/,//g');
        if ! (install_sys_deps_internal "${wkhtmltox_deps[@]}" && with_sudo dpkg -i "$wkhtmltox_path"); then
            echoe -e "${REDC}ERROR:${NC} Error caught while installing ${BLUEC}wkhtmltopdf${NC}.";
        fi

        rm "$wkhtmltox_path" || true;  # try to remove downloaded file, ignore errors

        echoe -e "${GREENC}OK${NC}:${YELLOWC}wkhtmltopdf${NC} installed successfully!";
    else
        echoe -e "${GREENC}OK${NC}:${YELLOWC}wkhtmltopdf${NC} seems to be installed!";
    fi
}


# install_sys_deps_internal dep_1 dep_2 ... dep_n
function install_sys_deps_internal {
    # Odoo's debian/control file usualy contains this in 'Depends' section 
    # so we need to skip it before running apt-get
    echoe -e "${BLUEC}Installing system dependencies${NC}: $*";
    if [ -n "$ALWAYS_ANSWER_YES" ]; then
        local opt_apt_always_yes="-yq";
    fi
    with_sudo apt-get install $opt_apt_always_yes --no-install-recommends "$@";
}

# install_parse_debian_control_file <control file>
# parse debian control file to fetch odoo dependencies
function install_parse_debian_control_file {
    local file_path=$1;
    local sys_deps_raw=( );

    mapfile -t sys_deps_raw < <(exec_py_utils install-parse-deb-deps --path="$file_path");

    # Preprocess odoo dependencies
    # TODO: create list of packages that should not be installed via apt
    for dep in "${sys_deps_raw[@]}"; do
        # shellcheck disable=SC2016
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
            python3-six|python3-pychart|python3-reportlab|python3-tz|python3-werkzeug|python3-suds|python3-xlsxwriter|python3-html2text|python3-chardet|python3-libsass|python3-polib|python3-qrcode|python3-xlrd|python3-zeep|python3-ofxparse|python3-freezegun|python3-stdnum|python3-num2words)
                continue
            ;;
            python-libxslt1|python-simplejson|python-unittest2|python-zeep)
                continue
            ;;
            *)
                echo "$dep";
        esac;
    done
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

        -y|--yes              - Always answer yes
        -b|--branch <branch>  - Odoo branch to fetch deps for

    ";
    local odoo_branch;
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -y|--yes)
                ALWAYS_ANSWER_YES=1;
            ;;
            -b|--branch)
                odoo_branch="$2";
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

    local odoo_version=$1;
    if [ -z "$odoo_version" ]; then
        echoe -e "${REDC}ERROR${NC}: Odoo version is not specified!";
        return 1;
    fi

    odoo_branch=${odoo_branch:-$odoo_version};
    local control_url="https://raw.githubusercontent.com/odoo/odoo/$odoo_branch/debian/control";
    local tmp_control;
    tmp_control=$(mktemp);
    wget -q -T 15 "$control_url" -O "$tmp_control";
    local sys_deps;
    mapfile -t sys_deps < <(ODOO_VERSION="$odoo_version" install_parse_debian_control_file "$tmp_control");
    install_sys_deps_internal "${sys_deps[@]}";
    rm "$tmp_control";
}

# install python requirements for specified odoo version via PIP requirements.txt
function install_odoo_py_requirements_for_version {
    local usage="
    Install python dependencies for specific Odoo version.

    Usage:

        $SCRIPT_NAME install py-deps [options] [odoo-version] - install python dependencies
        $SCRIPT_NAME install py-deps --help         - show this help message

    Options:
        -b|--branch <branch>   - Odoo branch to install deps for

    ";
    local odoo_branch=${ODOO_BRANCH};
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -b|--branch)
                odoo_branch="$2";
                shift;
            ;;
            *)
                break;
            ;;
        esac
        shift
    done

    local odoo_version=${1:-$ODOO_VERSION};
    local odoo_major_version="${odoo_version%.*}";
    odoo_branch=${odoo_branch:-$odoo_version};
    local requirements_url="https://raw.githubusercontent.com/odoo/odoo/$odoo_branch/requirements.txt";
    local tmp_requirements;
    local tmp_requirements_post;
    tmp_requirements=$(mktemp);
    tmp_requirements_post=$(mktemp);
    if wget -q -T 15 "$requirements_url" -O "$tmp_requirements"; then
        # Preprocess requirements to avoid known bugs
        while read -r dependency || [[ -n "$dependency" ]]; do
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
            elif [ "$odoo_major_version" -ge 10 ] && [[ "$dependency_stripped" =~ gevent* ]]; then
                # Starting from Odoo 11 python 3 is used. choose correct gevent  version
                # for python installed in system
                if exec_py -c "import sys; assert (3, 4) <= sys.version_info < (3, 6);" > /dev/null 2>&1; then
                    echo "gevent==1.1.2";
                elif exec_py -c "import sys; assert (3, 5) <= sys.version_info < (3, 7);" > /dev/null 2>&1; then
                    echo "gevent==1.3.4";
                elif exec_py -c "import sys; assert (3, 7) <= sys.version_info < (3, 9);" > /dev/null 2>&1; then
                    echo "gevent==1.5.0";
                elif exec_py -c "import sys; assert sys.version_info >= (3, 9);" > /dev/null 2>&1; then
                    echo "gevent>=20.6.0";
                else
                    echo "$dependency";
                fi
            elif [ "$odoo_major_version" -lt 10 ] && [[ "$dependency_stripped" =~ greenlet* ]]; then
                echo "greenlet==0.4.9";
            elif [ "$odoo_major_version" -ge 10 ] && [[ "$dependency_stripped" =~ greenlet* ]]; then
                # Set correct version of greenlet for gevent 1.5.0
                if exec_py -c "import sys; assert (3, 5) <= sys.version_info < (3, 9);" > /dev/null 2>&1; then
                    echo "greenlet==0.4.14";
                elif exec_py -c "import sys; assert sys.version_info >= (3, 9);" > /dev/null 2>&1; then
                    echo "greenlet==0.4.16";
                else
                    echo "$dependency";
                fi
            elif [ "$odoo_major_version" -lt 11 ] && [[ "$dependency_stripped" =~ psycopg2* ]]; then
                echo "psycopg2==2.7.3.1";
            elif [[ "$dependency_stripped" =~ psycopg2* ]] && exec_py -c "import sys; assert sys.version_info <= (3, 5);" > /dev/null 2>&1; then
                echo "psycopg2-binary==2.8.6";
            elif [[ "$dependency_stripped" =~ psycopg2* ]]; then
                echo "psycopg2-binary";
            elif [ "$odoo_major_version" -lt 11 ] && [[ "$dependency_stripped" =~ lxml ]]; then
                echo "lxml==3.7.1";
            elif [ "$odoo_major_version" -ge 11 ] && [[ "$dependency_stripped" =~ lxml ]] && exec_py -c "import sys; assert sys.version_info >= (3, 9);" > /dev/null 2>&1; then
                echo "lxml";
            elif [ "$odoo_major_version" -eq 11 ] && [[ "$dependency_stripped" =~ PyYAML ]] && exec_py -c "import sys; assert sys.version_info >= (3, 9);" > /dev/null 2>&1; then
                # Download latst version for python 3.9 and odoo 11.0
                echo "PyYAML";
            elif [[ "$dependency_stripped" =~ reportlab ]] && exec_py -c "import sys; assert sys.version_info >= (3, 9);" > /dev/null 2>&1; then
                # In case of python 3.9 latest version of reportlab have to be used
                echo "reportlab";
            elif [ "$odoo_major_version" -gt 10 ] && [[ "$dependency_stripped" =~ feedparser ]]; then
                # Recent versions of setup tools do not support `use_2to3` flag,so,
                # we have to use last version of feedparser to avoid errors during install
                echo "feedparser";
            elif [ "$odoo_major_version" -gt 10 ] && [[ "$dependency_stripped" =~ suds-jurko ]]; then
                # Recent versions of setup tools do not support `use_2to3` flag,so,
                # we have to use another fork of suds to avoid errors during install
                echo "suds-py3";
            else
                # Echo dependency line unchanged to rmp file
                echo "$dependency";
            fi
        done < "$tmp_requirements" > "$tmp_requirements_post";
        if ! exec_pip install -r "$tmp_requirements_post"; then
            echoe -e "${REDC}ERROR${NC}: Cannot install python dependencies.\n$(cat "$tmp_requirements_post")";
            return 1;
        fi
    else
        echoe -e "${REDC}ERROR${NC}: Cannot fetch python requirements for Odoo.";
    fi

    if [ -f "$tmp_requirements" ]; then
        rm "$tmp_requirements";
    fi

    if [ -f "$tmp_requirements_post" ]; then
        rm "$tmp_requirements_post";
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

    if [ -n "$db_user" ] && [ -n "$db_password" ]; then
        postgres_user_create "$db_user" "$db_password";
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
    install_sys_deps_internal git wget lsb-release \
        procps libevent-dev g++ libpq-dev libsass-dev \
        python3-dev libjpeg-dev libyaml-dev \
        libfreetype6-dev zlib1g-dev libxml2-dev libxslt-dev bzip2 \
        libsasl2-dev libldap2-dev libssl-dev libffi-dev fontconfig \
        libmagic1;

    echo -e "${BLUEC}Installing python2 dependencies (to support odoo 10 and below)...${NC}";
    if ! install_sys_deps_internal python2-dev; then
        echo -e "${YELLOWC}WARNING${NC}: It seems that it is too old version of OS, trying old version of python2 support...";
        if ! install_sys_deps_internal python-dev; then
            echo -e "${YELLOWC}WARNING${NC}: Cannot install python2 support... skipping...";
        fi
    fi
    if ! install_wkhtmltopdf; then
        echoe -e "${YELLOWC}WARNING:${NC} Cannot install ${BLUEC}wkhtmltopdf${NC}!!! Skipping...";
    fi
}


# Download and build specified python version
function install_build_python {
    local python_version="$1"
    local python_download_link="https://www.python.org/ftp/python/${python_version}/Python-${python_version}.tgz";
    local python_download_dir="$DOWNLOADS_DIR";
    local python_download_path="$python_download_dir/python-${python_version}.tgz";
    local python_build_dir="$python_download_dir/Python-$python_version";
    local python_path="$PROJECT_ROOT_DIR/python";
    local python_configure_options=( --prefix="$python_path" );

    if [ -n "$ODOO_BUILD_PYTHON_OPTIMIZE" ]; then
        python_configure_options+=( --enable-optimizations );
    fi

    if [ -n "$ODOO_BUILD_PYTHON_SQLITE3" ]; then
        python_configure_options+=( --enable-loadable-sqlite-extensions );
    fi

    if [[ "$python_version" =~ ^([0-9]+\.[0-9]+)\.[0-9]+$ ]]; then
        local python_version_short="${BASH_REMATCH[1]}"
    else
        echoe -e "${REDC}ERROR${NC}: Wrong python version format '$python_version'";
        return 1
    fi

    if ! wget -q -T 15 -O "$python_download_path" "$python_download_link"; then
            echoe -e "${REDC}ERROR${NC}: Cannot download Odoo from ${YELLOWC}${python_download_link}${NC}."
            echoe -e "Remove broken download (if it is exists) ${YELLOWC}${python_download_path}${NC}."
            echoe -e "and try to run command below: ";
            echoe -e "    ${BLUEC}wget --debug -T 15 -O \"$python_download_path\" \"$python_download_link\"${NC}"
            echoe -e "and analyze its output";
            return 2;
    fi
    if ! (cd "$python_download_dir" && tar -zxf "$python_download_path"); then
        echoe -e "${REDC}ERROR${NC}: Cannot unpack downloaded python archive ${YELLOWC}${python_download_path}${NC}."
        return 3;
    fi


    # Check if make package / command is installed, and install if it is not installed yet
    if ! check_command 'make' > /dev/null; then
        # TODO: May be it have sense to add it to pre-requirements, or somewhere else.
        #       Or may be it have sense to ask for confirmation?
        echoe -e "${YELLOWC}make${BLUEC} seems to be not installed. ${YELLOWC}make${BLUEC} is package required to build python and will be installed automatically.${NC}";
        install_sys_deps_internal "make";
    fi

    # Check if we need to install SQLite lib dev package  dpkg -s sqlite3 2&>1 > /dev/null
    if [ -n "$ODOO_BUILD_PYTHON_SQLITE3" ] && ! dpkg -s libsqlite3-dev > /dev/null 2>&1; then
        echoe -e "${YELLOWC}libsqlite3-dev${BLUEC} seems to be not installed. Installing...${NC}";
        install_sys_deps_internal "libsqlite3-dev";
    fi

    # Prepare build python
    echoe -e "${BLUEC}Building python version ${YELLOWC}${python_version}${BLUEC}...${NC}"
    local number_of_jobs;
    if check_command "nproc" > /dev/null; then
        number_of_jobs=$(nproc --ignore=1);
    else
        number_of_jobs=1;
    fi

    # Run build python
    echoe -e "${BLUEC}Configuring python (prefix=$python_path)...${NC}"
    if [ -n "$CI_RUN" ]; then
        # This is needed to make tests pass
        (cd "$python_build_dir" && "$ODOO_HELPER_LIB/pylib/bash_unwrap.py" ./configure "${python_configure_options[@]}")
    else
        (cd "$python_build_dir" && ./configure "${python_configure_options[@]}")
    fi
    echoe -e "${BLUEC}Compiling python...${NC}"
    (cd "$python_build_dir" && make --jobs="${number_of_jobs}")
    echoe -e "${BLUEC}Installing python...${NC}"
    (cd "$python_build_dir" && make --jobs="${number_of_jobs}" install)

    # Remove downloaded python
    rm -r "$python_download_dir/Python-$python_version" "$python_download_path";
    echo -e "${GREENC}OK${NC}: Python built successfully!"

    # create python symlink if needed
    if [ ! -f "${python_path}/bin/python" ]; then
        ln "${python_path}/bin/python${python_version_short}" "${python_path}/bin/python";
    fi
}

# Install virtual environment.
#
# install_virtual_env
function install_virtual_env {
    local venv_script=${ODOO_HELPER_ROOT}/tools/virtualenv/virtualenv.py;
    if [ -n "$VENV_DIR" ] && [ ! -d "$VENV_DIR" ]; then
        if [ -n "$ODOO_BUILD_PYTHON_VERSION" ]; then
            install_build_python "$ODOO_BUILD_PYTHON_VERSION";
            VIRTUALENV_PYTHON="$PROJECT_ROOT_DIR/python/bin/python" "$(odoo_get_python_interpreter)" "$venv_script" "$VENV_DIR";
        elif [ -z "$VIRTUALENV_PYTHON" ]; then
            local venv_python_version;
            venv_python_version=$(odoo_get_python_version);
            VIRTUALENV_PYTHON="$venv_python_version" "$(odoo_get_python_interpreter)" "$venv_script" "$VENV_DIR";
        else
            VIRTUALENV_PYTHON="$VIRTUALENV_PYTHON" "$(odoo_get_python_interpreter)" "$venv_script" "$VENV_DIR";
        fi
        exec_pip -q install nodeenv;

        if [ "$(odoo_get_major_version)" -gt 10 ]; then
            exec_pip -q install "setuptools<58";
        fi

        local nodeenv_opts;
        nodeenv_opts=( "--python-virtualenv" );
        if [ -n "$ODOO_INSTALL_NODE_VERSION" ]; then
            nodeenv_opts+=( "--node" "$ODOO_INSTALL_NODE_VERSION" );
        else
            nodeenv_opts+=( "--node" "lts" );
        fi

        execv nodeenv "${nodeenv_opts[@]}";  # Install node environment

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
    local deps=( );
    if ! check_command 'google-chrome' 'chromium' 'chromium-browser' > /dev/null; then
        echoe -e "${YELLOWC}Google Chrome${BLUEC} seems to be not installed. ${YELLOWC}chromium-browser${BLUEC} will be installed.${NC}";
        deps+=( chromium-browser );
    fi
    if ! check_command 'unbuffer' > /dev/null; then
        echoe -e "${YELLOWC}unbuffer${BLUEC} seems to be not installed. ${YELLOWC}expect-dev${BLUEC} and ${YELLOWC}tcl8.6${BLUEC} will be installed.${NC}";
        deps+=( expect-dev tcl8.6 );
    fi
    if ! check_command 'msgmerge' > /dev/null; then
        echoe -e "${YELLOWC}msgmerge${BLUEC} seems to be not installed. ${YELLOWC}gettext${BLUEC} package will be installed.${NC}";
        deps+=( gettext );
    fi

    if [ -n "${deps[*]}" ]; then
        install_sys_deps_internal "${deps[@]}";
    fi
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
        - jingtrang

    Usage:

        $SCRIPT_NAME install py-tools [options]  - install extra tools
        $SCRIPT_NAME install py-tools --help     - show this help message

    Options:

        -q|--quiet     - quiet mode. reduce output
        --upgrade      - upgrade the tools

    ";
    local pip_options=( );
    local pip_install_opts=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -q|--quiet)
                pip_options+=( --quiet );
            ;;
            --upgrade)
                pip_install_opts+=( --upgrade );
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
    exec_pip "${pip_options[@]}" install "${pip_install_opts[@]}" setproctitle watchdog pylint pylint-odoo coverage \
        flake8 flake8-colors websocket-client jingtrang;
}

# Install extra javascript tools
function install_js_tools {
    local usage="
    Install extra javascript tools.

    Following packages will be installed:

        - eslint
        - phantomjs-prebuilt (only for Odoo below 12.0)
        - stylelint
        - stylelint-config-standard

    Usage:

        $SCRIPT_NAME install js-tools [options] - install extra js tools
        $SCRIPT_NAME install js-tools --help    - show this help message

    Options:

        -u|--update       - update js packages
        -h|--help|help    - show this help message
    ";
    local npm_update;

    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            -u|--update)
                npm_update=1;
            ;;
            *)
                echo "Unknown option / command $key";
                return 1;
            ;;
        esac
        shift
    done
    local deps=( eslint stylelint stylelint-config-standard stylelint-config-standard-scss postcss-scss postcss-less);
    if [ "$(odoo_get_major_version)" -lt 12 ]; then
        deps+=( phantomjs-prebuilt );
    fi
    exec_npm install -g "${deps[@]}";
    if [ -n "$npm_update" ]; then
        exec_npm update -g "${deps[@]}";
    fi
}

function install_dev_tools {
    local usage="
    Install extra development tools. May require sudo.

    This command is just an alias to run following commands with single call:
        - $SCRIPT_NAME install bin-tools
        - $SCRIPT_NAME install py-tools
        - $SCRIPT_NAME install js-tools

    Usage:

        $SCRIPT_NAME install dev-tools [options]  - install extra dev tools
        $SCRIPT_NAME install dev-tools --help     - show this help message

    Options:

        --upgrade       - upgrade tools
        -h|--help|help  - show this help message
    ";
    local py_options=( );
    local js_options=( );
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --upgrade)
                py_options+=( --upgrade );
                js_options+=( --update );
            ;;
            *)
                echo "Unknown option / command $key";
                return 1;
            ;;
        esac
        shift
    done
    install_bin_tools;
    install_python_tools "${py_options[@]}";
    install_js_tools "${js_options[@]}";
}

function install_unoconv {
    local usage="
    Install unoconv;

    sudo is required for this command.
    Only available for odoo 11.0+
    Have to be run on per-project basis.

    Warning: this command is experimental.

    Usage:

        $SCRIPT_NAME install unoconv        - install unconv
        $SCRIPT_NAME install unoconv --help - show this help message
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
    ALWAYS_ANSWER_YES=1 install_sys_deps_internal unoconv;
    local system_python;
    system_python=$(command -v python3);
    if [ -n "$VENV_DIR" ] && [ -n "$system_python" ]; then
        exec_pip install unoconv;
        sed -i "1s@.*@#!$system_python@" "$VENV_DIR/bin/unoconv";
    fi;
}

function install_openupgradelib {
    local usage="
    Install latest openupgradelib;

    Warning: this command is experimental.

    Usage:

        $SCRIPT_NAME install openupgradelib        - install openupgradelib
        $SCRIPT_NAME install openupgradelib --help - show this help message
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
    exec_pip install --upgrade "git+https://github.com/OCA/openupgradelib.git@master#egg=openupgradelib"
}

# install_python_prerequirements
function install_python_prerequirements {
    # virtualenv >= 15.1.0 automaticaly installs last versions of pip and
    # setuptools, so we do not need to upgrade them
    exec_pip -q install phonenumbers python-slugify setuptools-odoo cffi \
        jinja2 click python-magic;

    if ! exec_py -c "import pychart" >/dev/null 2>&1 ; then
        exec_pip -q install Python-Chart;
    fi
}

# Install javascript pre-requirements.
# Now it is less compiler. install if it is not installed yet
function install_js_prerequirements {
    if ! check_command lessc > /dev/null; then
        execu npm install -g less@3.9.0 rtlcss;
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
    ODOO_CONF_OPTIONS['addons_path']="${ODOO_CONF_OPTIONS['addons_path']:-$addons_path}";
    ODOO_CONF_OPTIONS['admin_passwd']="${ODOO_CONF_OPTIONS['admin_passwd']:-admin}";
    ODOO_CONF_OPTIONS['data_dir']="${ODOO_CONF_OPTIONS['data_dir']:-$DATA_DIR}";
    ODOO_CONF_OPTIONS['logfile']="${ODOO_CONF_OPTIONS['logfile']:-$LOG_FILE}";
    ODOO_CONF_OPTIONS['db_host']="${ODOO_CONF_OPTIONS['db_host']:-False}";
    ODOO_CONF_OPTIONS['db_port']="${ODOO_CONF_OPTIONS['db_port']:-False}";
    ODOO_CONF_OPTIONS['db_user']="${ODOO_CONF_OPTIONS['db_user']:-odoo}";
    ODOO_CONF_OPTIONS['db_password']="${ODOO_CONF_OPTIONS['db_password']:-False}";

    local conf_file_data="[options]";
    for key in "${!ODOO_CONF_OPTIONS[@]}"; do
        conf_file_data="$conf_file_data\n$key = ${ODOO_CONF_OPTIONS[$key]}";
    done

    echo -e "$conf_file_data" > "$conf_file";
}


# odoo_run_setup_py
function odoo_run_setup_py {
    # Install dependencies via pip (it is faster if they are cached)
    install_odoo_py_requirements_for_version;

    if [ "$(odoo_get_major_version)" -gt 10 ]; then
        # We have to replace suds-jurko with suds-py3 to make it installable.
        sed -i 's/suds-jurko/suds-py3/g' "$ODOO_PATH/setup.py";
    fi

    # Install odoo
    (cd "$ODOO_PATH" && exec_py setup.py -q develop);
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

    # Run setup.py
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
        --node-version <version>  - version of node.js to be installed.
                                    Default: lts
        --no-backup               - do not backup virtualenv
        --build-python <version>  - Build custom version of python for
                                    this virtual environment
        --build-python-optimize   - Apply --enable-optimizations to python build.
                                    This could take a while.
        --build-python-sqlite3    - Apply  --enable-loadable-sqlite-extensions
                                    when building python.
    ";
    while [[ $# -gt 0 ]]
    do
        local key="$1";
        case $key in
            -p|--python)
                VIRTUALENV_PYTHON="$2";
                shift;
            ;;
            --no-backup)
                local do_not_backup_virtualenv=1;
            ;;
            --node-version)
                ODOO_INSTALL_NODE_VERSION=$2;
                shift;
            ;;
            --build-python)
                ODOO_BUILD_PYTHON_VERSION=$2;
                shift;
            ;;
            --build-python-optimize)
                ODOO_BUILD_PYTHON_OPTIMIZE=1;
            ;;
            --build-python-sqlite3)
                ODOO_BUILD_PYTHON_SQLITE3=1;
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
    if [ -d "$VENV_DIR" ] && [ -z "$do_not_backup_virtualenv" ]; then
        local venv_backup_path;
        local python_backup_path;
        venv_backup_path="$PROJECT_ROOT_DIR/venv-backup-$(random_string 4)";
        python_backup_path="$PROJECT_ROOT_DIR/python-$(random_string 4)";
        mv "$VENV_DIR" "$venv_backup_path";
        echoe -e "${BLUEC}Old ${YELLOWC}virtualenv${BLUEC} backed up at ${YELLOWC}${venv_backup_path}${NC}";
        if [ -d "$PROJECT_ROOT_DIR/python" ]; then
            mv "$PROJECT_ROOT_DIR/python" "$python_backup_path";
            echoe -e "${BLUEC}Old ${YELLOWC}python${BLUEC} backed up at ${YELLOWC}${python_backup_path}${NC}";
        fi
    elif [ -d "$VENV_DIR" ]; then
        # If we do not need to backup virtualenv, then we have to removed it before installing;
        echoe -e "${YELLOWC}Removing virualenv...${NC}";
        rm -r "$VENV_DIR";
        if [ -d "$PROJECT_ROOT_DIR/python" ]; then
            rm -r "$PROJECT_ROOT_DIR/python";
        fi
        echoe -e "${YELLOWC}Virtualenv removed!${NC}";
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

        $SCRIPT_NAME install reinstall-odoo [options] <type> - reinstall odoo

    <type> could be:
        git      - reinstall Odoo as git repository.
        archive  - reinstall Odoo from archive.

    Options:
        --no-backup     - do not backup old version of odoo
        -h|--help|help  - show this help message
    ";

    local reinstall_action="download";
    local do_not_backup_old_odoo;
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
            --no-backup)
                do_not_backup_old_odoo=1;
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

    if [ -d "$ODOO_PATH" ]; then
        if [ -z "$do_not_backup_old_odoo" ]; then
            local odoo_backup_path;
            odoo_backup_path="$ODOO_PATH-backup-$(random_string 4)";
            mv "$ODOO_PATH" "$odoo_backup_path";
            echo -e "${BLUEC}NOTE:${NC}: Previous odoo code backed up at ${YELLOWC}${odoo_backup_path}${NC}!";
        else
            echo -e "${BLUEC}INFO:${NC}: Removing old Odoo installation...";
            rm -rf "$ODOO_PATH";
        fi
    fi

    install_fetch_odoo "$reinstall_action";
    install_reinstall_venv;
}


# Entry point for install subcommand
function install_entry_point {
    local usage="
    Install utils, fix installation, etc

    Usage:

        $SCRIPT_NAME install pre-requirements [--help]   - [sudo] install system pre-requirements
        $SCRIPT_NAME install sys-deps [--help]           - [sudo] install system dependencies for odoo version
        $SCRIPT_NAME install py-deps [--help]            - install python dependencies for odoo version (requirements.txt)
        $SCRIPT_NAME install py-prerequirements          - install project-level python prerequirements
                                                           (python packages required for odoo-helper)
        $SCRIPT_NAME install py-tools [--help]           - install python tools (pylint, flake8, ...)
        $SCRIPT_NAME install js-tools [--help]           - install javascript tools (jshint, phantomjs)
        $SCRIPT_NAME install bin-tools [--help]          - [sudo] install binary tools. at this moment it is *unbuffer*,
                                                           which is in *expect-dev* package
        $SCRIPT_NAME install dev-tools [--help]          - [sudo] install dev tools.
        $SCRIPT_NAME install unoconv [--help]            - [sudo] install unoconv.
        $SCRIPT_NAME install openupgradelib [--help]     - install lates openupgradelib.
        $SCRIPT_NAME install wkhtmltopdf [--help]        - [sudo] install wkhtmtopdf
        $SCRIPT_NAME install postgres [user] [password]  - [sudo] install postgres.
                                                           and if user/password specified, create it
        $SCRIPT_NAME install reinstall-venv [--help]     - reinstall virtual environment
        $SCRIPT_NAME install reinstall-odoo [--help]     - completly reinstall odoo
                                                           (downlload or clone new sources, create new virtualenv, etc).
                                                           Options are:
                                                              - clone odoo as git repository
                                                              - download odoo archieve and unpack source

        $SCRIPT_NAME install <addon1> [addon2]...        - [experimental] install addons on all databases.
                                                           this is alternative for: $SCRIPT_NAME addons install
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
                install_system_prerequirements "$@";
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
                install_odoo_py_requirements_for_version "$@";
                return 0;
            ;;
            py-prerequirements)
                shift;
                config_load_project;
                install_python_prerequirements;
                return 0;
            ;;
            py-tools)
                shift;
                config_load_project;
                install_python_tools "$@";
                return 0;
            ;;
            js-tools)
                shift;
                config_load_project;
                install_js_tools "$@";
                return 0;
            ;;
            bin-tools)
                shift;
                install_bin_tools "$@";
                return 0;
            ;;
            dev-tools)
                shift;
                config_load_project;
                install_dev_tools "$@";
                return 0;
            ;;
            unoconv)
                shift;
                config_load_project;
                install_unoconv "$@";
                return 0;
            ;;
            openupgradelib)
                shift;
                config_load_project;
                install_openupgradelib "$@";
                return;
            ;;
            wkhtmltopdf)
                shift;
                install_wkhtmltopdf "$@";
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
                install_reinstall_odoo "$@";
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
                config_load_project;
                if addons_is_odoo_addon "$1"; then
                    echoe -e "${BLUEC}It seems that instalation of addons requeested.\nTrying to install addons...${NC}";
                    addons_install_update install "$@";
                    return;
                else
                    echo "Unknown option / command '$key'";
                    return 1;
                fi
            ;;
        esac
        shift
    done
}
