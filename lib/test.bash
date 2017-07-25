if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# require other odoo-helper modules
ohelper_require fetch;
ohelper_require server;
ohelper_require db;
ohelper_require odoo;
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


# create_tmp_dirs
function create_tmp_dirs {
    TMP_ROOT_DIR="/tmp/odoo-tmp-`random_string 16`";
    echov "Temporary dir created: $TMP_ROOT_DIR";

    OLD_ADDONS_DIR=$ADDONS_DIR;
    OLD_DOWNLOADS_DIR=$DOWNLOADS_DIR;
    OLD_REPOSITORIES_DIR=$REPOSITORIES_DIR;
    OLD_ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;

    ADDONS_DIR=$TMP_ROOT_DIR/addons;
    DOWNLOADS_DIR=$TMP_ROOT_DIR/downloads;
    REPOSITORIES_DIR=$TMP_ROOT_DIR/repositories;
    ODOO_TEST_CONF_FILE=$TMP_ROOT_DIR/odoo.test.conf;
    
    mkdir -p $ADDONS_DIR;
    mkdir -p $DOWNLOADS_DIR;
    mkdir -p $REPOSITORIES_DIR;
    sed -r "s@addons_path(.*)@addons_path\1,$ADDONS_DIR@" $OLD_ODOO_TEST_CONF_FILE > $ODOO_TEST_CONF_FILE
}

# remove_tmp_dirs
function remove_tmp_dirs {
    if [ -z $TMP_ROOT_DIR ]; then
        exit -1;  # no tmp root was created
    fi

    ADDONS_DIR=$OLD_ADDONS_DIR;
    DOWNLOADS_DIR=$OLD_DOWNLOADS_DIR;
    REPOSITORIES_DIR=$OLD_REPOSITORIES_DIR;
    ODOO_TEST_CONF_FILE=$OLD_ODOO_TEST_CONF_FILE;
    rm -rf $TMP_ROOT_DIR;

    echov "Temporary dir removed: $TMP_ROOT_DIR";
    TMP_ROOT_DIR=;
    OLD_ADDONS_DIR=;
    OLD_DOWNLOADS_DIR=;
    OLD_REPOSITORIES_DIR=;
    OLD_ODOO_TEST_CONF_FILE=$ODOO_TEST_CONF_FILE;
}


# test_run_server <with_coverage 0|1> [server options]
function test_run_server {
    local with_coverage=$1; shift;
    local SERVER=`get_server_script`;
    echo -e "${LBLUEC}Running server [${YELLOWC}test${LBLUEC}][${YELLOWC}coverage:${with_coverage}${BLUEC}]${NC}: $SERVER $@";

    # enable test coverage
    if [ $with_coverage -eq 1 ]; then
        if [ -z $COVERAGE_INCLUDE ]; then
            local COVERAGE_INCLUDE="$(pwd)/*";
        fi
        exec_conf $ODOO_TEST_CONF_FILE execu "coverage run --rcfile=$ODOO_HELPER_LIB/default_config/coverage.cfg \
            --include='$COVERAGE_INCLUDE' $SERVER --stop-after-init $@";
    else
        exec_conf $ODOO_TEST_CONF_FILE execu "$SERVER --stop-after-init $@";
    fi
}

# test_module_impl <with_coverage 0|1> <module> [extra_options]
# example: test_module_impl base -d test1
function test_module_impl {
    local with_coverage=$1
    local module=$2
    shift; shift;  # all next arguments will be passed to server

    # Set correct log level (depends on odoo version)
    if [ "$ODOO_VERSION" == "7.0" ]; then
        local log_level='test';
    else
        local log_level='info';
    fi

    set +e; # do not fail on errors
    # Install module
    test_run_server $with_coverage --init=$module --log-level=warn "$@";
    # Test module
    test_run_server $with_coverage --update=$module \
        --log-level=$log_level --test-enable "$@";
    set -e; # Fail on any error
}

# Get database name or create new one. Prints database name
# test_get_or_create_db    # get db
# test_get_or_create_db 1  # create new db
function test_get_or_create_db {
    local create_test_db=$1;

    if [ $create_test_db -eq 1 ]; then
        local test_db_name=`random_string 24`;
        odoo_db_create $test_db_name $ODOO_TEST_CONF_FILE 1>&2;
    else
        # name of test database expected to be defined in ODOO_TEST_CONF_FILE
        local test_db_name="$(odoo_get_conf_val db_name $ODOO_TEST_CONF_FILE)";
    fi
    echo "$test_db_name";
}


