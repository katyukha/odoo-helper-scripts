if [ -z $ODOO_HELPER_LIB ]; then
    echo "Odoo-helper-scripts seems not been installed correctly.";
    echo "Reinstall it (see Readme on https://github.com/katyukha/odoo-helper-scripts/)";
    exit 1;
fi

if [ -z $ODOO_HELPER_COMMON_IMPORTED ]; then
    source $ODOO_HELPER_LIB/common.bash;
fi

# ----------------------------------------------------------------------------------------


# Prints server script name
# (depends on ODOO_BRANCH environment variable,
#  which should be placed in project config)
# Now it simply returns openerp-server
function get_server_script {
    check_command odoo.py openerp-server openerp-server.py;
}

# Internal function to run odoo server
function run_server_impl {
    local SERVER=`get_server_script`;
    echo -e "${LBLUEC}Running server${NC}: $SERVER $@";
    export OPENERP_SERVER=$ODOO_CONF_FILE;
    execu $SERVER "$@";
    unset OPENERP_SERVER;
}

# server_run <arg1> .. <argN>
# all arguments will be passed to odoo server
function server_run {
    run_server_impl "$@";
}

function server_start {
    # Check if server process is already running
    if [ -f "$ODOO_PID_FILE" ]; then
        local pid=`cat $ODOO_PID_FILE`;
        if kill -0 $pid >/dev/null 2>&1; then
            echo -e "${REDC}Server process already running. PID=${pid}.${NC}";
            exit 1;
        fi
    fi

    run_server_impl --pidfile=$ODOO_PID_FILE "$@" &
    local pid=$!;
    sleep 2;
    echo -e "${GREENC}Odoo started!${NC}";
    echo -e "PID File: ${YELLOWC}$ODOO_PID_FILE${NC}."
    echo -e "Process ID: ${YELLOWC}$pid${NC}";
}

function server_stop {
    if [ -f "$ODOO_PID_FILE" ]; then
        local pid=`cat $ODOO_PID_FILE`;
        if kill $pid; then
            sleep 2;
            echo "Server stopped.";
            rm -f $PID_FILE;
        else
            echo "Cannot kill process.";
        fi
    fi
}

function server_status {
    if [ -f "$ODOO_PID_FILE" ]; then
        local pid=`cat $ODOO_PID_FILE`;
        if kill -0 $pid >/dev/null 2>&1; then
            echo -e "${GREENC}Server process already running. PID=${pid}.${NC}";
        else
            echo -e "${YELLOWC}Pid file points to unexistent process.${NC}";
        fi
    else
        echo "Server stopped";
    fi
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
        start           - start server in background
        stop            - stop background running server
        restart         - restart background server
        status          - status of background server
        log             - open server log
        -h|--help|help  - display this message

    Options:
        --use-test-conf     - Use test configuration file for server
    ";

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                exit 0;
            ;;
            --use-test-conf)
                ODOO_CONF_FILE=$ODOO_TEST_CONF_FILE;
                echo -e "${YELLOWC}NOTE${NC}: Using test configuration file: $ODOO_TEST_CONF_FILE";
            ;;
            run)
                shift;
                server_run "$@";
                exit;
            ;;
            start)
                shift;
                server_start "$@";
                exit;
            ;;
            stop)
                shift;
                server_stop "$@";
                exit;
            ;;
            restart)
                shift;
                server_stop;
                server_start "$@";
                exit;
            ;;
            status)
                shift;
                server_status "$@";
                exit
            ;;
            log)
                shift;
                # TODO: remove backward compatability from this code
                less ${ODOO_LOG_FILE:-$LOG_DIR/odoo.log};
                exit;
            ;;
            *)
                # all nex options have to be passed to the server
                break;
            ;;
        esac;
        shift;
    done;
    server_run "$@";
    exit;
}

# odoo_py <args>
function odoo_py {
    echov -e "${LBLUEC}Running odoo.py with arguments${NC}:  $@";
    export OPENERP_SERVER=$ODOO_CONF_FILE;
    execu odoo.py "$@";
    unset OPENERP_SERVER;
}

