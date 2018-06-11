# odoo-helper-scripts documentation

At this moment, here is only basic documentation

## odoo-helper-scripts installation

For full list of installation options look at [installation documentation](./installation.md)

To install *odoo-helper-scripts* system-wide do folowing:

```bash
# Install odoo-helper-scripts
wget -O - https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash | sudo bash -s

# Install system dependencies required for odoo-helper-scripts
# NOTE: Works only on debian-based systems
odoo-helper install pre-requirements
```

or more explicit way:

```bash
# Download installation script
wget -O /tmp/odoo-helper-install.bash https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash;

# Install odoo-helper-scripts
sudo bash /tmp/odoo-helper-install.bash;

#  Intall system pre-requirements for odoo-helper-scripts
# NOTE: Works only on debian-based systems
odoo-helper install pre-requirements
```


## Basic usage

### odoo-install

Install Odoo in specified directory (using virtualenv)

```bash
odoo-helper install sys-deps 11.0  # install global system dependencies for specified version of Odoo
odoo-install --odoo-version 11.0   # no sudo required
```

After this you will have odoo and it's dependencies installed into *odoo-11.0* directory.

This installation also creates *odoo-helper.conf* file inside project, which allows to use
*odoo-helper* script to simplify interaction with this odoo installation.

Description of *odoo-helper* project's directory structure is [here](./project-directory-structure.md)


### odoo-helper

This is the main script to manage Odoo instances installed by *odoo-install*

Most of *odoo-helper-scripts* functionality is implemented as *subcommands* of `odoo-helper`.
For example `odoo-helper server` contains server management commands like:

- `odoo-helper server start`
- `odoo-helper server stop`
- `odoo-helper server restart`
- etc

All *odoo-helper commands* may be splited in two groups:

- Odoo instance management commands
- Other

*Odoo instance management commands* are commands that manage Odoo instances installed using `odoo-install` script.
Example of such commands may be: `odoo-helper server` or `odoo-helper db` commands.
These commands are required to be ran inside Odoo instance directory (directory with Odoo installed using `odoo-install`)
or its subdirectories. Thus*odoo-helper* could find project/instance [config file](./odoo-helper-configuration.md).

See [Frequently used commands](./frequently-used-commands.md) for more info about available commands
or just run `odoo-helper --help`


## Complete example

Ensure *odoo-helper-scripts* pre-requirements are installed
This step should be usualy ran one time, and is required to ensure that
all odoo-helper dependencies are installed.

```bash
odoo-helper install pre-requirements
```

Install system dependencies for odoo version 10.0
Note, that this option requires *sudo*.

```bash
odoo-helper install sys-deps 10.0;
```

Install [PostgreSQL Server](https://www.postgresql.org/) and create
postgres user for Odoo with `name='odoo'` and `password='odoo'`

```bash
odoo-helper install postgres odoo odoo
```

Install *Odoo* 10.0 into *odoo-10.0* directory

```bash
odoo-install -i odoo-10.0 --odoo-version 10.0
```

Change directory to that one contains just installed Odoo instance.
This is required to make instance-management commands work

```bash
cd odoo-10.0
```

Now You have *Odoo 10.0* installed in this directory.
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

Let's fetch modules from [OCA repository 'contract'](https://github.com/OCA/contract)
Branch will be detected automatically by *odoo-helper-scripts*

```bash
odoo-helper fetch --oca contract
```

Or alternatively

```bash
odoo-helper fetch --github OCA/contract --branch 10.0
```

Now look at `custom_addons/` directory, there will be placed links to addons
from [OCA repository 'contract'](https://github.com/OCA/contract)
But repository itself is placed in `repositories/` directory

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
so we do not need to recreate database on each test run, which saves time

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

So... let's install one more Odoo version
go back to directory containing your projects (that one, where `odoo-10.0` project is placed in)

```bash
cd ../../
```

Let's install *Odoo* of version 11.0 here too.
First, install *system dependencies* for *Odoo* version 11.0

```bash
odoo-helper install sys-deps 11.0;
```

And when system dependencies installed, install *Odoo* itself

```bash
odoo-install --install-dir odoo-11.0 --odoo-version 11.0
cd odoo-11.0
```

and install there for example addon [project_task_code](https://github.com/OCA/project/tree/11.0/project_task_code)
from [project](https://github.com/OCA/project) [Odoo Community Association](https://odoo-community.org/) repository
Note that *odoo-helper* script will automaticaly fetch branch named as server version in current install,
if another branch was not specified

```bash
odoo-helper fetch --oca project -m project_task_code
```

and run tests for it

```bash
odoo-helper test --create-test-db -m project_task_code
```

Also if you want to install python packages in current installation environment,
*odoo-helper* provides *pip alias* to *pip* installed in virtualenv of Odoo instance

```bash
odoo-helper pip install phonenumbers
```

and as one more example, let's install aeroo-reports with dependancy to aeroolib in odoo 10.0

```bash
cd ../odoo-10.0
odoo-helper fetch --github gisce/aeroo -n aeroo
odoo-helper fetch -p git+https://github.com/jamotion/aeroolib#egg=aeroolib
```