# Run tests for set of addons
# test_run_tests_for_modules <with_coverage 0|1> <test_db_name> <log_file> <module_1> [module2] ...
function test_run_tests_for_modules {
    local with_coverage=$1
    local test_db_name=$2;
    local test_log_file=$3;
    shift; shift; shift;

    local modules=$(join_by , $@);

    if [ -z "$modules" ]; then
        echo -e "${REDC}ERROR:${NC} No modules supplied";
        return 1;
    fi

    if [ -z "$test_db_name" ]; then
        echo -e "${REDC}ERROR:${NC} No database name supplierd!";
        return 1;
    fi

    echo -e "${BLUEC}Testing modules $modules...${NC}";
    test_module_impl $with_coverage $modules --database $test_db_name \
        2>&1 | tee -a $test_log_file;
}


# Parse log file
# test_parse_log_file <test_db_name> <log_file> [fail_on_warn]
function test_parse_log_file {
    local test_db_name=$1;
    local test_log_file=$2;
    local fail_on_warn=$3;
    # remove color codes from log file
    sed -ri "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" $test_log_file;

    # Check log for warnings
    local warnings=0;
    if grep -q -e "no access rules, consider adding one" \
               -e "WARNING" \
               "$test_log_file"; then
        warnings=1;
        echo -e "${YELLOWC}Warings found while testing${NC}";
    fi


    # Standard log processing
    local res=0;
    if grep -q -e "CRITICAL" \
               -e "ERROR $test_db_name" \
               -e "At least one test failed" \
               -e "invalid module names, ignored" \
               -e "no access rules, consider adding one" \
               -e "OperationalError: FATAL" \
               "$test_log_file"; then
        res=1;
    fi

    # If Test is ok but there are warnings and set option 'fail-on-warn', fail this test
    if [ $res -eq 0 ] && [ $warnings -ne 0 ] && [ $fail_on_warn -eq 1 ]; then
        res=1
    fi

    return $res
    
}

# Function to handle Keyboard Interrupt while test.
# Primary reason for this is to clean up database if it was created for test
function test_run_tests_handle_sigint {
    local create_test_db=$1;
    local test_db_name=$2

    if [ $create_test_db -eq 1 ]; then
        odoo_db_drop $test_db_name $ODOO_TEST_CONF_FILE;
    fi

    exit 1;
}


# Run tests
# test_run_tests <create_test_db 1|0> <fail_on_warn 1|0> <with_coverage 1|0> <modules>
function test_run_tests {
    local create_test_db=$1;
    local fail_on_warn=$2;
    local with_coverage=$3;
    shift; shift; shift;

    # Create new test database if required
    local test_db_name="$(test_get_or_create_db $create_test_db)";
    local test_log_file="${LOG_DIR:-.}/odoo.test.db.$test_db_name.log";

    # Remove log file if it is present before test, otherwise
    # it will be appended, wich could lead to incorrect test results
    if [ -e $test_log_file ]; then
        rm $test_log_file;
    fi

    trap "test_run_tests_handle_sigint $create_test_db $test_db_name" SIGINT;

    test_run_tests_for_modules $with_coverage $test_db_name $test_log_file $@;

    # Combine test coverage results
    if [ $with_coverage -eq 1 ]; then
        execv coverage combine;
    fi

    # Drop created test db
    if [ $create_test_db -eq 1 ]; then
        echo  -e "${BLUEC}Droping test database: $test_db_name${NC}";
        odoo_db_drop $test_db_name $ODOO_TEST_CONF_FILE
    fi

    if test_parse_log_file $test_db_name $test_log_file $fail_on_warn; then
        echo -e "TEST RESULT: ${GREENC}OK${NC}";
    else
        echo -e "TEST RESULT: ${REDC}FAIL${NC}";
        return 1;
    fi
}


# test_find_modules_in_directories <dir1> [dir2] ...
# echoes list of modules found in specified directories
function test_find_modules_in_directories {
    # TODO: sort addons in correct order to avoid duble test runs
    #       in cases when addon that is tested first depends on other,
    #       which is tested next, but when it is tested, then all dependent
    #       addons will be also tested
    for directory in $@; do
        # skip non directories
        for addon_path in $(addons_list_in_directory $directory); do
            if addons_is_installable $addon_path; then
                echo -n " $(basename $addon_path)";
            fi
        done
    done
}

