# Copyright © 2015-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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
        local pid=`cat $ODOO_PID_FILE`;
        if is_process_running $pid; then
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
    if [ $(server_get_pid) -gt 0 ]; then
        return 0;
    else
        return 1;
    fi
}


function server_log {
    less +G $@ -- ${LOG_FILE:-$LOG_DIR/odoo.log};
}

# server_run <arg1> .. <argN>
# all arguments will be passed to odoo server
function server_run {
    local SERVER=`get_server_script`;
    echo -e "${LBLUEC}Running server${NC}: $SERVER $@";
    if [ ! -z $SERVER_RUN_USER ]; then
        local sudo_opt="sudo -u $SERVER_RUN_USER -H -E";
        echov "Using server run opt: $sudo_opt";
    fi

    exec_conf $ODOO_CONF_FILE execu "$sudo_opt $SERVER $@";
}

function server_start {
    if [ "$1" == "--log" ]; then
        local log_after_start=1;
        shift;
    fi

    if [ ! -z $INIT_SCRIPT ]; then
        echo -e "${YELLOWC}Starting server via init script: $INIT_SCRIPT ${NC}";
        execu $INIT_SCRIPT start;
    else
        # Check if server process is already running
        if server_is_running; then
            echoe -e "${REDC}Server process already running.${NC}";
            return 1;
        fi

        server_run --pidfile=$ODOO_PID_FILE "$@" &

        # Wait until Odoo server started
        local odoo_pid=;
        for stime in 2 4 8 16; do
            sleep $stime;
            if [ -f $ODOO_PID_FILE ]; then
                odoo_pid=$(cat $ODOO_PID_FILE);
                if [ ! -z $odoo_pid ] && is_process_running $odoo_pid; then
                    break
                else
                    odoo_pid=;
                fi
            fi
        done

        if [ -z $odoo_pid ]; then
            echoe -e "${REDC}ERROR${NC}: Cannot start odoo.";
            return 1;
        else
            echoe -e "${GREENC}Odoo started!${NC}";
            echoe -e "PID File: ${YELLOWC}${ODOO_PID_FILE}${NC}."
            echoe -e "Process ID: ${YELLOWC}${odoo_pid}${NC}";

            if [ -z "$INIT_SCRIPT" ]; then
                echoe -e "Server URL: ${BLUEC}$(odoo_gen_server_url)${NC}";
            fi
        fi
    fi

    if [ ! -z $log_after_start ]; then
        server_log;
    fi
}

function server_stop {
    if [ ! -z $INIT_SCRIPT ]; then
        echoe -e "${YELLOWC}Soppting server via init script: $INIT_SCRIPT ${NC}";
        execu $INIT_SCRIPT stop;
    else
        local pid=$(server_get_pid);
        if [ $pid -gt 0 ]; then
            if kill $pid; then
                # wait until server is stopped
                for stime in 2 4 6 8; do
                    if is_process_running $pid; then
                        # if process alive, wait a little time
                        echov "Server still running. sleeping for $stime seconds";
                        sleep $stime;
                    else
                        break;
                    fi
                done

                # if process still alive, it seems that it is frozen, so force kill it
                if is_process_running $pid; then
                    kill -SIGKILL $pid;
                    sleep 1;
                fi

                echoe -e "${GREENC}OK${NC}: Server stopped.";
                rm -f $PID_FILE;
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
    if [ ! -z $INIT_SCRIPT ]; then
        echoe -e "${BLUEC}Server status via init script:${YELLOWC} $INIT_SCRIPT ${NC}";
        execu $INIT_SCRIPT status;
    else
        local pid=$(server_get_pid);
        if [ $pid -gt 0 ]; then
            echoe -e "${GREENC}Server process already running: PID=${YELLOWC}${pid}${GREENC}.${NC}";
            if [ -z "$INIT_SCRIPT" ]; then
                echoe -e "${GREENC}Server URL:${NC} ${BLUEC}$(odoo_gen_server_url)${NC}";
            fi
        elif [ $pid -eq -2 ]; then
            echoe -e "${YELLOWC}Pid file points to unexistent process.${NC}";
        elif [ $pid -eq -1 ]; then
            echoe -e "${REDC}Server stopped${NC}";
        else
            echoe -e "${REDC}Unknown server status!${NC}";
        fi
    fi
}

function server_restart {
    if [ "$1" == "--log" ]; then
        local log_after_start=1;
        shift;
    fi

    if [ ! -z $INIT_SCRIPT ]; then
        echoe -e "${YELLOWC}Server restart via init script: $INIT_SCRIPT ${NC}";
        execu $INIT_SCRIPT restart;
    else
        server_stop;
        server_start "$@";
    fi

    if [ ! -z $log_after_start ]; then
        server_log;
    fi
}


# WARN: only for odoo 8.0+
# Update odoo sources
function server_auto_update {
    # Stop odoo server
    if server_is_running; then
        echoe -e "${BLUEC}Stopping server...${NC}";
        server_stop;
        local need_start=1;
    fi

    # Do database backup
    odoo_db_backup_all zip;

    # Update odoo sources
    odoo_update_sources;

    echoe -e "${BLUEC}update databases...${NC}";
    addons_install_update "update" all;

    # Start server again if it was stopped
    if [ ! -z $need_start ]; then
        echoe -e "${BLUEC}Starting server...${NC}";
        server_start;
    fi
}

# Print ps aux output for odoo-related processes
function server_ps {
    local server_script=$(get_server_script);
    if [ -z "$server_script" ]; then
        echo -e "${REDC}ERROR${NC}: this command should be called inside odoo-helper project"
        return 1;
    fi
    echo -e "${YELLOWC}Odoo processes:${NC}";
    ps aux | grep -e "$(get_server_script)";
}

# server [options] <command> <args>
# server [options] start <args>
# server [options] stop <args>
function server {
    local usage="
    Usage 

        $SCRIPT_NAME server [options] [command] [args]

    args - arguments that usualy will be passed forward to openerp-server script

    Commands:
        run             - run the server. if no command supply, this one will be used
        start [--log]   - start server in background
        stop            - stop background running server
        restart [--log] - restart background server
        status          - status of background server
        auto-update     - automatiacly update server. (WARN: experimental feature. may be buggy)
        log             - open server log
        ps              - print running odoo processes
        -h|--help|help  - display this message

    Options:
        --use-test-conf     - Use test configuration file for server
        -u|--user           - Name of user to run server as
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
                ODOO_CONF_FILE=$ODOO_TEST_CONF_FILE;
                echo -e "${YELLOWC}NOTE${NC}: Using test configuration file: $ODOO_TEST_CONF_FILE";
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
            auto-update)
                shift;
                server_auto_update "$@";
                return;
            ;;
            log)
                shift;
                # TODO: remove backward compatability from this code
                server_log;
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
    echov -e "${LBLUEC}Running odoo.py with arguments${NC}:  $@";
    local cmd=$(check_command odoo odoo-bin odoo.py);
    exec_conf $ODOO_CONF_FILE execu $cmd "$@";
}

