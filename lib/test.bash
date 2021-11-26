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
# test_get_or_create_db [--recreate-db] [--create-test-db] [--test-db-name <dbname>]
function test_get_or_create_db {
    local recreate_db;
    local create_test_db;
    local test_db_name;
    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            --create-test-db)
                create_test_db=1;
            ;;
            --recreate-db)
                recreate_db=1;
            ;;
            --test-db-name)
                test_db_name="$2";
                shift;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done;

    if [ -n "$create_test_db" ]; then
        test_db_name="test-$(< /dev/urandom tr -dc a-z0-9 | head -c24)";
        recreate_db=1;
    elif [ -z "$test_db_name" ]; then
        test_db_name=$(odoo_conf_get_test_db)
    fi

    if [ -n "$recreate_db" ] && odoo_db_exists -q "$test_db_name"; then
        if ! odoo_db_drop --conf "$ODOO_TEST_CONF_FILE" "$test_db_name" 1>&2; then
            return 2;
        fi
        if ! odoo_db_create --demo "$test_db_name" "$ODOO_TEST_CONF_FILE" 1>&2; then
            return 1;
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
               -e "Comparing apples and oranges" \
               -e "WARNING $test_db_name odoo.modules.loading: Module [a-zA-Z0-9_]\+ demo data failed to install, installed without demo data" \
               -e "WARNING $test_db_name odoo.models: [a-zA-Z0-9\\._]\+.create() includes unknown fields" \
               -e "WARNING $test_db_name odoo.models: [a-zA-Z0-9\\._]\+.write() includes unknown fields" \
               -e "WARNING $test_db_name odoo.addons.base.models.ir_ui_view: The group [a-zA-Z0-9\\._]\+ defined in view [a-zA-Z0-9\\._]\+ [a-z]\+ does not exist!" \
               -e "WARNING $test_db_name odoo.modules.registry: [a-zA-Z0-9\\._]\+: inconsistent 'compute_sudo' for computed fields" \
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
        odoo_db_drop --conf "$ODOO_TEST_CONF_FILE" "$test_db_name";
    fi

    exit 1;  # TODO: Use return here?
}


