# odoo-helper-scripts documentation

At this moment, here is only basic documentation

See also [Quick Start Guide](./quick-start-guide.md) and [Frequently used commands](./frequently-used-commands.md)

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

## Support

Have you any quetions? Just [fill an issue](https://gitlab.com/katyukha/odoo-helper-scripts/issues/new) or [send email](mailto:incoming+katyukha/odoo-helper-scripts@incoming.gitlab.com)
