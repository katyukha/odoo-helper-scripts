# Copyright © 2016-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

# Prepare for test (if running on CI)
if [ ! -z $CI_RUN ]; then
    echo -e "\e[33m Running as in CI environment \e[0m";
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
    if [ -f /etc/odoo-helper.conf ]; then
        echo "Content of odoo-helper global config";
        echo $(cat /etc/odoo-helper.conf);
    fi
    if [ -f $HOME/odoo-helper.conf ]; then
        echo "Content of odoo-helper home config";
        echo $(cat $HOME/odoo-helper.conf);
    fi
else
    echo -e "\e[33m CI Environment not enabled \e[0m";

fi
