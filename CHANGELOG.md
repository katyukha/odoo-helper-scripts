# Release Notes

## Unreleased

### Added

- Ability to automatically detect python for Odoo version via following options:
    - `odoo-helper install reinstall-venv --build-python auto`
    - `odoo-install --build-python auto`
- Ability to automatically build python of odoo version only if system python do not satisfy odoo requirements.
  For this reasone new option was added to following commands:
    - `odoo-helper install reinstall-venv --build-python-if-needed"
    - `odoo-install --build-python-if-needed`
- Add ability to enforce `odoo-helper fetch` clone repos with `--single-branch` options.
  This feature could be enabled via environment variable `ODOO_HELPER_FETCH_GIT_SINGLE_BRANCH`.
  This feature could be useful to reduce size of cloned repositories.
- Added ability to automatically update odoo-helper-scripts installed via debian package.

### Changed

- On module migration automatically replace `related_sudo=` to `compute_sudo`
  for field definitions.


### Deprecations

- Option `odoo-install --openupgrade` is deprecated. It will raise error for odoo 14.0+.
  Starting from Odoo 14.0, openupgrade separate odoo addons to store migrations, instead of full copy of odoo.

---

## Release 0.13.0 (2022-06-25)

### Changed

- Updated minimal version for setuptools for odoo to be greater or equal to 45 and less than 58

---

## Release 0.13.0 (2022-06-25)

### Added

- Short version of `--migrate-modules` option to `odoo-helper ci do-forwardport`: `--mm`.
  So, now forwardport command could look like: `odoo-helper ci do-forward-port -s 12.0 --mm`
- Automatically detect `.jslintrc` placed in repo root directory. If found, then apply it to pylint by default.
- Added shortcut for `odoo-helper fix-versions` - `odoo-helper fix-version`
- Added option `--tdb` to `odoo-helper odoo recompute` command
- Added new option `--no-backup` to `odoo-helper install reinstall-odoo`
- On module migration automatically replace `phantom_js(` to `browser_js(`.
- Added new option `--if-not-exists` to `odoo-helper db create` command
- Added new command `odoo-helper postgres wait-availability` that allows to wait while postgres will be started and ready.
  This command could be useful for docker containers

### Changed

- Install LTS version of nodejs by default.
  In previous version latest stable version was installed by default.
- [openupgradelib](https://github.com/OCA/openupgradelib) now will be downloaded from pypi.
  It seems that now relevant versions of this lib are published on pypi
- Simplify installation for debian-like systems: automatically install preprequirements
- Python2 support is now installed only for Odoo 10.0 and below.
- Do not use fallback packages when installing wkhtmltopdf.
  By default install wkhtml to pdf from wkhtmltopdf releases only fore supported releases.
  Otherwise, user have to manually choose if he needs to try fallback repo or install system's wkhtmltopdf.

---

## Release 0.12.1 (2021-10-25)

- Fixed: `libmagic1` added to system pre-requirements

## Release 0.12.0 (2021-10-25)

### Added

- Optionally, install py dependencies defined in `requirements.auto.txt` file duting linking addons.
  This may be used to handle auto-generated requirements by tools like [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit).
  This feature have to be enabled by setting environment variable `ODOO_HELPER_FETCH_PIP_AUTO_REQUIREMENTS` to non-zero value.
  If you want to enable this feature on permanent basis, then you can place this var to odoo-helper's project-level or global config file.
- Added experimental support for automatic discover of python dependencies defined in addon's manifest during addon linking process.
- Try to automatically detect config for linters, if it is placed in root of repository and if linter invoked inside this repo.
  Available linter config file names are:
    - `flake8.cfg`
    - `pylint_odoo.cfg`
    - `stylelint-default.json`
    - `stylelint-default-less.json`
    - `stylelint-default-scss.json`
- Added new opt `--upgrade` to `odoo-helper install py-tools` and `odoo-helper install dev-tools` commands
- Added new opt `--update` to `odoo-helper install js-tools`
- Added new opts to `odoo-helper db create` command:
    - `--tdb` - create test database with auto-generated name
    - `--name <name>` - allows to specify name of database as option
- Experimental support of Odoo 15.0
- Added new options to `odoo-install` and `odoo-helper install reinstall-venv`
  that influence on building python:
    - `--build-python-optimize`: enable expensive, stable optimizations (PGO, etc.)
    - `--build-python-sqlite3`: support loadable extensions in `_sqlite` module
- Added new option to `odoo-install` command: `--enable-unbuffer`.
  This option enables usage of `unbuffer` command, to make output of test logs colored.
- Added new option to `odoo-install` command `--dev` that will automatically install dev tools after odoo installation.
- Added short versions of options to `odoo-helper fix-versions` command:
    - `-p` for patch version fix
    - `-m` for minor version fix
    - `-M` for major version fix

### Changed

- Changed signature of `odoo-helper link` command. See `odoo-helper link --help` for more info.
- Automatically install `python-magic` package during odoo installation.
- Use another config for `stylelint` for `scss` files.
  This was done, because `stylelint` started throwing errors, when parsing `scss` files in standard way,
  so it was desided to update use specific config for style lint with this update.

### Removed

- `odoo-helper pip --oca` option support. There is no sense to use this option anymore,
  because all OCA apps now published on standard PyPI.


## Release 0.11.0 (2021-09-17)

### Added

- Added new module migration for version 14.0:
    - automatically replace `track_visibility='...'` to `tracking=True`
- Added new shortcuts:
    - `odoo-helper addin` - `odoo-helper addons install`
    - `odoo-helper addup` - `odoo-helper addons update`
- Added new command:
    - `odoo-helper install py-prerequirements` that could be used to install
      or update project-level python dependencies needed by odoo-helper

### Changed

- Command `odoo-helper install js-tools` now will also install
  `stylelint-config-sass-guidelines` package, that could be used as config for
  linter for sass file (`*.scss`)

### Fixed

- `odoo-helper odoo clean-compiled-assets` now will clean up dev-mode CSS files
  generated from SCSS and LESS files.
- Fixed odoo installation. New setuptools has dropt support of `use_2to3` build param,
  so odoo helper will enforce setup tools less then version 58 to make odoo installable.

### Deprecation
- Support for Odoo 10 and below is now deprecated and will be removed in one of next releases.
  The python2 support is over, and there is no sense to continues to support odoo versions,
  that rely on unsupported python versions.


## Release 0.10.0 (2021-06-22)

### Added

- Added ability to use project-level (odoo-helper project-level) configs for
  tools (linters). Just place correct config file on conf dir of your odoo-helper project.
- Pylint, handle following additional warnings:
    - undefined-variable - E0602
    - signature-differs - W0222
    - inconsistent-return-statements - R1710
    - no-else-continue - R1724
- Added option `--create-db-user` to `odoo-install` command, that allows
  to create postgresql user for installation automatically.
- Added new option `--format` to command `doc-utils addons-graph`.
  So, now it is possible to specify output format for result graph
- Added new option `--no-restart` to `odoo-helper update-odoo` command
- Added ability to build custom (non-system) python when installing odoo.
  Use option like `--build-python 3.8.0` in command `odoo-install` to use custom python version
- Added ability to build custom (non-system) python when reinstalling venv
- Added new shortut `odoo-helper ual` to `odoo-helper addons update-list`
- Added experimental option `--migrate-modules` to `odoo-helper ci do-forwardport` command

### Changed

- Fail tests on warning:
    - The group defined in view does not exist!
    - inconsistent `compute_sudo` for computed fields
- Forwardport migrations during forwardport by default.
- `odoo-helper update-odoo` now will restart server automatically
  (stop server before update and start server after)

### Deprecated

- Support for Odoo 10 and below is now deprecated and will be removed in one of next releases.
  The python2 support is over, and there is no sense to continues to support odoo versions,
  that rely on unsupported python versions.

## Release 0.9.0 (2021-03-06)

### Added
- New options for `odoo-helper test` command:
    - `--test-db-name` that allows to specify name of test db to use to run tests
    - `--coverage-html-view` that will automatically open coverage report in browser when tests completed
- Added new option `--fm` or `--forward-migration` to `odoo-helper ci do-forwardport` command,
  that will automatically forwardport migrations to next serie.
  Currently it just renames migration files.
- Added new opts to `odoo-helper ci check-versions-git` command:
    - `--fix-version-minor` that could be used to increase minor part of version number in changed modules
    - `--fix-version-major` that could be used to increase major part of version number in changed modules
- Added new cmd `odoo-helper ci fix-versions` that could be used to fix version number in changed modules
- Added new shortcut to run version fix: `odoo-helper fix-versions`

### Changed
- `odoo-helper ci do-forwardport` now can automatically add manifests with fixed versions to index (if there are no other conflicts)
- `odoo-helper ci check-versions-git` argument `repo` is now optional,
  and by default, it assumes that repo path is current working directory,
  unless repo path is not specified explicitly

## Release 0.8.0 (2020-12-22)

### Added
- Aliase `odoo-helper addons link` that is same as `odoo-helper link`
- Aliase `odoo-helper addons test` that is same as `odoo-helper test`
- Added support for Odoo 14.0 (experimental)
- Added option `--pot-update` to `odoo-helper tr regenerate` command,
  that will automatically update translations according to .pot files
- Added option `--installable` to `doc-utils addons-list` command
- Added command `odoo-helper doc-utils addons-graph` that could be used to
  build dependency graph for all addons in specified directory.
- Added option `--show-log-on-error` for `odoo-helper addons install|update` commands.

### Changed
- Fail tests on `Comparing apples and oranges` warning
- Command `odoo-helper ci check-versions-git` now simplified and coulde be
  called with only single argument - path to repository

### Removed
- Removed command `odoo-helper db dump`
- Removed support for clonning Hg repositories
- Drop support for Ubuntu 16.04: odoo-helper have to be working there still, but without warranty.


## Release 0.7.0 (2020-08-17)

### Added

- Added `--recursive` option to `odoo-helper doc-utils addons-list` command
- Added `--tmp-dir` option to odoo-helper's database backup/restore commands
- Added `--node-version` option to `odoo-install` and
  to `odoo-helper install reinstall-venv` commands
- Added `--coverage-ignore-errors` option to `odoo-helper test` command
- Added ability to install addons via `odoo-helper install` command
- Added option `--all` to `odoo-helper odoo clean-compiled-assets`,
  that could be used to clean assets for all databases
- Added `--install-dir` option to `odoo-helper db create` command.
  This option allows to automatically install all addons from specified
  directory after creation of database.
- Added new shortcuts:
    - `odoo-helper lsa` -> `odoo-helper addons list`
    - `odoo-helper lsd` -> `odoo-helper db list`
- Added help message for `odoo-helper addons update-py-deps` command.
- Added command `odoo-helper db dump-manifest <dbname>` that allows
  to generate manifest for database backups.
  Could be used with external backup tools.
- Added command `odoo-helper postgres pg_dump`
- Added option `odoo-helper addons update --skip-errors` that allows to
  continue update event if there was error caught on update of single db,
  thus now it is possible to update all databases and show list of databases,
  that produced error in the end of operation
- Added command `odoo-helper ci push-changes` (experimental stage)
- Added command `odoo-helper ci do-forward-port` (experimental stage)
- Added option `--coverage-html-dir` to `odoo-helper test` command.
- Added hints where to view html coverage report after tests
- Added option `--missing-only` to command `tr regenerate` and `tr export`.
  So now it is possible to generate/regenerate only missing translations for addons.
- Added command `tr generate-pot` to generate .pot files
- Added option `tr regenerate --pot-remove-dates` to remove dates from generated pot files.

### Changed

- Refactored `odoo-helper update-sources` command:
    - add help message
    - if `ODOO_REPO` specified, try to download archive from this repo
    - if `ODOO_DOWNLOAD_SOURCE_LINK` specified, then use it to download Odoo archive
- `odoo-helper browse` now will start server automatically if it is not started yet
- `odoo-helper postgres user-create` if password not privided, then use `odoo` as password.
- Fail `odoo-helepr test` if there is attempt to write/create with unknown fields
- Fail `odoo-helper test` if there was error/warning while loading demo data
- `odoo-helper db backup` refactored to avoid `base64` encoding / decoding.
  Additionally now it uses streams to dump file, so it have to be more
  memory friendly.
- `odoo-helper tr regenerate` command can now regenerate translations for
  multiple languages via single run. Also, it is possible to regenerate `.pot` files in same run.
- Disable sentry on database operations.
- Automatically replace `psycopg2` requirement with `psycopg2-binary`.
- Updated version of bundled virtualenv to *16.7.9*

### Deprecated

- `odoo-helper db dump` now deprecated.


## Release 0.6.0 (2020-01-28)

### Added

- `odoo-helper install py-tools` now also installs [jingtrang](https://pypi.org/project/jingtrang/).
  This tools is used to show better warning on parsing xml views
- Added option `--pot` for `odoo-helper tr regenerate` that allows to regenerate `.pot` files on modules
- Added option `--fix-version-fp` to `ci check-versions-git` command.
  This command allows to fix version numbers during forwardport changes from older version of Odoo to newer
- Added option `--fix-serie` to `ci check-versions-git` command.
- Added command `odoo-helper odoo recompute-menu`
- Added command `odoo-helper odoo clean-compiled-assets`
- Added `--no-backup` option to `odoo-helper install reinstall-venv` command
- Added `--custom-val` option to `odoo-helper doc-utils addons-list` command
- Added `odoo-helper python` command
- Added `odoo-helper ipython` command - just a fast way to install and run ipython
- Added `odoo-helper postgres locks-info` command
- Added `--http-host` option for `odoo-install` command


### Changed

- Enabled following warings in defaut pylint config:
    - trailing-newlines
    - wrong-import-order
    - no-else-raise
    - consider-using-in
    - relative-beyond-top-level
    - useless-object-inheritance
    - duplicate-except
    - trailing-whitespace
    - self-cls-assignment
    - consider-using-get
    - consider-using-set-comprehension
    - consider-using-dict-comprehension
    - unnecessary-semicolon
    - singleton-comparison
    - unneeded-not
    - too-many-nested-blocks
    - logging-too-many-args
    - redundant-unittest-assert
    - implicit-str-concat-in-sequence
    - simplifiable-if-expression
    - lost-exception
    - useless-return
    - global-statement
    - too-many-boolean-expressions
    - empty-docstring
    - try-except-raise
- Command `odoo-helper db drop` changed:
    - config file now is option (befor it was positional argument)
    - added ability to drop multiple databases at single call
- Run `odoo-helper odoo shell` with implicit `--no-http` option, to avoid conflicts with running odoo

### Fixed

- Fixed `--fix-version` option of `odoo-helper ci check-versions-git` command.
  Before this fix, only Odoo serie was updated.
  After this fix, version number updated too.
- Compatability fix for `odoo-helper tr rate` command with Odoo 13.0
- Load server-wide modules when interacting via lodoo (local odoo)
- Improve the way to run odoo with server users, to avoid loosing environment variables.


## Release 0.5.0 (2019-09-01)

### Added

- Added command `odoo-helper install dev-tools` that is just an alias to install
  *bin-tools*, *py-tools* and *js-tools* with single command.
- Param `--db` to `odoo-helper addons find-installed` to search for addons only
  in specified databases.
- Option `--coverage-fail-under` to `odoo-helper test` command
- Option `--skip-re` to `odoo-helper test` command
- Option `--except-filter` to `odoo-helper addons list` command
- Command `odoo-helper ci ensure-changelog`
- Command `odoo-helper install unoconv`
- Command `odoo-helper install openupgradelib`
- Shortcuts of `odoo-install` command:
    - `--ocb` - use [OCB (Odoo Community Backports)](https://github.com/OCA/OCB) repo.
    - `--openupgrade` - use [Open Upgrade](https://github.com/OCA/OpenUpgrade) repo.
- Extra options to command `odoo-helper db create`:
    - `--password` set password to database user
    - `--country` country code to create db for
- Extra option to `odoo-install` command
    - `--http-port` specify port for this odoo instance
- New option `--no-unbuffer` that is helpful to run `odoo shell` command
  (odoo-helper server run --no-unbuffer -- shell -d my-database-name)
- New `odoo-helper odoo shell` command
- New option `--install` or `-i` to `odoo-helper db create` command
  designed to automatically install specified addons after db created.
- New option `--time` for `odoo-helper test` command
- New option `--no-single-branch` to `odoo-install` command

### Changed

- `odoo-helper fetch` refactored. Changed path repository is stored at.
  Before this release, all fetched repositories were stored at `/reppositories/`
  directory. After this release new fetched repositories will be stored on path
  similar to their path on github. For example there is repository
  `https://github.com/crnd-inc/crnd-web`. Before this release this repository
  was saved at `/repositories/crnd-web` after this release,
  repository will be stored at `/repositories/crnd-inc/crnd-web`.
  This change have to be backward compatible, but be careful.
- Use default database backup format: *zip*
- Enabled following warings in defaut pylint config:
    - trailing-comma-tuple
    - deprecated-method
- Following DB-related commands changed to have `--help` option.
  This change is backward incompatible. Commands:
    - `odoo-helper db dump --help`
    - `odoo-helper db backup --help`
    - `odoo-helper db backup-all --help`
    - `odoo-helper db restore --help`
- Command 'odoo-helper db list' now ignores `list_db` setting

### Fixed

- bug when "odoo-helper test" does not receive --skip argument
- regression of "odoo-helper addons uninstall" command.
- regression of "odoo-helper install wkhtmltopdf" command.
- bug in "odoo-helper odoo-py" command (related to usage of unbuffer)
- install specific version of `lessc`: 3.9.0 (version 3.10.0 seems to be buggy)

### Migration notes

#### New repository layout

Migrating to new repository layout could be done by following alogorithm:

```bash
# change working directory to odoo-project rool and save all repositories in
# requirements file

odoo-helper addons generate-requirements > odoo-requirements-tmp.txt

# Rename your current repository directory and create new empty 'repositories' dir
# This is required to save your current repositories state in case of uncommited changes.
mv repositories repositories-backup
mkdir repositories

# Fetch all your repositories with new layout enabled
odoo-helper fetch --requirements odoo-requirements-tmp.txt

# remove temporary requirements file
rm odoo-requirements-tmp.txt
```


## Release 0.4.0 (2019-05-03)

### Added

- Added command *odoo-helper addons find-installed*.
  Scan all databases for installed addons.
- Added aliases (shortcuts):
    - `odoo-helper-link`
    - `odoo-helper-addons-update`
- Experimental option `odoo-helper fetch --odoo-app <app_name>` that
  will automatically download module from Odoo Market
- Added option to `odoo-helper odoo recompute --db`
    - same as `-d` and `--dbname`
- Added command `odoo-helper db is-demo` to check if database contains demo-data

### Fixed

- Fixed bug with install/update addons via `odoo-helper addons install`
  and `odoo-helper addons update` commands, when addons were always installed with demo-data.
  This happened, because we have to explicitly tell Odoo that we do not need to install demo-data.

### Changed

- Changed `odoo-helper pull-updates` command
    - Now it does not update addons list automatically
    - Added `--ual` option to update addons list
    - Added `--do-update` option to update addons just after pull
    - Added `--help` options
    - First positional argument not applicable for it.
      Added option `--addons-dir` instead .
- Refactored `odoo-helper lint pylint` command
    - `consider-using-ternary` warning enabled by default
    - `unused-import` warning enabled by default
- Default timeouts for `wget` increased `2` -> `15` to be able to
  download Odoo via low-speed networks
- Changed bundled [virtualenv](https://virtualenv.pypa.io/en/latest/) version to `16.4.3`
- Command `odoo-helper ci check-versions-git` will ignore addons that are not installable.

### Removed

- `odoo-helper test pylint` command removed. Use `odoo-helper lint pylint`
- `odoo-helper test flake8` command removed. Use `odoo-helper lint flake8`

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
