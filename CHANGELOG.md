# Release Notes

## Unreleased

### Added

- Added command *odoo-helper addons find-installed*.
  Scan all databases for installed addons.
- Added aliases (shortcuts):
    - `odoo-helper-link`
    - `odoo-helper-addons-update`

### Changed

- Changed `odoo-helper pull-updates` command
    - Now it does not update addons list automatically
    - Added `--ual` option to update addons list
    - Added `--help` options
    - First positional argument not applicable for it.
      Added option `--addons-dir` instead .
- Refactored `odoo-helper lint pylint` command
    - `consider-using-ternary` warning enabled by default
    - `unused-import` warning enabled by default

### Deprecations

- Command `odoo-helper generate-requirements` deprecated.
  Use `odoo-helper addons generate-requirements`


## Release 0.3.0 (2019-02-04)

### Added

- Added `--fix-version` option to `odoo-helper ci check-versions-git` command
- Added ability to pass list of addons to `odoo-helper test` command without 
  need to prefix each addon with `-m `. Now it could be done like:
  `odoo-helper test my_addon1 my_addon2`
- Added `--skip` option of `odoo-helper test` command
- Added `odoo-helper db copy` command

### Fixed

- running `odoo-helper tr` command will not overwrite `pidfile`

### Changed

- Last argument of `odoo-helper ci check-versions-git` now optional.
  If it is omited, than current working tree state will be used as last revision.
- Use own copy of virtualenv, to avoid installing it in system.
  virtualenv is bundled into odoo-helper as git submodule now.

### Removed

- Removed support of Odoo 7.0. Now minimal supported Odoo version is 8.0
- Removed `odoo-helper server auto-update` command that was deprecated in previous version
- Removed `-p` and `--python` options for `odoo-helper fetch` command
- Removed `-p` and `--python` options for `odoo_requirements.txt` file


## Release 0.2.0 (2018-12-20)

### Added

- New `--color` option to `odoo-helper addons list` command.
  At this time this option colors output  by following rules:
    - green - addon is linked to *custom addons*
    - red - addons is not present in *custom addons*
    - yellow - addons is present in *custom addon*, but link point's to another place
- New `--not-linked` option to `odoo-helper addons list` command
- New `--linked` option to `odoo-helper addons list` command
- New `--filter` option to `odoo-helper addons list` command
- New `odoo-helper odoo server-url` command
- New `odoo-helper system is-project` command
- New `odoo-helper system get-venv-dir` command
- New options to `odoo-helper addons update/install/uninstall` commands
    - `--tdb` or `--test-db` use test database
    - `--cdb` or `--conf-db` use default database from odoo config
    - `-m` or `--module`. Option is added to be consistend with
      `odoo-helper test` command, which used this toption to specify
      addons (modules) to be tested
    - `--ual` - Update Apps List. When this option is specified, apps (addons)
      list will be updated before install/update/uninstall addon
    - `all` - install or update all addons. Does not work for uninstall.
- Shortcut `odoo-helper psql` for `odoo-helper postgres psql` command
- Shortcut `odoo-helper ps` for `odoo-helper server ps`
- Alias to `--version` option - `version`: `odoo-helper version`
- New options for `odoo-helper server run` command
    - `--coverage`: run with code coverage enabled
    - `--test-conf`: run with test configuratuon
    - `--help`: show help message
    - `--`: options delimiter - all options after this
      will be passed directly to Odoo
- Help message and new options to `odoo-helper db drop` command
    - option `-q` or `--quite` to hide messages produced by this command
- Added help messages for commands:
    - `odoo-helper install pre-requirements`
    - `odoo-helper install sys-deps`
    - `odoo-helper install py-deps`
    - `odoo-helper install py-tools`
    - `odoo-helper install js-tools`
    - `odoo-helper install bin-tools`
    - `odoo-helper install postgres`
    - `odoo-helper install reinstall-odoo`
    - `odoo-helper install reinstall-venv`
- New options to `odoo-install` command
    - `--git` - shortcut for `--download-archive off`
    - `--archive` - shortcut for `--download-archive on`
