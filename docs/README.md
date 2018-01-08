# odoo-helper-scripts documentation

At this moment, here is only basic documentation

## Basic usage

### odoo-install

Install Odoo in specified directory (using virtualenv)

```bash
sudo odoo-helper install sys-deps 11.0  # install global system dependencies for specified version of Odoo
odoo-install --odoo-version 11.0        # no sudo required
```

After this you wil have odoo and it's dependencies installed into *odoo-11.0* directory.

This installation also creates *odoo-helper.conf* file inside project, which allows to use
*odoo-helper* script to simplify interaction with this odoo installation.

### odoo-helper

This script simlify interaction with odoo installs (mostly done by *odoo-install* script)

Note, that this script becomes useful when there is *odoo-helper.conf* config file could be found.
Config will be searched in folowing paths:

- `/etc/default/odoo-helper.conf`  - System wide config file. May be usefule if
                                     You have only one Odoo instalation in system
- `<user home dir>/odoo-helper.conf`   - User specific config.
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
- *db* - manage database (create, drop, dump, restore, etc)
- *addons* - manage addons (install, update, check for updates in git repos, etc)
- *tr* - translation utils
- *postgres* - manage local postgres (create pg user, etc)

For details use *--help* option


## Complete example

```bash
# Install odoo-helper scripts pre-requirements.
# This step should be usualy ran one time, and is required to ensure that
# all odoo-helper dependencies installed.
odoo-helper install pre-requirements

# Install system dependencies for odoo version 10.0
# This option requires sudo.
odoo-helper install sys-deps 10.0;

# Install postgres and create there user with name='odoo' and password='odoo'
odoo-helper install postgres odoo odoo

# Install odoo 10.0 into 'odoo-10.0' directory
odoo-install -i odoo-10.0 --odoo-version 10.0
cd odoo-10.0

# Now You have odoo-10.0 installed in this directory.
# Note, that this odoo installation uses virtual env (venv dir)
# Also You will find there odoo-helper.conf config file

# So now You may run local odoo server (i.e openerp-server script).
# Note that this command run's server in foreground.
odoo-helper server run  # This will automaticaly use config file: conf/odoo.conf

# Press Ctrl+C to stop seerver

# To run server in backgroud use following command
odoo-helper server start

# there are also few additional server related commands:
odoo-helper server status
odoo-helper server log
odoo-helper server ps
odoo-helper server restart
odoo-helper server stop

# Also there are shourtcuts for these commands:
odoo-helper status
odoo-helper log
odoo-helper restart
odoo-helper stop

# Let's install fetch module contract from OCA repository 'contract'
# Here branch will be detected automatically
odoo-helper fetch --oca contract

# Or alternatively
odoo-helper fetch --github OCA/contract --branch 10.0

# Now look at custom_addons/ dir, there will be placed links to addons
# from https://github.com/OCA/contract repository
# But repository itself is placed in repositories/ directory

# Now let's run tests for these just installed modules
odoo-helper test --create-test-db -m contract

# this will create test database (it will be dropt after test finished) and 
# run tests for modules 'base_tags' and 'product_tags'

# Or we can run tests of whole directory, odoo-helper-scripts
# will automaticaly detect installable addons and test it
odoo-helper test -d ./repositories/contract

# This will use standard test database, that will not be dropt after tests,
# so we do not need to recreate database on each test run, which saves time

# If You need color output from Odoo, you may use '--use-unbuffer' option,
# but it depends on 'expect-dev' package.
odoo-helper --use-unbuffer test -m contract

# The one cool thing of odoo-helper script, you may not remeber paths to odoo instalation,
# and if you change directory to another inside your odoo project, everything will continue to work.
cd custom_addons
odoo-helper server status
dooo-helper server restart

# So... let's install one more odoo version
# go back to directory containing our projects (that one, where odoo-10.0 project is placed)
cd ../../

# Let's install odoo of version 8.0 here too.
# First, install system dependencies for odoo version 8.0
odoo-helper install sys-deps 8.0;

# And when system dependencies installed, install odoo itself
odoo-install --install-dir odoo-8.0 --odoo-version 8.0
cd odoo-8.0

# and install there for example addon 'project_sla' for 'project' Odoo Comutinty repository
# Note  that odoo-helper script will automaticaly fetch branch named as server version in current install,
# if another branch was not specified
odoo-helper fetch --oca project -m project_sla

# and run tests for it
odoo-helper test --create-test-db -m project_sla


# also if you want to install python packages in current installation environment, you may use command:
odoo-helper fetch -p suds  # this installs 'suds' python package

# and as one more example, let's install aeroo-reports with dependancy to aeroolib in odoo 10.0
cd ../odoo-10.0
odoo-helper fetch --github gisce/aeroo -n aeroo
odoo-helper fetch -p git+https://github.com/jamotion/aeroolib#egg=aeroolib

```
