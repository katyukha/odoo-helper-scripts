# Odoo helper scripts collection

## Install

To install (in user home) just do folowing:

```bash
wget https://raw.githubusercontent.com/katyukha/odoo-helper-scripts/master/install-user.bash | bash
```

After instalation You will have ```odoo-helper-scripts``` directory inside your home directory.
And ```$HOME/odoo-helper.conf``` file wil be generated with path to odoo-helper-scripts install dir.


## Usage

And after install you will have available folowing scripts in your path:

    - odoo-install
    - odoo-helper

Each script have -h or --help option which display most relevant information about script

Look at [complete example](#complete-example)

### odoo-install

Install Odoo in specified directory in (using virtualenv)

```bash
odoo-install
```

After this You wil have odoo and it's dependencies installed into *MyOdoo* directory.
Note that installation is done only with PIP, with out need of super-user rights, but thus
system dependencies, such as libraries, compilers, \*-dev packages, etc cannot be installed.
You should install them manualy.

This installation also creates *odoo-helper.conf* file inside project, which allows to use
*odoo-helper* script to simplify interaction with this odoo installation.

Also, in case that this is source installation, you may install more than one odoo installation
on machine, thus you can use it for development of multiple addon sets, which may not work good on same odoo installation.

### odoo-helper

This script simlify interaction with odoo installs (mostly done by *odoo-install* script)

Note, that this script becomes useful when there is *odoo-helper.conf* config file could be found.
Config will be searched in folowing paths:

- */etc/default/odoo-helper.conf*  - System wide config file. May be usefule if
                                     You have only one Odoo instalation in system
- *<user home dir>/odoo-helper.conf*   - User specific config.
- *Project specific* - this config is searched in working directory and up. first one found will be used.
                     This feature allows to use *odoo-helper* with multiple odoo instances in one system

Core functionality is:

- *fetch* - which makes available to fetch module from git repository and
            install it in this installation.
            Also it may automatically fetch dependencise of module been fetched,
            if it have *odoo_requirements.txt* file inside.
- *generate_requirements* - Generates *odoo_requirements.txt* file, with list of modules
                            installed from git repositories. It checks all modules placed in
                            addons directory, which is passed as argument to this command or
                            got from odoo-helper.conf. Resulting file is suitable for *fetch_requirements command
- *server* - Contorlls odoo server of current project. run with *--help* option for more info.
- *test* - Test set of modules (```-m <module>``` option, which could be passed multiple times)
           Depending on options, may create new clean test daatabase.
           For depatis run this command with --help option$A
- *link* - link specified module directory to current addons dir. mostly used internaly
- *create_db* - allows to create database from command line
- *drop_db* - allows to drop database from commandline
- *list_db* - lists databases, available for this odoo instance

For details use *--help* option

### Syntax of odoo\_requirements.txt

*odoo_requirements.txt* parsed line by line, and each line must be just set of options to ```odoo-helper fetch``` command:

```
-r|--repo <git repository>  [-b|--branch <git branch>] [-m|--module <odoo module name>] [-n|--name <repo name>]
--requirements <requirements file>
-p|--python <python module>

```

Also there are shorter syntax for specific repository sources:

- ```--github user/repository``` for github repositories
- ```--oca repository``` of Odoo Comunity Assiciation repositories

Fore example:

```
--github katyukha/base_tags --module base_tags -b master
--oca project-service -m project_sla -b 7.0
```

For details run ```odoo-helper fetch --help```


## Complete example

```bash
odoo-install --install-dir odoo-7.0 --branch 7.0 --extra-utils
cd odoo-7.0

# Now You will have odoo-7.0 installed in this directory.
# Note, thant Odoo this odoo install uses virtual env (venv dir)
# Also You will find there odoo-helper.conf config file

# So now You may run local odoo server (i.e openerp-server script).
# Note that this command run's server in foreground.
odoo-helper server   # This will automaticaly use config file: conf/odoo.conf

# Also you may run server in background using
odoo-helper server start

# there are also few additional server related commands:
odoo-helper server status
odoo-helper server log
odoo-helper server restart
odoo-helper server stop

# Let's install base_tags addon into this odoo installation
odoo-helper fetch --github katyukha/base_tags --branch master

# Now look at custom_addons/ dir, there will be placed links to addons
# from https://github.com/katyukha/base_tags repository
# But repository itself is placed in downloads/ directory
# By default no branch specified when You fetch module,
# but there are -b or --branch option which can be used to specify which branch to fetch

# Now let's run tests for these just installed modules
odoo-helper test --create-test-db -m base_tags -m product_tags

# this will create test database (it will be dropt after test finishes) and 
# run tests for modules 'base_tags' and 'product_tags'

# If You need color output from Odoo, you may use '--use-unbuffer' option,
# but it depends on 'expect-dev' package
odoo-helper --use-unbuffer test --create-test-db -m base_tags -m product_tags

# The one cool thing of odoo-helper script, you may not remeber paths to odoo instalation,
# and if you change directory to another inside your odoo project, everything will continue to work.
cd custom_addons
odoo-helper server status
dooo-helper server restart

# So... let's install one more odoo version
# go back to directory containing our projects (that one, where odoo-7.0 project is placed)
cd ../../

# Let's install odoo of version 8.0 too here.
odoo-install --install-dir odoo-8.0 --branch 8.0 --extra-utils
cd odoo-8.0

# and install there for example addon 'project_sla' for 'project-service' Odoo Comutinty repository
# Note  that odoo-helper script will automaticaly fetch branch named as server version in current install,
# if another branch was not specified
odoo-helper fetch --oca project-service -m project_sla

# and run tests for it
odoo-helper test --create-test-db -m project_sla


# also if you want to install python packages in current installation environment, you may use command:
odoo-helper fetch -p suds  # this installs 'suds' python package

# and as one more example, let's install aeroo-reports with dependancy to aeroolib in odoo 7.0
cd ../odoo-7.0
odoo-helper fetch --github gisce/aeroo -n aeroo
odoo-helper fetch -p git+https://github.com/jamotion/aeroolib#egg=aeroolib

```
