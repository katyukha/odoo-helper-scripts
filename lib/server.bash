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

ohelper_require 'db';
ohelper_require 'git';
ohelper_require 'addons';
ohelper_require 'odoo';
# ----------------------------------------------------------------------------------------

set -e; # fail on errors



# Prints server script name
# (depends on ODOO_BRANCH environment variable,
#  which should be placed in project config)
# Now it simply returns openerp-server
function get_server_script {
    check_command odoo-bin odoo odoo.py openerp-server openerp-server.py;
}


# Function to check server run status;
# Function echo:
#   pid - server running process <pid>
#   -1  - server stopped
#   -2  - pid file points to unexistent process
#
# server_is_running
function server_get_pid {
    if [ -f "$ODOO_PID_FILE" ]; then
        local pid;
        pid=$(cat "$ODOO_PID_FILE");
        if is_process_running "$pid"; then
            echo "$pid";
        else
            echo "-2";
        fi
    else
        echo "-1";
    fi
}


# Test if server is running
#
# server_is_running
function server_is_running {
    if [ "$(server_get_pid)" -gt 0 ]; then
        return 0;
    else
        return 1;
    fi
}


function server_log {
    less +G "$@" -- "${LOG_FILE:-$LOG_DIR/odoo.log}";
}

# server_run [options] <arg1> .. <argN>
# all arguments (except options) will be passed to odoo server
# available options
#   --test-conf
#   --coverage
function server_run {
    local usage="
    Run Odoo server in foreground

    Usage:

        $SCRIPT_NAME server run [options] -- [odoo options]

    Options:
        --test-conf     - run odoo-server with test configuration file
        --coverage      - run odoo with coverage mode enabled
        --no-unbuffer   - do not use unbuffer.
        -h|--help|help  - display this message

    Options after '--' will be passed directly to Odoo.

    For example:
        $ odoo-helper server run --test-conf -- workers=2

    For --coverage option files in current working directory will be covered
    To add customa paths use environement variable COVERAGE_INCLUDE
    ";
    local server_conf="$ODOO_CONF_FILE";
    local with_coverage=0;
    local no_unbuffer;
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            --test-conf)
                server_conf="$ODOO_TEST_CONF_FILE";
                shift;
            ;;
            --coverage)
                with_coverage=1;
                shift;
            ;;
            --no-unbuffer)
                no_unbuffer=1;
                shift;
            ;;
            --help|-h|help)
                echo "$usage";
                return 0;
            ;;
            --)
                shift;
                break;
            ;;
            *)
                break;
            ;;
        esac
    done
    local server_script;
    local server_cmd=( );
    server_script=$(get_server_script);
    if [ -n "$SERVER_RUN_USER" ]; then
        server_cmd+=( sudo -u "$SERVER_RUN_USER" -H -E -- )
    fi

    if [ "$with_coverage" -eq 1 ]; then
        local coverage_include;
        local coverage_conf;
        local coverage_cmd;
        coverage_include=${COVERAGE_INCLUDE:-"$(pwd)"/*};
        coverage_conf=$(config_get_default_tool_conf "coverage.cfg");
        if ! check_command coverage >/dev/null 2>&1; then
            echoe -e "${REDC}ERROR${NC}: command *${YELLOWC}coverage${NC}* not found." \
               " Please, run *${LBLUEC}odoo-helper install py-tools${NC}* or " \
               " *${LBLUEC}odoo-helper pip install coverage${NC}*.";
            return 1
        fi
        coverage_cmd=$(check_command coverage);
        server_cmd+=( "$coverage_cmd" run "--rcfile=$coverage_conf" "--include=$coverage_include" );
    fi
    server_cmd+=( "$server_script" );
    echo -e "${LBLUEC}Running server${NC}: ${server_cmd[*]} $*";
    if [ -n "$no_unbuffer" ]; then
        exec_conf "$server_conf" execv "${server_cmd[@]}" "$@";
    else
        exec_conf "$server_conf" execu "${server_cmd[@]}" "$@";
    fi
}

function server_start {
    local usage="
    Start Odoo server in background

    Usage:

        $SCRIPT_NAME server start [options] -- [odoo options]

    Options:
        --test-conf     - start odoo-server with test configuration file
        --coverage      - start odoo with coverage mode enabled
        --log           - open logfile after server been started
        -h|--help|help  - display this message

    Options after '--' will be passed directly to Odoo.

    For example:
        $ odoo-helper server start --test-conf -- workers=2

    For --coverage option files in current working directory will be covered
    To add customa paths use environement variable COVERAGE_INCLUDE
    ";
    local server_run_opts=( );
    while [[ $1 == -* ]]
    do
        local key="$1";
        case $key in
            --test-conf|--coverage)
                server_run_opts+=( "$key" );
                shift;
            ;;
            --log)
                local log_after_start=1;
                shift;
            ;;
            --help|-h|help)
                echo "$usage";
                return 0;
            ;;
            --)
                shift;
                break;
            ;;
            *)
                break;
            ;;
        esac
    done

    if [ -n "$INIT_SCRIPT" ]; then
        echo -e "${YELLOWC}Starting server via init script: $INIT_SCRIPT ${NC}";
        execu "$INIT_SCRIPT" start;
    else
        # Check if server process is already running
        if server_is_running; then
            echoe -e "${REDC}Server process already running.${NC}";
            return 1;
        fi

        server_run "${server_run_opts[@]}" -- --pidfile="$ODOO_PID_FILE" "$@" &

        # Wait until Odoo server started
        local odoo_pid;
        for stime in 2 4 8 16; do
            sleep "$stime";
            if [ -f "$ODOO_PID_FILE" ]; then
                odoo_pid=$(cat "$ODOO_PID_FILE");
                if [ -n "$odoo_pid" ] && is_process_running "$odoo_pid"; then
                    break
                else
                    odoo_pid=;
                fi
            fi
        done

        if [ -z "$odoo_pid" ]; then
            echoe -e "${REDC}ERROR${NC}: Cannot start odoo.";
            return 1;
        else
            echoe -e "${GREENC}Odoo started!${NC}";
            echoe -e "PID File: ${YELLOWC}${ODOO_PID_FILE}${NC}."
            echoe -e "Process ID: ${YELLOWC}${odoo_pid}${NC}";

            if [ -z "$INIT_SCRIPT" ]; then
                echoe -e "Server URL: ${BLUEC}$(odoo_get_server_url)${NC}";
            fi
        fi
    fi

    if [ -n "$log_after_start" ]; then
        server_log;
    fi
}

function server_stop {
    if [ -n "$INIT_SCRIPT" ]; then
        echoe -e "${YELLOWC}Soppting server via init script: $INIT_SCRIPT ${NC}";
        execu "$INIT_SCRIPT" stop;
    else
        local pid;
        pid=$(server_get_pid);
        if [ "$pid" -gt 0 ]; then
            if kill "$pid"; then
                # wait until server is stopped
                for stime in 2 4 6 8; do
                    if is_process_running "$pid"; then
                        # if process alive, wait a little time
                        echov "Server still running. sleeping for $stime seconds";
                        sleep "$stime";
                    else
                        break;
                    fi
                done

                # if process still alive, it seems that it is frozen, so force kill it
                if is_process_running "$pid"; then
                    kill -SIGKILL "$pid";
                    sleep 1;
                fi

                echoe -e "${GREENC}OK${NC}: Server stopped.";
                rm -f "$PID_FILE";
            else
                echoe -e "${REDC}ERROR${NC}: Cannot kill process.";
            fi
        else
            echoe -e "${YELLOWC}Server seems not to be running!${NC}"
            echoe -e "${YELLOWC}Or PID file $ODOO_PID_FILE was removed${NC}";
        fi
    fi

}

function server_status {
    if [ -n "$INIT_SCRIPT" ]; then
        echoe -e "${BLUEC}Server status via init script:${YELLOWC} $INIT_SCRIPT ${NC}";
        execu "$INIT_SCRIPT" status;
    else
        local pid;
        pid=$(server_get_pid);
        if [ "$pid" -gt 0 ]; then
            echoe -e "${GREENC}Server process already running: PID=${YELLOWC}${pid}${GREENC}.${NC}";
            if [ -z "$INIT_SCRIPT" ]; then
                echoe -e "${GREENC}Server URL:${NC} ${BLUEC}$(odoo_get_server_url)${NC}";
            fi
        elif [ "$pid" -eq -2 ]; then
            echoe -e "${YELLOWC}Pid file points to unexistent process.${NC}";
        elif [ "$pid" -eq -1 ]; then
            echoe -e "${REDC}Server stopped${NC}";
        else
            echoe -e "${REDC}Unknown server status!${NC}";
        fi
    fi
}

function server_restart {
    if [ -n "$INIT_SCRIPT" ]; then
        echoe -e "${YELLOWC}Server restart via init script: $INIT_SCRIPT ${NC}";
        execu "$INIT_SCRIPT" restart;
    else
        server_stop;
        server_start "$@";
    fi
}


# Print ps aux output for odoo-related processes
function server_ps {
    local server_script;
    server_script=$(get_server_script);
    if [ -z "$server_script" ]; then
        echo -e "${REDC}ERROR${NC}: this command should be called inside odoo-helper project"
        return 1;
    fi
    echo -e "${YELLOWC}Odoo processes:${NC}";

    # shellcheck disable=SC2009
    ps aux | grep -e "$(get_server_script)";
}

# server [options] <command> <args>
# server [options] start <args>
# server [options] stop <args>
function server_command {
    local usage="
    Manage Odoo instance

    Usage 

        $SCRIPT_NAME server [options] [command] [args]

    args - arguments that usualy will be passed forward to openerp-server script

    Commands:
        run [--help]     - run the server. if no command supply, this one will be used
        start [--help]   - start server in background
        stop             - stop background running server
        restart [--help] - restart background server
        status           - status of background server
        log              - open server log
        ps               - print running odoo processes
        -h|--help|help   - display this message

    Options:
        --use-test-conf     - Use test configuration file for server
        -u|--user           - [sudo] Name of user to run server as
    ";

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --use-test-conf)
                # TODO: do we realy need this?
                ODOO_CONF_FILE=$ODOO_TEST_CONF_FILE;
                echoe -e "${YELLOWC}NOTE${NC}: Using test configuration file: $ODOO_TEST_CONF_FILE";
            ;;
            -u|--user)
                SERVER_RUN_USER=$2;
                shift;
            ;;
            run)
                shift;
                server_run "$@";
                return;
            ;;
            start)
                shift;
                server_start "$@";
                return;
            ;;
            stop)
                shift;
                server_stop "$@";
                return;
            ;;
            restart)
                shift;
                server_restart "$@";
                return;
            ;;
            status)
                shift;
                server_status "$@";
                return
            ;;
            log)
                shift;
                server_log "$@";
                return;
            ;;
            ps)
                shift;
                server_ps;
                return;
            ;;
            *)
                # all nex options have to be passed to the server
                break;
            ;;
        esac;
        shift;
    done;
    server_run "$@";
}

# odoo_py <args>
function odoo_py {
    echov -e "${LBLUEC}Running odoo.py with arguments${NC}: $*";
    server_run --no-unbuffer -- "$@"
}
