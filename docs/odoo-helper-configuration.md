# odoo-helper-scripts configuration


There are two types of config files used by odoo-helper:
- global config
- per project/instance config

## Global config

Glocbal configuration file could be placed in two specific directories:
- `/etc/odoo-helper.conf` - for *system-wide* installations
- `$HOME/odoo-helper.conf` - for *user-space* installations

Both of them may be present at same time.
In this case *system-wide* config will be loaded first and *user-space* config second.
Thus *user-space* config may override variables defined in *system-wide* config.

Ususaly these files generated on *odoo-helper-scripts* installation.

## Project/Instance Configuration files.

odoo-helper searches for *project/instance config file* (`odoo-helper.conf`)
starting from current working directory and going up to root directory.
First config found is used.
