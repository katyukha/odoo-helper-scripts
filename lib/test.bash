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
    echo -e "${LBLUEC}Running server [${YELLOWC}test${LBLUEC}][${YELLOWC}coverage:${with_coverage}${BLUEC}]${NC}: $*";

    # enable test coverage
    if [ "$with_coverage" -eq 1 ]; then
        server_run --coverage --test-conf -- --stop-after-init --workers=0 "$@";
    else
        server_run --test-conf -- --stop-after-init --workers=0 "$@";
    fi
}

# test_module_impl <with_coverage 0|1> <modules> [extra_options]
# example: test_module_impl base,mail -d test1
#
# param modules - is coma-separated list of addons to be tested
#
# extra_options will be directly passed to Odoo server
function test_module_impl {
    local with_coverage=$1
    local modules=$2
    shift; shift;  # all next arguments will be passed to server

    # Install module
    if ! test_run_server "$with_coverage" --init="$modules" --log-level=warn "$@"; then
        return $?;
    fi

    # Test module
    if ! test_run_server "$with_coverage" --update="$modules" \
        --log-level=info --test-enable "$@"; then
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
    local test_db_name;

    if [ "$create_test_db" -eq 1 ]; then
        test_db_name="test-$(< /dev/urandom tr -dc a-z0-9 | head -c24)";
        if ! odoo_db_create --demo "$test_db_name" "$ODOO_TEST_CONF_FILE" 1>&2; then
            return 1;
        fi
    else
        test_db_name=$(odoo_get_conf_val db_name "$ODOO_TEST_CONF_FILE");
        if [ -z "$test_db_name" ]; then
            test_db_name=$(odoo_get_conf_val_default db_user odoo "$ODOO_TEST_CONF_FILE");
            test_db_name="$test_db_name-odoo-test";
        fi
    fi

    if [ "$recreate_db" -eq 1 ] && odoo_db_exists -q "$test_db_name"; then
        if ! odoo_db_drop "$test_db_name" "$ODOO_TEST_CONF_FILE" 1>&2; then
            return 2;
        fi
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

    local modules;
    modules=$(join_by , "$@");

    if [ -z "$modules" ]; then
        echo -e "${REDC}ERROR:${NC} No modules supplied";
        return 1;
    fi

    if [ -z "$test_db_name" ]; then
        echo -e "${REDC}ERROR:${NC} No database name supplierd!";
        return 1;
    fi

    echo -e "${BLUEC}Testing modules $modules...${NC}";
    test_module_impl "$with_coverage" "$modules" --database "$test_db_name" \
        2>&1 | tee -a "$test_log_file";
}


# Parse log file
# test_parse_log_file <test_db_name> <log_file> [fail_on_warn]
function test_parse_log_file {
    local test_db_name=$1;
    local test_log_file=$2;
    local fail_on_warn=$3;
    # remove color codes from log file
    sed -ri "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" "$test_log_file";

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
    if [ "$res" -eq 0 ] && [ "$warnings" -ne 0 ] && [ "$fail_on_warn" -eq 1 ]; then
        res=1
    fi

    return $res
    
}

# Function to handle Keyboard Interrupt while test.
# Primary reason for this is to clean up database if it was created for test
function test_run_tests_handle_sigint {
    local create_test_db=$1;
    local test_db_name=$2

    if [ "$create_test_db" -eq 1 ] && odoo_db_exists "$test_db_name"; then
        odoo_db_drop "$test_db_name" "$ODOO_TEST_CONF_FILE";
    fi

    exit 1;  # TODO: Use return here?
}


# Run tests
# test_run_tests <recreate_db 1|0> <create_test_db 1|0> <fail_on_warn 1|0> <with_coverage 1|0> <modules>
function test_run_tests {
    local recreate_db=$1;
    local create_test_db=$2;
    local fail_on_warn=$3;
    local with_coverage=$4;
    shift; shift; shift; shift;

    local res=0;
    local test_db_name;
    local test_log_file;

    # Create new test database if required
    test_db_name=$(test_get_or_create_db "$recreate_db" "$create_test_db");
    if [ -z "$test_db_name" ]; then
        echoe -e "${REDC}ERROR${NC} Cannot use or create test database!";
        return 1;
    fi
    test_log_file="${LOG_DIR:-.}/odoo.test.db.$test_db_name.log";

    # Remove log file if it is present before test, otherwise
    # it will be appended, wich could lead to incorrect test results
    if [ -n "$test_log_file" ] && [ -e "$test_log_file" ]; then
        rm "$test_log_file";
    fi

    # TODO: Set up global handlers to remove temporary
    # databases on SIGINT, ERR, ETC. And tests, translations, etc
    # could just add names of created databases to that global array
    #
    # shellcheck disable=SC2064
    trap "test_run_tests_handle_sigint $create_test_db $test_db_name" SIGINT;

    if ! test_run_tests_for_modules "$with_coverage" "$test_db_name" "$test_log_file" "$@"; then
        res=2
    fi

    # Combine test coverage results
    if [ "$with_coverage" -eq 1 ]; then
        execv coverage combine;
    fi

    # Drop created test db
    if [ "$create_test_db" -eq 1 ]; then
        echo  -e "${BLUEC}Droping test database: ${YELLOWC}${test_db_name}${NC}";
        odoo_db_drop "$test_db_name" "$ODOO_TEST_CONF_FILE"
    fi

    if [ "$res" -eq 2 ]; then
        echo -e "${REDC}ERROR${NC}: Some error happened during test!";
    elif ! test_parse_log_file "$test_db_name" "$test_log_file" "$fail_on_warn"; then
        echo -e "TEST RESULT: ${REDC}FAIL${NC}";
        res=1;
    else
        echo -e "TEST RESULT: ${GREENC}OK${NC}";
        res=0;
    fi
    return $res
}


