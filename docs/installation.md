# Installation of odoo-helper-scripts

Installation of *odoo-helper-scripts* consists of three steps:

1. Install *odoo-helper-scripts*
2. Install system dependencies for *odoo-helper-scripts*
3. Install dependencies for specific *Odoo* version

Second step is separated, because installing system dependencies on different
different platforms may differ and automatic installation of system dependencies
only supported on debian-like systems (using apt)


## Installing odoo-helper-scripts itself
There are two options to install *odoo-helper-scripts*:

- *user-space* installation
- *system-wide* installation

### User-space installation

```bash
wget -O - https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-user.bash | bash -s
```

or in more explicit way:

```bash
wget -O odoo-helper-install-user.bash https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-user.bash
bash odoo-helper-install-user.bash
```

After instalation you will have ``odoo-helper-scripts`` directory inside your home directory
And ``$HOME/odoo-helper.conf`` file will be generated with path to odoo-helper-scripts install dir.
*odoo-helper-scripts* executables will be placed in ``$HOME/bin/`` directory.
If this directory does not exists at installation time, then it will be created.

#### Known bugs and workarounds for user-space installation

1. *command not found `odoo-helper`* after installation. Ususaly this happens, because there is
   no `$HOME/bin` directory or it is not in `$PATH` before installation.
   After installation this directory will be created, but additional steps may be required to add it to `$PATH`
    - restart shell session (for example open new terminal window or tab).
      This may help if shell is configured to use `$HOME/bin` directory if it is exists.
    - if *bash* is used as shell, then it may be enough to source `.profile` file (`$ source $HOME/.profile`)
    - add `$HOME/bin` directory to `$PATH` in your shell start-up configration ([Stack Exchange Question](https://unix.stackexchange.com/questions/381228/home-bin-dir-is-not-on-the-path))

### System-wide installation

To install (system-wide) just do folowing:

```bash
# Install odoo-helper-scripts
wget -O - https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash | sudo bash -s
```

or more explicit way:

```bash
# Download installation script
wget -O /tmp/odoo-helper-install.bash https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash;

# Install odoo-helper-scripts
sudo bash /tmp/odoo-helper-install.bash;
```

After instalation *odoo-helper-scripts* code will be placed in ``/opt/odoo-helper-scripts`` directory.
``odoo-helper.conf`` file that containse global odoo-helper configuration will be placed inside ``/etc/`` directory
*odoo-helper-scripts* executables will be placed in ``/usr/local/bin`` directory.

## Install system dependencies for odoo-helper-scripts

On this step system dependencies have to be installed. This could be done automaticaly for *debian-based* systems:

```bash
odoo-helper install pre-requirements
```

On other operation systems it may require to install system dependencies manualy
For example following command will isntall system dependencies for [OpenSUSE](https://www.opensuse.org/) linux

```bash
zypper install git wget python-setuptools gcc postgresql-devel python-devel expect-devel libevent-devel libjpeg-devel libfreetype6-devel zlib-devel libxml2-devel libxslt-devel cyrus-sasl-devel openldap2-devel libssl43 libffi-devel
```

Also, *PostgreSQL* is usualy required for local development.
For *debian-based* systems odoo-helper could be used:

```bash
odoo-helper install postgres
```

Postgres user for odoo may be created at same time

```bash
odoo-helper install postgres odoo_user odoo_password
```

For other systems it have to be installed manualy


## Install Odoo system dependencies

To make Odoo work, some system dependencies fpecific for version may be required.
Most of python dependencies are installed in virtualenv, thus no need for sudo access.
But some non-python system libraries may be required.

For this reason for *debian-based* systems exists one more odoo-helper command

```bash
#odoo-helper install sys-deps <odoo-version>
odoo-helper install sys-deps 11.0
```

For other systems such depencies have to be installed manualy


## Installation of development version

Installation scripts could reciev *reference* argument.  This could be branch name, tag name or commit hash.
So to install *development* version system-wide run following command:

```bash
# Install odoo-helper-scripts  (note '- dev' in the end of command)
wget -O - https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash | sudo bash -s - dev

#  Intall system pre-requirements for odoo-helper-scripts
odoo-helper install pre-requirements
```

For user-space install:

```bash
wget -O - https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-user.bash | bash -s - dev

#  Intall system pre-requirements for odoo-helper-scripts
#  NOTE: works only on debian-based systems
odoo-helper install pre-requirements
```

## Update odoo-helper-scripts

If you installed old version of odoo-helper scripts and want to update them to new version,
then following command will help you:

```bash
odoo-helper system update
```

For example to update to last *dev* commit following command could be used:

```
odoo-helper system update dev
```
