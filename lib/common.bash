# Copyright © 2015-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# predefined filenames
CONF_FILE_NAME="odoo-helper.conf";


set -e; # fail on errors

# Odoo-helper mark that common module is imported
ODOO_HELPER_COMMON_IMPORTED=1;

declare -A ODOO_HELPER_IMPORTED_MODULES;
ODOO_HELPER_IMPORTED_MODULES[common]=1

# if odoo-helper root conf is not loaded yet, try to load it
# This is useful when this lib is used by external utils,
# making possible to write things like:
#   source $(odoo-helper system lib-path common);
#   oh_require 'server'
#   ...

if [ -z "$ODOO_HELPER_ROOT" ]; then
    if [ -f "/etc/$CONF_FILE_NAME" ]; then
        source "/etc/$CONF_FILE_NAME";
    fi
    if [ -f "$HOME/$CONF_FILE_NAME" ]; then
        source "$HOME/$CONF_FILE_NAME";
    fi

    if [ -z $ODOO_HELPER_ROOT ]; then
        echo "Odoo-helper-scripts seems not been installed correctly.";
        echo "Reinstall it (see Readme on https://gitlab.com/katyukha/odoo-helper-scripts/)";
        exit 1;
    fi
fi

# Color related definitions
function allow_colors {
    NC='\e[0m';
    REDC='\e[31m';
    GREENC='\e[32m';
    YELLOWC='\e[33m';
    BLUEC='\e[34m';
    LBLUEC='\e[94m';
    OH_COLORS_ENABLED=1;
}

# could be used to hide colors in output
function deny_colors {
    NC='';
    REDC='';
    GREENC='';
    YELLOWC='';
    BLUEC='';
    LBLUEC='';
    OH_COLORS_ENABLED=;
}

# Allow colors by default
allow_colors;
# -------------------------

# Get path to specified bash lib
# oh_get_lib_path <lib name>
function oh_get_lib_path {
    local mod_name=$1;
    local mod_path=$ODOO_HELPER_LIB/$mod_name.bash;
    if [ -f $mod_path ]; then
        echo "$mod_path";
    else
        >&2 echo -e "${REDC}ERROR${NC}: module ${YELLOWC}${mod_name}${NC} could not been loaded." \
                    "Looking for module in '${BLUEC}${ODOO_HELPER_LIB}${NC}'";
        return 1;
    fi
}

# Simplify import controll
# oh_require <module_name>
function ohelper_require {
    local mod_name=$1;
    if [ -z ${ODOO_HELPER_IMPORTED_MODULES[$mod_name]} ]; then
        ODOO_HELPER_IMPORTED_MODULES[$mod_name]=1;
        source $(oh_get_lib_path $mod_name);
    fi
}

# Import version info and utils
ohelper_require "version";
ohelper_require "utils";
