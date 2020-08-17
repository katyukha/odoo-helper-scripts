# Copyright © 2015-2019 Dmytro Katyukha <dmytro.katyukha@gmail.com>

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

ohelper_require "config";
ohelper_require "fetch";
ohelper_require "link";
ohelper_require "server";
ohelper_require "db";
ohelper_require "test";
ohelper_require "addons";
ohelper_require "install";
ohelper_require "git";
ohelper_require "odoo";
ohelper_require "tr";
ohelper_require "postgres";
ohelper_require "system";
ohelper_require "scaffold";
ohelper_require "doc-utils";
ohelper_require "lint";
ohelper_require "ci";
# ----------------------------------------------------------------------------------------

function odoo_helper_print_usage {
    echo "
    Odoo helper script collection

    Version: $ODOO_HELPER_VERSION

    Usage:
        $SCRIPT_NAME [global options] command [command options]

    Current project settings:
        Project dir: ${PROJECT_ROOT_DIR:-'No project found'};
        Branch:      ${ODOO_BRANCH:-'Not defined'}

    Available commands:
        fetch [--help]                      - fetch and install odoo addon
        link [--help]                       - link module to custom_addons dir
        server [--help]                     - manage local odoo server (run, start, stop, etc)
        addons [--help]                     - addons related helpers
        odoo [--help]                       - Odoo utils.
        test [--help]                       - test addon
        lint [--help]                       - lint addon
        db [--help]                         - database management (list, create, drop, etc...)
        tr [--help]                         - manage translations (import, export, load, ...)
        postgres [--help]                   - manage local instance of postgresql server
        git [--help]                        - git-related commands
        ci [--help]                         - commands usefule for Continious Integration
        install [--help]                    - install related stuff (sys-deps, ...)
        doc-utils [--help]                  - subcommand that contains doc utlities
        update-odoo [--help]                - update odoo source code
        odoo-py [args]                      - run project-specific odoo.py script
        scaffold [--help]                   - Scaffold repo, addon, model, etc
        print-config                        - print current configuration
        status                              - show project status
        system [--help]                     - odoo-helper related functions
        exec <cmd> [args]                   - exec command in project environment. Useful if virtualenv is used
        pip [--oca] <pip arguments>         - shortcut to run project-specific pip.
                                              if option *--oca* is specified, then OCA wheelhouse
                                              will be used to install OCA addons.
        npm <npm arguments>                 - Run npm installed in current project's environment
        python [args]                       - Run python for this instance
        ipython [args]                      - Run ipython shell
        browse                              - Open running odoo instance in browser
        help | --help | -h                  - display this help message
        --version|version                   - display odoo-helper version and exit

    Shortcuts (aliases):
        start                               - shortcut for 'server start' commands
        stop                                - shortcut for 'server stop' commands
        restart                             - shortcut for 'server restart' commands
        log                                 - shortcut for 'server log' commands
        ps                                  - shortcut for 'server ps' command
        psql                                - shortcut for 'postgres psql' command
        pylint                              - shortcut for 'lint pylint' command
        flake8                              - shortcut for 'lint flake8' command
        style                               - shortcut for 'lint style' command
        pg                                  - shortcut for 'postgres' command
        lsa                                 - shortcut for 'addons list' command
        lsd                                 - shortcut for 'db list' command
    
    Global options:
        --use-copy                          - if set, then downloaded modules, repositories will
                                              be copied instead of being symlinked
        --use-unbuffer                      - if set, then 'unbuffer' command from 'expect' package will be used
                                              otherwise standard 'exec' will be used to run odoo server
                                              this helps to make odoo server think that it runs in terminal thus
                                              it provides colored output.
        --no-colors                         - disable colored output
        --verbose|--vv                      - show extra output

    Also global options may be set up using configuration files.
    Folowing file paths will be searched for file $CONF_FILE_NAME:
        - /etc/default/$CONF_FILE_NAME  - Default conf. there may be some general settings placed
        - $HOME/$CONF_FILE_NAME         - User specific oconf  (overwrites previous conf)
        - Project specific conf         - File $CONF_FILE_NAME will be searched in $WORKDIR and all parent
                                          directories. First one found will be used

    Configuration files are simple bash scripts that sets environment variables
";
}