function _test_check_conf_options {
    local dbname;
    local dbfilter;
    dbname=$(odoo_get_conf_val "db_name" "$ODOO_TEST_CONF_FILE")
    dbfilter=$(odoo_get_conf_val "db_filter" "$ODOO_TEST_CONF_FILE")
    if [ -n "$dbname" ]; then
        echoe -e "${YELLOWC}WARNING${NC}: Test conf ${BLUEC}${ODOO_TEST_CONF_FILE}${NC} contains ${BLUEC}db_name${NC} option, which may deny to drop test databases. Now it is set to ${YELLOWC}${dbname}${NC}";
    fi
    if [ -n "$dbfilter" ]; then
        echoe -e "${YELLOWC}WARNING${NC}: Test conf ${BLUEC}${ODOO_TEST_CONF_FILE}${NC} contains ${BLUEC}db_filter${NC} option, which may deny to drop test databases. Now it is set to ${YELLOWC}${dbname}${NC}";
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
    local modules_list;
    local modules=( );
    local module;
    local module_name;
    local skip_addon;
    local skip_addon_list;
    local res=;

    # Modules map if there is module in this map, than it have to be skipped
    declare -A skip_modules_map;

    local usage="
    Run tests for addons

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
        --skip <path or name>    - skip addons specified by path or name.
                                   could be specified multiple times.

    Examples:
        $SCRIPT_NAME test -m my_cool_module        # test single addon
        $SCRIPT_NAME test -d addon_dir             # test all addons in specified directory
        $SCRIPT_NAME test --dir-r addon_dir        # test all addons in specified directory
                                                   # and subdirectories

    Notes:
        To handle coverage right, it is recommended to run tests
        being inside repository root directory or inside addon root directory,
        because, by default, only files in current working directory included
        in coverage report.
        Default test database name usualy computed as:
        - value of 'db_name' param in test config file (confs/odoo.test.conf)
        - '{db_user}-odoo-test'

    ";

    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options/commands supplied $#: $*";
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
                if ! addons_is_odoo_addon "$2"; then
                    echoe -e "${REDC}ERROR${NC}: ${YELLOWC}${2}${NC} is not Odoo addon!";
                    return 1;
                else
                    module_name=$(addons_get_addon_name "$2");
                    modules+=( "$module_name" );  # add module to module list
                fi
                shift;
            ;;
            -d|--dir|--directory)
                mapfile -t modules_list < <(addons_list_in_directory --installable --by-name "$2");
                modules+=( "${modules_list[@]}" );
                shift;
            ;;
            --dir-r|--directory-r)
                mapfile -t modules_list < <(addons_list_in_directory --recursive --installable --by-name "$2");
                modules+=( "${modules_list[@]}" );
                shift;
            ;;
            --skip)
                if addons_is_odoo_addon "$2"; then
                    skip_addon=$(addons_get_addon_name "$2");
                    echoe -e "${BLUEC}Skipping addon ${YELLOWC}${skip_addon}${NC}";
                    skip_modules_map[$skip_addon]=1;
                else
                    mapfile -t skip_addon_list < <(addons_list_in_directory --recursive --installable --by-name "$2");
                    for skip_addon in "${skip_addon_list[@]}"; do
                        echoe -e "${BLUEC}Skipping addon ${YELLOWC}${skip_addon}${NC}";
                        skip_modules_map["$skip_addon"]=1;
                    done
                fi
                shift;
            ;;
            *)
                if addons_is_odoo_addon "$key"; then
                    module_name=$(addons_get_addon_name "$key");
                    modules+=( "$module_name" );
                else
                    echo "Unknown option: $key";
                    return 1;
                fi
            ;;
        esac;
        shift;
    done;

    local modules_to_test=( );
    for module in "${modules[@]}"; do
        if [ -z "${skip_modules_map[$module]}" ]; then
            modules_to_test+=( "$module" );
        fi
    done

    # Print warning and return if there is no modules specified
	if [ -z "${modules_to_test[*]}" ]; then
        echo -e "${YELLOWC}WARNING${NC}: There is no addons to test";
		return 0;
	fi

    _test_check_conf_options;

    # Run tests
    if test_run_tests "${recreate_db:-0}" "${create_test_db:-0}" \
        "${fail_on_warn:-0}" "${with_coverage:-0}" "${modules_to_test[@]}";
    then
        res=0;
    else
        res=1
    fi

    if [ -n "$with_coverage_report_html" ]; then
        if [ -n "$with_coverage_skip_covered" ]; then
            execv coverage html --skip-covered;
        else
            execv coverage html;
        fi
    fi

    if [ -n "$with_coverage_report" ]; then
        if [ -n "$with_coverage_skip_covered" ]; then
            execv coverage report --skip-covered;
        else
            execv coverage report;
        fi
    fi
    # ---------

    return $res;
}

