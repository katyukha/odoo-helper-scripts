if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------

set -e; # fail on errors


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
    sudo apt-get install $opt_apt_always_yes "$@";
}

# Get dependencies from odoo's debian/control file
function install_sys_deps {
        local sys_deps=$(perl -ne 'next if /^#/; $p=(s/^Depends:\s*/ / or (/^ / and $p)); s/,|\n|\([^)]+\)//mg; print if $p' < $ODOO_PATH/debian/control);
        install_sys_deps_internal $sys_deps;
}

function install_and_configure_postgresql {
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-y";
    fi

    # Check if postgres is installed on this machine. If not, install it
    # TODO: think about better way to check postgres presence
    if [ ! -f /etc/init.d/postgresql ]; then
        echov "It seems that postgresql is already installed, so not installing it, just configuring...";
        sudo apt-get install $opt_apt_always_yes postgresql;
    fi
    local user_count=$(sudo -u postgres -H psql -tA -c "SELECT count(*) FROM pg_user WHERE usename = '$DB_USER';");
    if [ $user_count -eq 0 ]; then
        sudo -u postgres -H psql -c "CREATE USER $DB_USER WITH CREATEDB PASSWORD '$DB_PASSWORD';"
        echov "Postgresql user $DB_USER was created for this Odoo instance";
    else
        echo -e "${YELLOWC}There are $DB_USER already exists in postgres server${NC}";
    fi
    echov "Postgres seems to be installed and db user seems created.";
}

function install_system_prerequirements {
    if [ ! -z $ALWAYS_ANSWER_YES ]; then
        local opt_apt_always_yes="-y";
    fi

    echo "Updating package list..."
    sudo apt-get update || true;

    echo "Installing system preprequirements...";
    sudo apt-get install $opt_apt_always_yes git wget python-setuptools perl g++ libpq-dev python-dev;

    if [ ! -z $INSTALL_EXTRA_UTILS ]; then
        sudo apt-get install $opt_apt_always_yes expect-dev;
    fi;

    sudo easy_install pip;
    sudo pip install --upgrade pip virtualenv;
}


# Install virtual environment, and preinstall some packages
function install_virtual_env {
    if [ ! -d $VENV_DIR ]; then
        if [ ! -z $USE_SYSTEM_SITE_PACKAGES ]; then
            local venv_opts=" --system-site-packages ";
        else
            local venv_opts="";
        fi
        virtualenv $venv_opts $VENV_DIR;
    fi

    # required to make odoo.py work correctly when setuptools too old
    execu easy_install --upgrade setuptools;
    execu pip install --upgrade pip;  

    if ! execu python -c 'import pychart'; then
        execu pip install http://download.gna.org/pychart/PyChart-1.39.tar.gz;
    fi

    if [ ! -z $INSTALL_EXTRA_UTILS ]; then
        execu pip install --upgrade erppeek;
    fi

    execu pip install --upgrade --allow-external=PIL --allow-unverified=PIL PIL
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

function odoo_gevent_install_workaround_cleanup {
    if [ ! -z $odoo_gevent_fix_applied ]; then
        mv -f $ODOO_PATH/setup.py.backup $ODOO_PATH/setup.py
        unset odoo_gevent_fix_applied;
    fi
}

