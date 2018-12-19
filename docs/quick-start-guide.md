# Quick Start Guide

This is quick start guide for *odoo-helper-scripts*.

## Install odoo-helper scripts

For full list of installation options look at [installation documentation](./installation.md)

To install *odoo-helper-scripts* system-wide do folowing:

```bash
wget -O - https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash | sudo bash -s
```

or more explicit way:

```bash
# Download installation script
wget -O /tmp/odoo-helper-install.bash https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash;

# Install odoo-helper-scripts
sudo bash /tmp/odoo-helper-install.bash;
```

## Install dependencies

Ensure *odoo-helper-scripts* pre-requirements are installed
This step should be usualy ran one time.
It installs dependencies of *odoo-helper-scripts* itself and common odoo dependencies.

```bash
odoo-helper install pre-requirements
```

Install system dependencies for specific Odoo version (in this example *11.0*)
Note, that this option requires *sudo*.

```bash
odoo-helper install sys-deps 11.0;
```

Install [PostgreSQL Server](https://www.postgresql.org/) and create
postgres user for Odoo with `name='odoo'` and `password='odoo'`.
First argument is postgres user name and second is password.

```bash
odoo-helper install postgres odoo odoo
```

## Install Odoo

Install *Odoo* 11.0 into *odoo-11.0* directory

```bash
odoo-install -i odoo-11.0 --odoo-version 11.0
```

## Manage installed Odoo

Change directory to that one contains just installed Odoo instance.
This is required to make instance-management commands work.

```bash
cd odoo-11.0
```

Now You have *Odoo 11.0* installed in this directory.
Note, that this odoo installation uses [virtualenv](https://virtualenv.pypa.io/en/stable/)
(`venv` directory)
Also you will find there `odoo-helper.conf` config file

So now You can run local odoo server (i.e `openerp-server` or `odoo.py` or `odoo-bin` script).
Note that this command run's server in foreground.
Configuration file `conf/odoo.conf` will be automatically used

```bash
odoo-helper server run
```

Press `Ctrl+C` to stop the server

To run server in backgroud use following command:

```bash
odoo-helper server start
```

Run command below to open current odoo isntance in browser:

```bash
odoo-helper browse
```

By default Odoo service will be accessible on [localhost:8069](http://localhost:8069/)

There are also additional server related commands (see [Frequently Used Commands](./frequently-used-commands.md)):

```bash
odoo-helper server status
odoo-helper server log
odoo-helper server ps
odoo-helper server restart
odoo-helper server stop
```

Also there are shourtcuts for these commands

```bash
odoo-helper status
odoo-helper log
odoo-helper restart
odoo-helper stop
```


## Create database with demo-data

To create Odoo database with demo data run following command

```bash
odoo-helper db create --demo my-database
```

Then start Odoo server (if it wasn't started yet)

```bash
odoo-helper start
```

And login to just created database with following default credentials:

- login: admin
- password: admin


## Fetch and install Odoo addons

Let's fetch modules from [OCA repository contract](https://github.com/OCA/contract)
Branch will be detected automatically by *odoo-helper-scripts*

```bash
odoo-helper fetch --oca contract
```

Or alternatively

```bash
odoo-helper fetch --github OCA/contract --branch 11.0
```

If repository have standard branch structure branches have same names as Odoo versions (series)
then odoo-helper will automatically try to switch to right branch,
thus it is not required to specify branch name in this case.
So command above may look like:

```bash
odoo-helper fetch --github OCA/contract
```

Now look at `custom_addons/` directory, there will be placed links to addons
from [OCA repository 'contract'](https://github.com/OCA/contract)
But repository itself is placed in `repositories/` directory

At this point fetched addons are not shown in *Apps* Odoo menu.
That's why we have to update addons list in database.
This can be done by Odoo UI in developer mode (*Apps / Update Applications List*)
or  th a simple shell command:

```bash
odoo-helper addons update-list
```

Now addons are present in Odoo's database, so they could be installed via UI (*Apps* menu)
Also it is possible to do this via command line with following command:

```bash
odoo-helper addons install [-d database] <addon name>
```

For example following command will install [contract](https://github.com/OCA/contract/tree/11.0/contract) addon

```bash
odoo-helper addons install -d my-database contract
```

Also if database is not specified addon will be installed to all vaiablable databases


## Run tests

Now let's run tests for these just installed modules

```bash
odoo-helper test --create-test-db -m contract
```

This will create *test database* (it will be dropt after tests finished) and 
run tests for `contract` module

Or we can run tests for all addons in specified directory, *odoo-helper-scripts*
will automaticaly detect installable addons and run test for them

```bash
odoo-helper test --dir ./repositories/contract
```

This will use standard test database, that will not be dropt after tests,
so we do not need to recreate database on each test run, which saves time.

If you need color output from Odoo, you may use `--use-unbuffer` option,
but it depends on `unbuffer` program that could be found in `expect-dev` package.

```bash
odoo-helper --use-unbuffer test -m contract
```

The one cool thing of *odoo-helper-scripts*, you may not remeber paths to odoo instalation directory,
and if you change directory to another inside your *Odoo* project, everything will continue to work.

```bash
cd custom_addons
odoo-helper server status
dooo-helper server restart
```

## One more Odoo install

So... let's install one more Odoo version
go back to directory containing your projects (that one, where `odoo-11.0` project is placed in)

```bash
cd ../../
```

Let's install *Odoo* of version 12.0 here too.
First, install *system dependencies* for *Odoo* version 12.0

```bash
odoo-helper install sys-deps 12.0;
```

And when system dependencies installed, install *Odoo* itself

```bash
odoo-install --install-dir odoo-12.0 --odoo-version 12.0
cd odoo-12.0
```

and, for example,  install there [partner-contact/base_location](https://github.com/OCA/partner-contact/tree/12.0/base_location) addon 
from [partner-contact](https://github.com/OCA/partner-contact) [Odoo Community Association](https://odoo-community.org/) repository
Note that *odoo-helper* script will automaticaly fetch branch named as server version in current install (in this case *12.0*),
if another branch was not specified

```bash
odoo-helper fetch --oca partner-contact -m base_location
```

and run tests for it

```bash
odoo-helper test --create-test-db -m base_location
```

Also if you want to install python packages in current installation environment,
*odoo-helper* provides *pip alias* to *pip* installed in virtualenv of Odoo instance

```bash
odoo-helper pip install phonenumbers
```

## More

*odoo-helper-scripts* has much more features.

Look at [Frequently Used Commands](./frequently-used-commands.md) to gen more info.
