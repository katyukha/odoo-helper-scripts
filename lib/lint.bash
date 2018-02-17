if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi


ohelper_require utils;
ohelper_require addons;
ohelper_require odoo;
# ----------------------------------------------------------------------------------------

set -e; # fail on errors

# test_run_flake8 [flake8 options] <module1 path> [module2 path] .. [module n path]
function lint_run_flake8 {
    local res=0;
    if ! execu flake8 --config="$ODOO_HELPER_LIB/default_config/flake8.cfg" $@; then
        res=1;
    fi
    return $res;
}

# Run pylint tests for modules
# test_run_pylint <module1 path> [module2 path] .. [module n path]
# test_run_pylint [--disable=E111,E222,...] <module1 path> [module2 path] .. [module n path]
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
    for path in $@; do
        if is_odoo_module $path && addons_is_installable $path; then
            local addon_dir=$(dirname $path);
            local addon_name=$(basename $path);
            local save_dir=$(pwd);
            cd $addon_dir;
            if ! execu pylint $pylint_opts $addon_name; then
                res=1;
            fi
            cd $save_dir;
        elif [ -d $path ]; then
            for subdir in "$path"/*; do
                if is_odoo_module $subdir; then
                    if ! lint_run_pylint "$pylint_disable_opt" $subdir; then
                        res=1;
                    fi
                fi
            done
        fi
    done
    return $res
}


# Run stylelint for each addon in specified path
# test_run_stylelint <path> [path] [path]
function lint_run_stylelint {
    local stylelint_config_path=$ODOO_HELPER_LIB/default_config/stylelint-default.json;

    #-----
    local res=0;
    for directory in $@; do
        # skip non directories
        for addon_path in $(addons_list_in_directory $directory); do
            if addons_is_installable $addon_path; then
                local save_dir=$(pwd);
                cd $addon_path;

                echoe -e "${BLUEC}Processing addon ${YELLOWC}$(basename $addon_path)${BLUEC} ...${NC}";

                if ! execu stylelint --config $stylelint_config_path \
                        "$addon_path/**/*.css" \
                        "$addon_path/**/*.scss" \
                        "$addon_path/**/*.less"; then
                    res=1;
                    echoe -e "${BLUEC}Addon ${YELLOWC}$(basename $addon_path)${BLUEC}:${REDC}FAIL${NC}";
                else
                    echoe -e "${BLUEC}Addon ${YELLOWC}$(basename $addon_path)${BLUEC}:${GREENC}OK${NC}";
                fi

                cd $save_dir;
            fi
        done
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
                exit 0;
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
                exit 1;
            ;;
        esac
        shift
    done
}
