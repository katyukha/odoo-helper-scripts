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
ohelper_require lint;
# ----------------------------------------------------------------------------------------

set -e; # fail on errors


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
        if ! check_command coverage >/dev/null 2>&1; then
            echoe -e "${REDC}ERROR${NC}: command *${YELLOWC}coverage${NC}* not found. Please, run *${BLUEC}odoo-helper install py-tools${BLUEC}* or *${BLUEC}odoo-helper pip install coverage${NC}*.";
            return 1
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

    # Install module
    if ! test_run_server $with_coverage --init=$module --log-level=warn "$@"; then
        return $?;
    fi

    # Test module
    if ! test_run_server $with_coverage --update=$module \
        --log-level=$log_level --test-enable "$@"; then
        return $?;
    fi
}

# Get database name or create new one. Prints database name
# test_get_or_create_db      # get db
# test_get_or_create_db 1    # recreate db
# test_get_or_create_db 0 1  # create new db
function test_get_or_create_db {
    local recreate_db=$1;
    local create_test_db=$2;

    if [ $create_test_db -eq 1 ]; then
        local test_db_name=`random_string 24`;
        odoo_db_create --demo $test_db_name $ODOO_TEST_CONF_FILE 1>&2;
    else
        # name of test database expected to be defined in ODOO_TEST_CONF_FILE
        local test_db_name="$(odoo_get_conf_val db_name $ODOO_TEST_CONF_FILE)";
    fi

    if [ $recreate_db -eq 1 ] && odoo_db_exists -q $test_db_name; then
        odoo_db_drop $test_db_name $ODOO_TEST_CONF_FILE 1>&2;
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
# test_run_tests <recreate_db 1|0> <create_test_db 1|0> <fail_on_warn 1|0> <with_coverage 1|0> <modules>
function test_run_tests {
    local recreate_db=$1;
    local create_test_db=$2;
    local fail_on_warn=$3;
    local with_coverage=$4;
    shift; shift; shift; shift;

    # Create new test database if required
    local test_db_name="$(test_get_or_create_db $recreate_db $create_test_db)";
    local test_log_file="${LOG_DIR:-.}/odoo.test.db.$test_db_name.log";

    # Remove log file if it is present before test, otherwise
    # it will be appended, wich could lead to incorrect test results
    if [ ! -z "$test_log_file" ] && [ -e "$test_log_file" ]; then
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

# Run flake8 for modules
# test_module [--create-test-db] -m <module_name>
function test_module {
    local create_test_db=0;
    local recreate_db=0;
    local fail_on_warn=0;
    local with_coverage=0;
    local with_coverage_report_html=;
    local with_coverage_report=;
    local with_coverage_skip_covered=;
    local modules="";
    local directories="";
    local res=;
    local usage="
    Usage 

        $SCRIPT_NAME test [options] [-m <module_name>] [-m <module name>] ...
        $SCRIPT_NAME test [options] [-d <dir with addons to test>]
        $SCRIPT_NAME test flake8 <addon path> [addon path]
        $SCRIPT_NAME test pylint <addon path> [addon path]
        $SCRIPT_NAME test pylint [--disable=E111,E222,...] <addon path> [addon path]

    Options:
        --create-test-db         - Creates temporary database to run tests in
        --recreate-db            - Recreate test database if it already exists
        --fail-on-warn           - if this option passed, then tests will fail even on warnings
        --coverage               - calculate code coverage (use python's *coverage* util)
        --coverage-html          - automaticaly generate coverage html report
        --coverage-report        - print coverage report
        --coverage-skip-covered  - skip covered files in coverage report
        -m|--module              - specify module to test
        -d|--dir|--directory     - search for modules to test in specified directory
        --dir-r|--directory-r    - recursively search for modules to test in specified directory

    Examples:
        $SCRIPT_NAME test -m my_cool_module        # test single addon
        $SCRIPT_NAME test -d addon_dir             # test all addons in specified directory
        $SCRIPT_NAME test --dir-r addon_dir        # test all addons in specified directory
                                                   # and subdirectories
        $SCRIPT_NAME test pylint ./my_cool_module  # check addon with pylint
        $SCRIPT_NAME test flake8 ./my_cool_module  # check addon with flake8
        $SCRIPT_NAME test style ./my_cool_module   # run stylelint standard checks for addon
        
    ";

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options/commands supplied $#: $@";
        echo "$usage";
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --create-test-db)
                create_test_db=1;
            ;;
            --recreate-db)
                recreate_db=1;
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
            --coverage-skip-covered)
                with_coverage_skip_covered=1
            ;;
            -m|--module)
                modules="$modules $2";  # add module to module list
                shift;
            ;;
            -d|--dir|--directory)
                modules="$modules $(addons_list_in_directory --installable --by-name $2)";
                shift;
            ;;
            --dir-r|--directory-r)
                modules="$modules $(addons_list_in_directory --recursive --installable --by-name $2)";
                shift;
            ;;
            flake8)
                shift;
                echoe -e "${YELLOWC}WARNING${NC}: 'odoo-helper test flake8' is deprecated. Use 'odoo-helper lint flake8' instead.";
                lint_run_flake8 $@;
                return;
            ;;
            pylint)
                shift;
                echoe -e "${YELLOWC}WARNING${NC}: 'odoo-helper test pylint' is deprecated. Use 'odoo-helper lint pylint' instead.";
                lint_run_pylint $@;
                return;
            ;;
            *)
                echo "Unknown option: $key";
                return 1;
            ;;
        esac;
        shift;
    done;

    # Run tests
    if test_run_tests ${recreate_db:-0} ${create_test_db:-0} \
        ${fail_on_warn:-0} ${with_coverage:-0} $modules;
    then
        res=0;
    else
        res=1
    fi

    if [ ! -z "$with_coverage_report_html" ]; then
        if [ ! -z $with_coverage_skip_covered ]; then
            execv coverage html --skip-covered;
        else
            execv coverage html;
        fi
    fi

    if [ ! -z "$with_coverage_report" ]; then
        if [ ! -z $with_coverage_skip_covered ]; then
            execv coverage report --skip-covered;
        else
            execv coverage report;
        fi
    fi
    # ---------

    return $res;
}

