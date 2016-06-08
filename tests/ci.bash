# Prepare for test (if running on CI)
if [ ! -z $CI_RUN ]; then
    echo "Running as in CI environment";
    export ALWAYS_ANSWER_YES=1;

    if ! command -v "odoo-install" >/dev/null 2>&1 || ! command -v "odoo-helper" >/dev/null 2>&1; then
        echo "Seems that odoo-helper-scripts were not installed correctly!";
        echo "PATH: $PATH";
        echo "Current path: $(pwd)";
        echo "Home var: $HOME";
        echo "";
        if [ -f $HOME/odoo-helper.conf ]; then
            echo "User conf: ";
            echo "$(cat $HOME/odoo-helper.conf)";
        else
            echo "User conf not found!";
        fi
        echo "";
        echo "Content of ~/.profile file:";
        echo "$(cat $HOME/.profile)";
        echo "";
        echo "Content of ~/.bashrc file:";
        echo "$(cat $HOME/.bashrc)";
        echo "";
        echo "Content of ~/.bash_profile file:";
        echo "$(cat $HOME/.bash_profile)";
        echo "";
        
    fi
    sudo pip install --upgrade pip pytz;
fi
