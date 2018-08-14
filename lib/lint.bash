# Copyright © 2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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


ohelper_require "utils";
ohelper_require "addons";
ohelper_require "odoo";
ohelper_require "config";
# ----------------------------------------------------------------------------------------

set -e; # fail on errors

# lint_run_flake8 [flake8 options] <module1 path> [module2 path] .. [module n path]
function lint_run_flake8 {
    local usage="
    Usage:

        $SCRIPT_NAME lint flake8 <addon path> [addon path]
        $SCRIPT_NAME lint flake8 --help

    Description:
        Lint addons with [Flake8](http://flake8.pycqa.org)
        By default lints only installable addons ('installable' is True) on
        specified *addon paths*

        To run unwrapped flake8 use following command:

            $ odoo-helper exec flake8

    ";
    # Parse command line options
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
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done

    local res=0;
    for path in $(addons_list_in_directory --installable $@); do
        if ! execu flake8 --config="$ODOO_HELPER_LIB/default_config/flake8.cfg" $path; then
            res=1;
        fi
    done
    return $res;
}


# lint_run_pylint_internal <addon_path> [options]
function lint_run_pylint_internal {
    local addon_dir=$(dirname $1);
    local addon_name=$(basename $1);
    shift;

    local save_dir=$(pwd);
    local res=0;
    cd $addon_dir;
    if ! execu pylint $@ $addon_name; then
        res=1;
    fi
    cd $save_dir;
    return $res;
}

# Run pylint tests for modules
# lint_run_pylint <module1 path> [module2 path] .. [module n path]
# lint_run_pylint [--disable=E111,E222,...] <module1 path> [module2 path] .. [module n path]
function lint_run_pylint {
    local pylint_rc="$ODOO_HELPER_LIB/default_config/pylint_odoo.cfg";
    local pylint_opts="--rcfile=$pylint_rc";
    local pylint_disable="manifest-required-author";

    # specify valid odoo version for pylint manifest version check
    pylint_opts="$pylint_opts --valid_odoo_versions=$ODOO_VERSION";

    # Pre-process commandline arguments to be forwarded to pylint
    while [[ "$1" =~ ^--[a-zA-Z0-9\-]+(=[a-zA-Z0-9,-.]+)? ]]; do
        if [[ "$1" =~ ^--disable=([a-zA-Z0-9,-]*) ]]; then
            local pylint_disable_opt=$1;
            local pylint_disable_arg="${BASH_REMATCH[1]}";
            pylint_disable=$(join_by , $pylint_disable_arg "manifest-required-author");
        elif [[ "$1" =~ --help|--long-help|--version ]]; then
            local show_help=1;
            pylint_opts="$pylint_opts $1"
        else
            pylint_opts="$pylint_opts $1"
        fi
        shift;
    done
    local pylint_opts="$pylint_opts -d $pylint_disable";

    # Show help if requested
    if [ ! -z $show_help ]; then
        execu pylint $pylint_opts;
        return;
    fi

    local res=0;
    for path in $(addons_list_in_directory --installable $@); do
        if ! lint_run_pylint_internal $path $pylint_opts; then
            res=1;
        fi
    done

    return $res
}


# lint_run_stylelint_internal <addon path>
function lint_run_stylelint_internal {
    local addon_path="$1";
    local save_dir;
    local stylelint_default_conf;
    local stylelint_less_conf;
    local stylelint_scss_conf;
    local res=0;

    save_dir=$(pwd);
    cd $addon_path;

    stylelint_default_conf=$(config_get_default_tool_conf "stylelint-default.json");
    stylelint_less_conf=$(config_get_default_tool_conf "stylelint-default-less.json");
    stylelint_scss_conf=$(config_get_default_tool_conf "stylelint-default-scss.json");

    echoe -e "${BLUEC}Processing addon ${YELLOWC}$(basename $addon_path)${BLUEC} ...${NC}";

    if ! execu stylelint --config "$stylelint_default_conf" "$addon_path/**/*.css"; then
        res=1;
    fi
    if ! execu stylelint --config "$stylelint_less_conf" "$addon_path/**/*.less"; then
        res=1;
    fi
    if ! execu stylelint --config "$stylelint_scss_conf" "$addon_path/**/*.scss"; then
        res=1;
    fi

    if [ ! "$res" -eq "0" ]; then
        echoe -e "${BLUEC}Addon ${YELLOWC}$(basename $addon_path)${BLUEC}:${REDC}FAIL${NC}";
    else
        echoe -e "${BLUEC}Addon ${YELLOWC}$(basename $addon_path)${BLUEC}:${GREENC}OK${NC}";
    fi

    cd $save_dir;

    return $res;
}


# Run stylelint for each addon in specified path
# lint_run_stylelint <path> [path] [path]
function lint_run_stylelint {
    local usage="
    Usage:

        $SCRIPT_NAME lint style <addon path> [addon path]
        $SCRIPT_NAME lint style --help

    Description:
        Lint styles (*.css, *.less, *.scss).
        This command uses [stylelint](https://stylelint.io/) with
        standard config (stylelint-config-standard)

    ";

    # Parse command line options
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
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done

    #-----
    local res=0;
    for addon_path in $(addons_list_in_directory --installable $@); do
        if ! lint_run_stylelint_internal $addon_path; then
            res=1;
        fi
    done

    return $res
}


function lint_command {
    local usage="
    Usage:

        $SCRIPT_NAME lint flake8 <addon path> [addon path]
        $SCRIPT_NAME lint pylint <addon path> [addon path]
        $SCRIPT_NAME lint pylint [--disable=E111,E222,...] <addon path> [addon path]
        $SCRIPT_NAME lint style <addon path> [addon path]

        $SCRIPT_NAME lint -h|--help|help    - show this help
    ";

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options supplied $#: $@";
        echo "";
        echo "$usage";
        exit 0;
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return;
            ;;
            flake8)
                shift;
                lint_run_flake8 $@;
                return;
            ;;
            pylint)
                shift;
                lint_run_pylint $@;
                return;
            ;;
            style)
                shift;
                lint_run_stylelint $@;
                return;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac
        shift
    done
}