function odoo_helper_show_project_tools_versions {
    local python_version;
    local node_version;
    local npm_version;
    local lessc_version;
    python_version="${BLUEC}$(execv python --version 2>&1)${NC}";
    node_version="${BLUEC}$(execv node --version 2>&1)${NC}";
    npm_version="${BLUEC}$(execv npm --version 2>&1)${NC}";
    lessc_version="${BLUEC}$(execv lessc --version 2>&1)${NC}";
    echo -e "
    Tools versions:
        Python: $python_version
        NodeJS: $node_version
        npm: $npm_version
        Less.js: $lessc_version
    ";
}

function odoo_helper_show_project_ci_tools_versions {
    local flake8_version;
    local pylint_version;
    local eslint_version;
    local pylint_odoo_version;
    local stylelint_version;
    if check_command flake8 >/dev/null 2>&1; then
        flake8_version="${BLUEC}$(execv flake8 --version 2>&1)${NC}";
    else
        flake8_version="${REDC}Not installed${NC}"
    fi

    if check_command pylint >/dev/null 2>&1; then
        pylint_version="${BLUEC}$(lint_run_pylint --version 2>&1 | tr '\n' ' ')${NC}";
    else
        pylint_version="${REDC}Not installed${NC}"
    fi

    if check_command eslint >/dev/null 2>&1; then
        eslint_version="${BLUEC}$(execv eslint --version 2>&1)${NC}";
    else
        eslint_version="${REDC}Not installed${NC}"
    fi

    if run_python_cmd "import pylint_odoo" >/dev/null 2>&1 ; then
        pylint_odoo_version=$(run_python_cmd "import pkg_resources; print(pkg_resources.get_distribution('pylint_odoo').version)");
        pylint_odoo_version="${BLUEC}${pylint_odoo_version}${NC}";
    else
        pylint_odoo_version="${REDC}Not installed${NC}";
    fi

    if check_command stylelint >/dev/null 2>&1; then
        stylelint_version="${BLUEC}$(execv stylelint --version)${NC}";
    else
        stylelint_version="${REDC}Not installed${NC}";
    fi

    echo -e "
    CI Tools versions:
        Flake8:      $flake8_version
        Pylint:      $pylint_version
        Pylint Odoo: $pylint_odoo_version
        ESLint:      $eslint_version
        Stylelint:   $stylelint_version
    ";
}