# Run tests
# test_run_tests [--recreate-db] [--create-test-db] [--fail-on-warn] [--with-coverage] <modules>
function test_run_tests {
    local db_name_options=();
    local create_test_db=0;
    local fail_on_warn=0;
    local with_coverage=0;
    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            --create-test-db)
                create_test_db=1;
                db_name_options+=( --create-test-db );
            ;;
            --recreate-db)
                db_name_options+=( --recreate-db );
            ;;
            --test-db-name)
                db_name_options+=( --test-db-name "$2" );
                shift;
            ;;
            --fail-on-warn)
                fail_on_warn=1;
            ;;
            --with-coverage)
                with_coverage=1;
            ;;
            *)
                break;
            ;;
        esac;
        shift;
    done;

    local res=0;
    local test_db_name;
    local test_log_file;

    # Create new test database if required
    test_db_name=$(test_get_or_create_db "${db_name_options[@]}");
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
        odoo_db_drop --conf "$ODOO_TEST_CONF_FILE" "$test_db_name";
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
    echo -e "${LBLUEC}HINT${NC}: Use following command to see log file: ${YELLOWC}less +G '$test_log_file'${NC}.";
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
    local create_test_db;
    local recreate_db;
    local fail_on_warn;
    local with_coverage;
    local with_coverage_report_html;
    local with_coverage_report_html_view
    local with_coverage_report_html_dir;
    local with_coverage_report;
    local with_coverage_skip_covered;
    local with_coverage_ignore_errors;
    local modules_list;
    local modules=( );
    local module;
    local module_name;
    local skip_addon;
    local skip_addon_re_list=( );
    local skip_addon_list;
    local run_tests_options=();
    local res=;

    # Modules map if there is module in this map, than it have to be skipped
    declare -A skip_modules_map;

    with_coverage_report_html_dir="$(pwd)/htmlcov";

    local usage="
    Run tests for addons

    Usage 

        $SCRIPT_NAME test [options] [-m <module_name>] [-m <module name>] ...
        $SCRIPT_NAME test [options] [-d <dir with addons to test>]
        $SCRIPT_NAME test flake8 <addon path> [addon path]
        $SCRIPT_NAME test pylint <addon path> [addon path]
        $SCRIPT_NAME test pylint [--disable=E111,E222,...] <addon path> [addon path]

    Options:
        --create-test-db               - Creates temporary database to run tests in
        --recreate-db                  - Recreate test database if it already exists
        --test-db-name <dbname>        - Use specific name for test database
        --tdb <dbname>                 - Shortcut for --test-db-name
        --fail-on-warn                 - if this option passed, then tests will fail even on warnings
        --coverage                     - calculate code coverage (use python's *coverage* util)
        --coverage-html                - automaticaly generate coverage html report
        --coverage-html-dir <dir>      - Directory to save coverage report to. Default: ./htmlcov
        --coverage-html-view           - Open coverage report in browser
        --coverage-report              - print coverage report
        --coverage-skip-covered        - skip covered files in coverage report
        --coverage-fail-under <value>  - fail if coverage is less then specified value
        --coverage-ignore-errors       - Ignore errors for coverage report
        -m|--module <module>           - specify module to test
        -d|--dir|--directory <dir>     - search for modules to test in specified directory
        --dir-r|--directory-r <dir>    - recursively search for modules to test in specified directory
        --skip <path or name>          - skip addons specified by path or name.
                                         could be specified multiple times.
        --skip-re <regex>              - skip addons that match specified regex.
                                         could be specified multiple times.
        --time                         - measure test execution time

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
                run_tests_options+=( --create-test-db );
            ;;
            --recreate-db)
                run_tests_options+=( --recreate-db );
            ;;
            --tdb|--test-db-name)
                run_tests_options+=( --test-db-name "$2" );
                shift;
            ;;
            --fail-on-warn)
                run_tests_options+=( --fail-on-warn );
            ;;
            --coverage)
                with_coverage=1;
            ;;
            --coverage-html)
                with_coverage=1;
                with_coverage_report_html=1;
            ;;
            --coverage-html-dir)
                with_coverage=1;
                with_coverage_report_html=1;
                with_coverage_report_html_dir=$(readlink -f "$2");
                shift;
            ;;
            --coverage-html-view)
                with_coverage=1;
                with_coverage_report_html=1;
                with_coverage_report_html_view=1;
            ;;
            --coverage-report)
                with_coverage=1;
                with_coverage_report=1;
            ;;
            --coverage-skip-covered)
                with_coverage=1;
                with_coverage_report=1;
                with_coverage_skip_covered=1
            ;;
            --coverage-fail-under)
                with_coverage=1;
                with_coverage_report=1;
                with_coverage_fail_under="$2";
                shift;
            ;;
            --coverage-ignore-errors)
                with_coverage_ignore_errors=1;
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
            --skip-re)
                skip_addon_re_list+=( "$2" );
                shift;
            ;;
            --time)
                measure_test_time=1;
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

    if [ -n "$with_coverage" ]; then
        run_tests_options+=( --with-coverage );
    fi

    local modules_to_test=( );
    for module in "${modules[@]}"; do
        if [ -n "$module" ]; then
            local to_skip=0;
            for skip_addon_re in "${skip_addon_re_list[@]}"; do
                if [[ "$module" =~ $skip_addon_re ]]; then
                    echoe -e "${BLUEC}Skipping addon ${YELLOWC}${module}${NC}";
                    to_skip=1;
                    break;
                fi
            done
            if [ "$to_skip" -eq 0 ] && [ -z "${skip_modules_map[$module]}" ]; then
                modules_to_test+=( "$module" );
            fi
        fi
    done

    # Print warning and return if there is no modules specified
	if [ -z "${modules_to_test[*]}" ]; then
        echo -e "${YELLOWC}WARNING${NC}: There is no addons to test";
		return 0;
	fi

    _test_check_conf_options;

    # Run tests
    if [ -n "$measure_test_time" ] && time test_run_tests "${run_tests_options[@]}" "${modules_to_test[@]}"; then
        res=0;
    elif [ -z "$measure_test_time" ] && test_run_tests "${run_tests_options[@]}" "${modules_to_test[@]}"; then
        res=0;
    else
        res=1;
    fi

    if [ -n "$with_coverage_report_html" ]; then
        if [ -n "$with_coverage_skip_covered" ]; then
            execv coverage html --directory "$with_coverage_report_html_dir" --skip-covered;
        else
            execv coverage html --directory "$with_coverage_report_html_dir";
        fi
        echoe -e "${LBLUEC}HINT${NC}: Coverage report saved at ${YELLOWC}${with_coverage_report_html_dir}${NC}";
        echoe -e "${LBLUEC}HINT${NC}: Just open url (${YELLOWC}file://${with_coverage_report_html_dir}/index.html${NC}) in browser to view coverage report.";

        if [ -n "$with_coverage_report_html_view" ]; then
            if ! check_command xdg-open >/dev/null 2>&1; then
                echoe -e "${REDC}ERROR${NC}: ${YELLOWC}xdg-open${NC} not installed.";
            else
                xdg-open "file://${with_coverage_report_html_dir}/index.html";
            fi
        fi
    fi

    if [ -n "$with_coverage_report" ]; then
        local coverage_report_opts=( );
        if [ -n "$with_coverage_skip_covered" ]; then
            coverage_report_opts+=( --skip-covered );
        fi
        if [ -n "$with_coverage_fail_under" ]; then
            coverage_report_opts+=( "--fail-under=$with_coverage_fail_under" );
        fi
        if [ -n "$with_coverage_ignore_errors" ]; then
            coverage_report_opts+=( "--ignore-errors" );
        fi
        execv coverage report "${coverage_report_opts[@]}";
    fi

    return $res;
}