- New command `odoo-helper postgres stat-connections`
- New shortcut `odoo-helper pg` for `odoo-helper postgres`
- New command `odoo-helper git changed-addons` that displays
  list of addons that have been changed between two specified git revisions
- New command `odoo-helper ci check-versions-git`.
  The goal of this command is to be sure that addon version number was updated.
- New command `odoo-helper ci ensure-icons`.
  Ensure that all addons in specified directory have icons.
- New option `--ual` for `odoo-helper link` command.
- New command `odoo-helper browse` that opens running odoo instance in webbrowser
- Experimental support of Odoo 12.0
- Added colors to `odoo-helper tr rate` command output
- Added option `--recreate` to `odoo-helper db create` command.
  If database with such name already exists,
  then it will be dropt before creation of new database.
- Added special option `--dependencies` to
  `odoo-helper doc-utils addons-list` command
- Install [websocket-client](https://github.com/websocket-client/websocket-client)
  during `py-tools` install to run test tours in Odoo 12+
- Install `chromium-browser` durin `bin-tools` install. It is requird to run
  tests in Odoo 12+

### Fix

- `odoo-helper addons list` bugfix `--recursive` option:
  forward options to recursive calls
- `odoo-helper db drop` check result of drop function, and if it is False then fail
- `odoo-helper install reinstall-version` show correct help message
  and added ability to specify python version to be used for new virtualenv

### Changed

- `odoo-helper addons list` will search for addons in current directory if addons path is not specified
- `odoo-helper addons update-list` possible options and arguments changed
    - Before
        - first argument is database name and second is config file.
          last one wasn't used a lot
        - if no arguments supplied then update addons list for all databases
    - After
        - added `--help` option
        - added `--tdb` or `--test-db` option to use test database
        - added `--cdb` or `--conf-db` option to use database specified in default odoo config
        - all arguments are considered as database names.
          This allows us to keep partial backward compatability
- `odoo-install` now will automaticaly install [phonenumbers](https://github.com/daviddrysdale/python-phonenumbers)
  python package.
- display commit date in output of `odoo-helper --version`
- `odoo-helper postgres speedify` use SQL `ALTER SYSTEM` instead of modifiying postgresql config file
- `odoo-helper lint style` now have separate configs for *.css*, *.less*, *.scss*.
  The only differece is that *.less* and *.scss* configs have default indentation set to 4 spaces and
  *.css* config have default indentation set to 2 spaces
- `odoo-helper lint style` status changed from *experimental* to *alpha*
- `odoo-helper test`
    - use default test database named `<dbuser>-odoo-test`
    - created temporary databases are prefixed with `test-`
- `odoo-install` do not set automatically `db_filter` and `db_name` for test config file
- `odoo-helper tr rate` if there is no translation terms for addon compute it's rate as 100%
- default flake8 config: disable W503 and W504 checks
- default pylint config:
    - Add proprietary licenses to allowed licenses list
- Install newer version of [wkhtmltopdf](https://wkhtmltopdf.org/): [0.12.5](https://github.com/wkhtmltopdf/wkhtmltopdf/releases/tag/0.12.5)

### Deprecations

- `odoo-helper server auto-update` use instead:
  - `odoo-helper intall reinstall-odoo`
  - `odoo-helper upate-odoo`
- Support of Odoo 7.0 is now deprecated and will be removed in one of next releases
- `odoo-helper fetch -p` and `odoo-helper fetch --python` options are deprecated.
  Use `odoo-helper pip install` command instead.
  Or place `requirements.txt` file inside repository root or addon root directory.
- It is not recommended now to use `db_name` and `db_filter` in test config file,
  because, if either of them is defined,
  then it is not allowed to drop databases that do not match  `db_name` or `db_filter` 


## Release 0.1.6 (2018-06-04)

- Improve `odoo-helper addons update-py-deps` command, now it aloso updates repository level dependencies
  (those, mentioned in repository's `requirements.txt`)
- Added `odoo-helper doc-utils` command. Have following subcommands
    - `odoo-helper doc-utils addons-list` command to print info about addons in repo in [Markdown](https://en.wikipedia.org/wiki/Markdown) format
- Move linters to separate subcommand `odoo-helper lint`.
  Run `odoo-helper lint --help` for details
- Added `odoo-helper lint style` commant.
  It is experimental integration with [stylelint](https://stylelint.io/)
- `odoo-helper lint pylint` skip addons with `'installable': False`
- `odoo-helper lint flake8` skip addons with `'installable': False`
- `odoo-helper addons list` command now have extra options and can search for addons in multiple paths:
    - `--installable`
    - `--by-name`  (used by default)
    - `--by-path`
    - `--recursive`
- `odoo-helper addons (install|update|uninstall)` command now have
  extra options `--dir <addon path>` and `--dir-r <addon-path>` which can be used
  to install/update/uninstall all installable addons in specified directory
- Added `--dir` and `--dir-r` options for `odoo-helper tr regenerate` and `odoo-helper tr rate` commands
- Added `--start` option to `odoo-helper addons install|update|uninstall` command
- Do not set `pidfile` option in odoo config by default.
  pidfile have to be managed by odoo-helper-scripts, not by Odoo.
- **Backward incompatible** remove [Mercurial](https://www.mercurial-scm.org/)
  installation from `odoo-helper install py-tools`, because it [does not support Python3](https://www.mercurial-scm.org/wiki/Python3)
- To be compatible with [Odoo.sh](https://www.odoo.sh)-style development,
  `odoo-helper fetch` now recursively fetches submodules for git repositories.
- Added option `--dir-r|--directory-r` for `odoo-helper test` command,
  to recursively search for addons to be tested in specified directory
- Added `--log` option for following commands:
    - `odoo-helper start --log`
    - `odoo-helper restart --log`
    - `odoo-helper addons install --log`
    - `odoo-helper addons update --log`
    - `odoo-helper addons uninstall --log`
- Command `odoo-helper server log`: automatically move to end of log file after open  (`+G` for `less` command)
- Added command `odoo-helper postgres start-activity` to display running postgres connections
- Added command `odoo-helper install reinstall-odoo` to easily spwitch betwen two installation modes:
    - `download` - download Odoo source as archive (faster)
    - `clone` - clone Odoo source as git repo (better handle updates, multiple remotes, multiple branches, etc).
- Show if it is *Git Install* in output of `odoo-helper status` command
- Show Odoo server url in output of following command:
    - `odoo-helper status`
    - `odoo-helper server status`
    - `odoo-helper server start`


## Release 0.1.5 (2018-01-12)

- Use [nodeenv](https://pypi.python.org/pypi/nodeenv) together with
  [virtualenv](https://virtualenv.pypa.io/en/stable/) to be able to install
  js dependencies in virtual environment. Examples of such dependencies are
  [jshint](http://jshint.com/about/) that used by
  [pylint_odoo](https://github.com/OCA/pylint-odoo) to check javascript files and
  [phantomjs](ihttp://phantomjs.org/) used to run test tours.
- Added command `odoo-helper install js-tools`
- Added command `odoo-helper npm` - shortcut to run npm for current project
- Improved command `odoo-helper test pylint`, now most of pylint options will
  be forwarded directly to pylint.
- `wkhtmltopdf` install refactored, added separate command `install wkhtmltopdf`,
  start using wkhtmltopdf downloads from [github](https://github.com/wkhtmltopdf/wkhtmltopdf/releases/tag/0.12.2.1)
- Autodetect python version
- Removed `odoo-install --python` option
- `odoo-helper generate_requirements` renamed to `odoo-helper generate-requirements`
- `odoo-helper update_odoo` renamed to `odoo-helper update-odoo`
- `odoo-helper install reinstall-venv` option simplified. now it does not recieve any arguments
- do not install `node-less` as system dependency
- `odoo-helper install js-tools` automatialy install `eslint` instead of `jshint`
  Starting from version 1.6.0 [pylint_odoo](https://pypi.python.org/pypi/pylint-odoo/) uses `eslint`
- removed unuseful `odoo-install -y`, it does not run apt, so there is no interactive y/n questions
- pylint default config: enabled *redefined-outer-name* check
- experimental `odoo-helper tr rate` command, which computes translation rate for addons. Useful in CI.
- added command `odoo-helper install bin-tools`
- do not use [OCA simple](https://wheelhouse.odoo-community.org/) PyPI index by defautl.
  So to use [OCA simple](https://wheelhouse.odoo-community.org/) PyPI index, pass *--oca* argument to
  `odoo-helper pip` command. For example: 
  `odoo-helper --oca pip install odoo10-addon-mis-builder` will use [OCA simple](https://wheelhouse.odoo-community.org/) index.
- `odoo-helper status`: print versions of following tools used in current project.
    - NodeJS
    - npm
    - Less.JS
    - Pylint
    - Flake8
    - ESLint
    - Pylint Odoo
- Do not require [erppeek](https://github.com/tinyerp/erppeek).
  This project seems to be abandoned.
- Do not force install following python packages: *six*, *num2words*
- Python package *setproctitle* will be installed by `odoo-helper install py-tools` command.
  (previously it was installed as python-prerequirement for Odoo)
- Do not upgrade *pip* and *setuptools* when installing Odoo in fresh virtualenv,
  virtualenv versions >= 15.1.0 automaticaly installs last pip and setuptools,
  so there is not need to reinstall them
- List command `odoo-helper addons generate-requirements` in help message for addons subcommand
- Bugfix in processing OCA depenencies: handle cases, when file ends without newline


## Release 0.1.4 (2017-11-13)

- Added command `odoo-helper odoo`
- Added command `odoo-helper odoo recompute`, that allows to recompute stored fields.
  Also this command allow to recompute parents (left/right)
- Command `odoo-helper db exists` now have it's own help message
- Command `odoo-helper db exists` added option `-q` to disable output
- Added command `odoo-helper postgres speedify`


## Release 0.1.3 (2017-10-28)

- use [codecov](https://codecov.io) for code coverage
- renamed command `odoo-helper print_config` to `odoo-helper print-config`
- Added `odoo-helper test --coverage-skip-covered` option
- Added `odoo-helper addons update-py-deps` command
- Added aliase `odoo-helper-log`
- Added `odoo-helper postgres psql` command
- Removed old unused options
    - `odoo-helper --addons-dir <addons_directory>`
    - `odoo-helper --downloads-dir <downloads_directory>`
    - `odoo-helper --virtual-env <virtual_env_dir>`
    - `odoo-helper test --tmp-dirs`
    - `odoo-helper test --no-rm-tmp-dirs`


## Release 0.1.2 (2017-10-04)

- `odoo-install --python` option added. Now it is possible to install Odoo 11
  in python3 virtual environment
- `odoo-install` system dependencies reduced. Now most of python dependencies
  will be installed in virtualenv via pip.
- `odoo-helper tr regenerate` command added. This command allows to regenerate
  translation files for specified lang. This may be useful,
  if new translation terms appeared after module change.
- no `_` (underscore symbol) in random strings
- Save Odoo repository in ``odoo-helper.conf``
- bugfix in command: `odoo-helper odoo-py`
- Added option `odoo-helper test --coverage-report`
- Bugfix, install Pillow less than 4.0 for Odoo 7.0
- Added command `odoo-helper install py-deps <version>`
- `odoo-helper test -d .` do not omit `.` if it is odoo addon.
  This happens in case if `odoo-helper test` called when current dir is addon.
- `odoo-helper test --recreate-db` option added. If this option passed,
  and test database already exists, then it will be dropt before tests started.
- `odoo-helper tr` command: better help messages, added help messages for subcommands
- `odoo-helper exec` command now adds to env vars `ODOO_RC` and `OPENERP_SERVER` variables
  with path to project's odoo config file
- Added `odoo-helper install py-tools` command to install extra tools like pylint, flake8, ...
- Added `odoo-helper server ps` command
- Added more colors to odoo-helper output
- Added `odoo-helper addons uninstall` command
- Added ability to test odoo-helper-scripts on various debian-based distributions via docker
- Added `odoo-helper addons list` command, that lists odoo-addons in specified directory
- Added aliases `odoo-helper flake8` and `odoo-helper pylint`
- Added automatic configuration checks.
  So, when odoo-helper-scripts provides some new configuration params after update,
  user will be notified about them and asked to update project config file
- `odoo-helper scaffold` have new features and subcommands:
    - `odoo-helper scaffold repo` create repository. place it in repo dir
    - `odoo-helper scaffold addon` create new addon. place it in repo and automaticaly link.
    - `odoo-helper scaffold model` create new model in addon. (Still work in progress)


## Release 0.1.1 (2017-06-08)

- Support of Odoo 10.0
- Support of [setuptools-odoo](https://pypi.python.org/pypi/setuptools-odoo)
    - Automaticaly install in env
    - Wrap pip with automaticaly set `PIP_EXTRA_INDEX_URL` environment variable with [OCA Wheelhouse](https://wheelhouse.odoo-community.org/)
- Added shortcut script `odoo-helper-restart` to restart server.
- Added `odoo-helper db rename` command
- Added `odoo-helper install reinstall-venv` option
- `odoo-helper test`: Test only installable addons
- `odoo-helper addons update-list` command support odoo 7.0
- `odoo-helper addons test-installed` command support odoo 7.0
- `odoo-helper fetch`: added experimental support of Mercurial
- `odoo-helper test --coverage-html` option added.
- `odoo-helper db create` new options added:
    - `--demo` load demo data (default: not load)
    - `--lang <lang` choose language of database
    - `--help` display help message
- `odoo-install --single-branch` option added. This allow to disable `single-branch` clone.
- Added `pychart` for install
  `pychart` package is broken on pypi, so replace it with Python-Chart


## Release 0.1.0 (2017-03-06)

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


## Release 0.0.10 (2016-09-08)

- Bugfixes in ``odoo-helper test`` command
- Added ``odoo-helper addons check_updates`` command
- Improved ``odoo-helper addons status`` command to be able to
  correctyle display remote status of git repos of addons
- Added ``odoo-helper postgres`` command to manage local postgres instance
- ``odoo-helper-*`` shortcuts refactored
- Added command ``odoo-helper addons update_list <db>`` which updates
  list of available modules for specified db
- Bugfixes and improvements in ``odoo-helper tr`` command


## Release 0.0.9 (2016-08-17)

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


## Release 0.0.8 (2016-06-08)

- Bugfix in ``odoo-helper link .`` command
- Added aditional extra_python depenencies:
    - setproctitle
    - python-slugify
    - watchdog
- Added experimental command ``odoo-helper server auto-update``.
- Added experimental command ``odoo-helper db backup-all``.


## Release 0.0.7 (2016-04-18)

- odoo-helper system lib-path command makes available to use some parts of this project from outside
- Added new db commands: dump, restore, backup
- odoo-helper addons status: bugfix in parsing git status
- odoo-install related fixes


## Release 0.0.6 (2016-03-19)

- Added 'odoo-helper exec <cmd> [args]' command
- Added simple auto-update mechanism
- odoo-helper addons: Added ability to list addons not under git


## Release 0.0.5 (2016-02-29)

- Added support to manage server state via init script
- Separate *repository* directory to store repositories fetched by this scripts
- Added ability to install Odoo from non-standard repository
- Added basic support of OCA dependency files (oca\_dependencies.txt)


## Release 0.0.4 (2016-02-17)

- Added ability to specify config options on odoo-install
- Added automatic processing of pip requirements file placed in repo.
- Added better check if postgres installed on attempt to install it.


## Release 0.0.3 (2015-12-16)

- Added `odoo-helper status` command
- Added `odoo-helper db` command

## Release 0.0.2 (2015-12-01)

- Initial release
