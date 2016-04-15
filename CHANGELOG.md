# Changelog

## Version 0.0.7.dev
- odoo-helper system lib-path command makes available to use some parts of this project from outside
- Added new db commands: dump, restore, backup
- odoo-helper addons status: bugfix in parsing git status
- odoo-install related fixes

## Version 0.0.6

- Added 'odoo-helper exec <cmd> [args]' command
- Added simple auto-update mechanism
- odoo-helper addons: Added ability to list addons not under git

## Version 0.0.5

- Added support to manage server state via init script
- Separate *repository* directory to store repositories fetched by this scripts
- Added ability to install Odoo from non-standard repository
- Added basic support of OCA dependency files (oca\_dependencies.txt)

## Version 0.0.4

- Added ability to specify config options on odoo-install
- Added automatic processing of pip requirements file placed in repo.
- Added better check if postgres installed on attempt to install it.

