# Changelog

## Version 0.1.1

- Support of Odoo 10.0
- Support of [setuptools-odoo](https://pypi.python.org/pypi/setuptools-odoo)
  - Automaticaly install in env
  - Wrap pip with automaticaly set `PIP_FIND_LINKS` environment variable with [OCA Wheelhouse](https://wheelhouse.odoo-community.org/)
- Added shortcut script `odoo-helper-restart` to restart server.
- Added `odoo-helper db rename` command
- Added `odoo-helper install reinstall-venv` option
- `odoo-helper test`: Test only installable addons

## Version 0.1.0

- Added ``odoo-helper addons pull_updates`` command
- Added basic support of Odoo 10
- Added ``odoo-helper --version`` command
- Refactored ``odoo-install`` script:
  - Always install python extra utils
  - Removed following options (primery goal of this, is to simplify ``odoo-install`` script):
    - ``--extra-utils``: extrautils are installed by default
    - ``--install-sys-deps``: use instead separate command: ``odoo-helper install``
    - ``--install-and-conf-postgres``: use instead separate command: ``odoo-helper install`` or ``odoo-helper postgres``
    - ``--use-system-packages``: seems to be not useful
    - ``--use-shallow-clone``: seems to be not useful
    - ``--use-unbuffer``: seems to be not useful
  - Added following options:
    - ``--odoo-version``: this option is useful in case of using custom
      repository and custom branch with name different then odoo's version branches
  - Fixed bug with ``--conf-opt-*`` and ``--test-conf-opt-*`` options
- Completely refactored ``odoo-helper test`` command
  - removed ``--reinit-base``
  - added ``--coverage`` options
  - Added subcommand ``odoo-helper test flake8``
  - Added subcommand ``odoo-helper test pylint``
- ``odoo-helper addons update-list`` command: ran for all databases if no db specified
- suppress git feedback in ``odoo-helper system update``
- improve system-wide install script: allow to choose odoo-helper branch or
  commit to install
- Added ability to run tests for directory.
  In this case odoo-helper script will automaticaly discover addons in
  that directory
- odoo-helper: added ``--no-colors`` option
- ``odoo-helper tr`` command improved:
  - ``import`` and ``load`` subcommands can be ran on all databases
  - ``import`` subcommand: added ability to search addons in directory
  - bugfix in ``tr import``: import translations only for installed addons
- Added ``addons test-installed`` command
  This allows to find databases where this addon is installed
- Bugfix: ``addons check_updates`` command: show repositories that caused errors when checking for updates
- ``addons status`` command now shows repository's remores
- ``odoo-helper fetch`` and ``odoo-helper link`` commands refactored:
  - Added recursion protection for both of therm, to avoid infinite recursion
  - ``odoo-helepr fetch`` filter-out uninstallable addons, on linking muti-addon repo
  - ``odoo-helper link`` now is recursive, thus it will look for odoo addons
    recursively in a specified directory and link them all.
- Added ``odoo-helper install`` command, which allows to install
  system dependencies for specific odoo version without installing odoo itself
- Added ``odoo-helper addons install --no-restart`` option
- Added ``odoo-helper addons update --no-restart`` option
- Added following shortcuts:
  - ``odoo-helper pip`` to run pip for current project
  - ``odoo-helper start`` for ``odoo-helper server start``
  - ``odoo-helper stop`` for ``odoo-helper server stop``
  - ``odoo-helper restart`` for ``odoo-helper server restart``
  - ``odoo-helper log`` for ``odoo-helper server log``


## Version 0.0.10

- Bugfixes in ``odoo-helper test`` command
- Added ``odoo-helper addons check_updates`` command
- Improved ``odoo-helper addons status`` command to be able to
  correctyle display remote status of git repos of addons
- Added ``odoo-helper postgres`` command to manage local postgres instance
- ``odoo-helper-*`` shortcuts refactored
- Added command ``odoo-helper addons update_list <db>`` which updates
  list of available modules for specified db
- Bugfixes and improvements in ``odoo-helper tr`` command


## Version 0.0.9

- Added ``odoo-helper scaffold <addon_name> [addon_path]`` shortcut command
- Added ``odoo-helper tr`` subcommand that simplifies translation management
- Added shortcuts for frequently used subcommands to ``bin`` dir,
  so standard autocomplete can help. They are:
    - odoo-helper-server
    - odoo-helper-db
    - odoo-helper-addons
    - odoo-helper-fetch
- Added ``odoo-helper addons update`` and ``odoo-helper addons install`` subcommands
- Refactored ``odoo-helper server auto-update`` and ``odoo-helper update_odoo``

## Version 0.0.8

- Bugfix in ``odoo-helper link .`` command
- Added aditional extra_python depenencies:
    - setproctitle
    - python-slugify
    - watchdog
- Added experimental command ``odoo-helper server auto-update``.
- Added experimental command ``odoo-helper db backup-all``.


## Version 0.0.7
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