# display project status
function odoo_helper_show_project_status {
    local pid;
    local server_status;
    local server_url;
    local project_dir;
    local branch;
    local version;
    local is_git_install;
    local usage="
    Show odoo-helper project status

         $SCRIPT_NAME status [--tools-versions] [--ci-tools-versions]
    ";

    if [ -z "$PROJECT_ROOT_DIR" ]; then
        echoe -e "${REDC}ERROR${NC}: Not inside odoo-helper project!";
        return 1;
    fi
    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                echo "$usage";
                return 0;
            ;;
            --tools-versions)
                local opt_show_tools_versions=1;
            ;;
            --ci-tools-versions)
                local opt_show_ci_tools_versions=1;
            ;;
            *)
                echo "Unknown option $key";
                return 1;
            ;;
        esac;
        shift;
    done;

    if [ -n "$INIT_SCRIPT" ]; then
        server_status="run ${YELLOWC}${INIT_SCRIPT} status${NC}";
        server_url="";
    else
        pid=$(server_get_pid);
        if [ "$pid" -gt 0 ]; then
            server_status="${GREENC}Running (${YELLOWC}$pid${GREENC})${NC}";
            if [ -z "$INIT_SCRIPT" ]; then
                server_url="${BLUEC}$(odoo_get_server_url)${NC}";
            else
                server_url="";
            fi
        else
            server_status="${REDC}Stopped${NC}";
            server_url="";
        fi
    fi

    if [ -z "$PROJECT_ROOT_DIR" ]; then
        project_dir="${REDC}No project found${NC}";
    else
        project_dir="${GREENC}$PROJECT_ROOT_DIR${NC}";
    fi

    if [ -z "$ODOO_BRANCH" ]; then
        branch="${REDC}Not defined${NC}";
    else
        branch="${GREENC}$ODOO_BRANCH${NC}";
    fi

    if [ -z "$ODOO_VERSION" ]; then
        version="${REDC}Not defined${NC}";
    else
        version="${GREENC}$ODOO_VERSION${NC}";
    fi

    if [ -d "$ODOO_PATH"/.git ]; then
        is_git_install="${GREENC}Yes${NC}";
    else
        is_git_install="${YELLOWC}No${NC}";
    fi

    echo -e "
    Current project:

        Project dir:   $project_dir
        Odoo branch:   $branch
        Odoo version:  $version
        Git install:   $is_git_install
        Server status: ${server_status}
        Server URL:    ${server_url}
    ";

    if [ -n "$opt_show_tools_versions" ]; then
        odoo_helper_show_project_tools_versions;
    fi

    if [ -n "$opt_show_ci_tools_versions" ]; then
        odoo_helper_show_project_ci_tools_versions;
    fi
}

function odoo_helper_print_version {
    echo -e "Version: ${GREENC}$ODOO_HELPER_VERSION${NC}";

    if git_is_git_repo "$ODOO_HELPER_ROOT"; then
        echo -e "Branch:  ${BLUEC}$(git_get_branch_name "$ODOO_HELPER_ROOT")${NC}";
        echo -e "Commit:  ${BLUEC}$(git_get_current_commit "$ODOO_HELPER_ROOT")${NC}";
        echo -e "Date:    ${BLUEC}$(git_get_current_commit_date "$ODOO_HELPER_ROOT")${NC}";
    fi

    echo -e "Path:    ${YELLOWC}$ODOO_HELPER_ROOT${NC}";
}

function odoo_helper_browse {
    # Open odoo on browser
    local server_url;
    if [ -n "$INIT_SCRIPT" ]; then
        echoe -e "${REDC}ERROR${NC}: cannot open in browser when odoo controlled via init script";
        return 1;
    fi
    if ! check_command xdg-open >/dev/null 2>&1; then
        echoe -e "${REDC}ERROR${NC}: ${YELLOWC}xdg-open${NC} not installed.";
        return 3;
    fi
    server_url=$(odoo_get_server_url);
    if [ -z "$server_url" ]; then
        echoe -e "${REDC}ERROR${NC}: Cannot determine server url of odoo instance";
        return 4;
    fi
    if ! server_is_running; then
        echoe -e "${YELLOWC}WARNING${NC}: Odoo not started. Starting...";
        server_start;
        if ! server_is_running; then
            echoe -e "${REDC}ERROR${NC}: cannot open in browser: odoo not started";
            return 2;
        fi
    fi
    xdg-open "$server_url";
}

function odoo_helper_ipython {
    if [ ! -e "$VENV_DIR/bin/ipython" ]; then
        exec_pip install ipython;
    fi

    execv ipython "$@";
}

