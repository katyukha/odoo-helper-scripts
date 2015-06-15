# Odoo helper scripts collection

## Install

To install just do folowing:

```bash
# Clone repository to heme directory
git clone https://github.com/katyukha/odoo-helper-scripts.git $HOME/odoo-helper-scripts

# And add path to it to the system PATH
echo "
PATH=\$PATH:\$HOME/odoo-helper-scripts/bin/
" >> $HOME/.bashrc
```

## Usage

And after nstall you will have available folowing scripts in your path:

    - odoo-install
    - odoo-helper

Each script have -h or --help option which display most relevant information about script

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

Core functionality is:

    - *fetch_module* - which makes available to fetch module from git repository and install it in this installation.
      Also it may automatically fetch dependencise of module been fetched, if it heve *odoo_requirements.txt* file inside.
    - *fetch_requirements* - which can process *odoo_requirements.txt* files
    - *run_server*
    - *test_module*
    - *create_db*
    - *drop_db*
    - *list_db*

The main advantage of using this scripts is that it looks for config file in working
directory and up to get information about odoo-installation, and thus you do not need to worry
about path, your odoo installed in.

### odoo\_requirements.txt

*odoo_requirements.txt* parsed line by line, and each line must be just set of options to ```odoo-helper fetch_module``` command:

```
-r|--repo <git repository> [-m|--module <odoo module name>] [-n|--name <repo name>] [-b|--branch <git branch>]
--requirements <requirements file>
-p|--python <python module>

```

Also there are shorter syntax for specific repository sources:

- ```--github user/repository``` for github repositories
- ```--oca repository``` of odoo comunity repositories

Fore example:

```
--github katyukha/base_tags --module base_tags -b master
--oca project-service -m project_sla -b 7.0
```

For details run ```odoo-helper fetch_module --help```