# Run flake8 for modules
# test_run_flake8 [flake8 options] <module1 path> [module2 path] .. [module n path]
function test_run_flake8 {
    local res=0;
    if ! execu flake8 --config="$ODOO_HELPER_LIB/default_config/flake8.cfg" $@; then
        res=1;
    fi
    return $res;
}

# Run pylint tests for modules
# test_run_pylint <module1 path> [module2 path] .. [module n path]
# test_run_pylint [--disable=E111,E222,...] <module1 path> [module2 path] .. [module n path]
function test_run_pylint {
    if [[ "$1" =~ ^--disable=([a-zA-Z0-9,-]*) ]]; then
        local pylint_disable_opt=$1;
        local pylint_disable_arg="${BASH_REMATCH[1]}";
        local pylint_disable=$(join_by , $pylint_disable_arg "manifest-required-author");
        shift;
    else
        local pylint_disable="manifest-required-author";
    fi
    local pylint_rc="$ODOO_HELPER_LIB/default_config/pylint_odoo.cfg";
    local pylint_opts="--rcfile=$pylint_rc -d $pylint_disable";
    local res=0;
    for path in $@; do
        if is_odoo_module $path; then
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
                    if ! test_run_pylint "$pylint_disable_opt" $subdir; then
                        res=1;
                    fi
                fi
            done
        fi
    done
    return $res
}

# test_module [--create-test-db] -m <module_name>
# test_module [--tmp-dirs] [--create-test-db] -m <module name> -m <module name>
# test_module [--tmp-dirs] [--create-test-db] -d <dir with addons to test>
function test_module {
    local create_test_db=0;
    local fail_on_warn=0;
    local with_coverage=0;
    local with_coverage_report_html=;
    local with_coverage_report=;
    local modules="";
    local directories="";
    local usage="
    Usage 

        $SCRIPT_NAME test [options] [-m <module_name>] [-m <module name>] ...
        $SCRIPT_NAME test [options] [-d <dir with addons to test>]
        $SCRIPT_NAME test flake8 <addon path> [addon path]
        $SCRIPT_NAME test pylint <addon path> [addon path]
        $SCRIPT_NAME test pylint [--disable=E111,E222,...] <addon path> [addon path]

    Options:
        --create-test-db    - Creates temporary database to run tests in
        --fail-on-warn      - if this option passed, then tests will fail even on warnings
        --tmp-dirs          - use temporary dirs for test related downloads and addons
        --no-rm-tmp-dirs    - not remove temporary directories that was created for this test
        --coverage          - calculate code coverage (use python's *coverage* util)
        --coverage-html     - automaticaly generate coverage html report
        --coverage-report   - print coverage report
        -m|--module         - specify module to test
        -d|--directory      - specify directory with modules to test
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
                create_test_db=1;
            ;;
            --fail-on-warn)
                fail_on_warn=1;
            ;;
            --coverage)
                with_coverage=1;
            ;;
            --coverage-html)
                with_coverage=1;
                with_coverage_report_html=1;
            ;;
            --coverage-report)
                with_coverage=1;
                with_coverage_report=1;
            ;;
            -m|--module)
                modules="$modules $2";  # add module to module list
                shift;
            ;;
            -d|--directory)
                modules="$modules $(test_find_modules_in_directories $2)";
                shift;
            ;;
            --tmp-dirs)
                local tmp_dirs=1
            ;;
            --no-rm-tmp-dirs)
                local not_remove_tmp_dirs=1;
            ;;
            flake8)
                shift;
                test_run_flake8 $@;
                exit;
            ;;
            pylint)
                shift;
                test_run_pylint $@;
                exit;
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

    # Run tests
    if test_run_tests ${create_test_db:-0} ${fail_on_warn:-0} \
            ${with_coverage:-0} $modules;
    then
        local res=$?;
    else
        local res=$?
    fi

    if [ ! -z "$with_coverage_report_html" ]; then
        execv coverage html;
    fi

    if [ ! -z "$with_coverage_report" ]; then
        execv coverage report;
    fi
    # ---------

    if [ ! -z $tmp_dirs ] && [ -z $not_remove_tmp_dirs ]; then
        remove_tmp_dirs;
    fi

    return $res;
}