# function that parses commandline arguments and executes commands
function odoo_helper_main {
    # Parse command line options and run commands
    if [[ $# -lt 1 ]]; then
        echo "No options/commands supplied $#: $*";

        # load configuration files at startup
        config_load_project;

        odoo_helper_print_usage;
        return 0;
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1";
        case $key in
            -h|--help|help)
                odoo_helper_print_usage;
                return 0;
            ;;
            --version|version)
                odoo_helper_print_version;
                return 0;
            ;;
            --use-copy)
                USE_COPY=1;
            ;;
            --use-unbuffer)
                USE_UNBUFFER=1;
            ;;
            --no-colors|--no-color)
                deny_colors;
            ;;
            --verbose|--vv|-vv)
                VERBOSE=1;
            ;;
            fetch)
                shift;
                config_load_project;
                fetch_module "$@";
                return
            ;;
            generate-requirements|generate_requirements)
                shift;
                echoe -e "${YELLOWC}WARNING${NC}: this command is deprecated. Use ${BLUEC}odoo-helper addons generate-requirements${NC} instead.";
                config_load_project;
                addons_generate_requirements "$@"
                return;
            ;;
            doc-utils)
                shift;
                config_load_project;
                doc_utils_command "$@";
                return;
            ;;
            update-odoo|update_odoo)
                shift;
                config_load_project;
                odoo_update_sources "$@";
                return;
            ;;
            link|link_module)
                shift;
                config_load_project;
                link_command "$@"
                return;
            ;;
            server)
                shift;
                config_load_project;
                server_command "$@";
                return;
            ;;
            addons)
                shift;
                config_load_project;
                addons_command "$@";
                return;
            ;;
            odoo)
                shift;
                config_load_project;
                odoo_command "$@";
                return;
            ;;
            odoo-py)
                shift;
                config_load_project;
                odoo_py "$@";
                return;
            ;;
            scaffold)
                shift;
                config_load_project;
                scaffold_parse_cmd "$@";
                return;
            ;;
            test)
                shift;
                config_load_project;
                test_module "$@";
                return;
            ;;
            lint)
                shift;
                config_load_project;
                lint_command "$@";
                return;
            ;;
            db)
                shift;
                config_load_project;
                odoo_db_command "$@";
                return;
            ;;
            tr)
                shift;
                config_load_project;
                tr_main "$@";
                return;
            ;;
            postgres|pg)
                shift;
                postgres_command "$@";
                return;
            ;;
            git)
                shift;
                git_command "$@";
                return;
            ;;
            ci)
                shift;
                config_load_project;
                ci_command "$@";
                return;
            ;;
            psql)
                shift;
                postgres_command psql "$@";
                return;
            ;;
            install)
                shift;
                install_entry_point "$@";
                return;
            ;;
            print-config)
                shift;
                config_load_project;
                config_print;
                return;
            ;;
            status)
                shift;
                config_load_project;
                odoo_helper_show_project_status "$@";
                return;
            ;;
            system)
                shift;
                system_entry_point "$@";
                return;
            ;;
            # Server shortcuts
            start|stop|restart|log|ps)
                config_load_project;
                server_command "$@";
                return;
            ;;
            # Lint shortcuts
            pylint|flake8|style)
                config_load_project;
                lint_command "$@";
                return;
            ;;
            lsa)
                shift;
                config_load_project;
                addons_list_in_directory --by-name "$@";
                return;
            ;;
            lsd)
                shift;
                config_load_project;
                odoo_db_list "$@";
                return;
            ;;
            exec)
                shift;
                config_load_project;
                if [ -n "$ODOO_CONF_FILE" ]; then
                    exec_conf "$ODOO_CONF_FILE" execv "$@";
                else
                    execv "$@";
                fi
                return 0;
            ;;
            pip)
                shift;
                config_load_project;
                exec_pip "$@";
                return 0;
            ;;
            npm)
                shift;
                config_load_project;
                exec_npm "$@";
                return 0;
            ;;
            python)
                shift;
                config_load_project;
                exec_py "$@";
                return 0;
            ;;
            ipython)
                shift;
                config_load_project;
                odoo_helper_ipython "$@";
            ;;
            browse)
                shift;
                config_load_project;
                odoo_helper_browse "$@";
            ;;
            *)
                echo "Unknown option global option /command $key";
                return 1;
            ;;
        esac;
        shift;
    done;
}
