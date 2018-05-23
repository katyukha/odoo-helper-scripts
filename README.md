# Odoo helper scripts collection

| Master        | [![Build Status](https://travis-ci.org/katyukha/odoo-helper-scripts.svg?branch=master)](https://travis-ci.org/katyukha/odoo-helper-scripts) [![Coverage Status](https://codecov.io/gh/katyukha/odoo-helper-scripts/graph/badge.svg)](https://codecov.io/gh/katyukha/odoo-helper-scripts) | [![Release](https://img.shields.io/github/release/katyukha/odoo-helper-scripts.svg)](https://github.com/katyukha/odoo-helper-scripts/releases) [![Release Date](https://img.shields.io/github/release-date/katyukha/odoo-helper-scripts.svg)](https://github.com/katyukha/odoo-helper-scripts/releases) | [![Last Commit](https://img.shields.io/github/last-commit/katyukha/odoo-helper-scripts/master.svg)](https://github.com/katyukha/odoo-helper-scripts/commits/master) | [![CHANGELOG](https://img.shields.io/badge/CHANGELOG-master-brightgreen.svg)](https://github.com/katyukha/odoo-helper-scripts/blob/master/CHANGELOG.md)              |
| ------------- |:---------------|:------------|:------------|:----------|
| Dev           | [![Build Status](https://travis-ci.org/katyukha/odoo-helper-scripts.svg?branch=dev)](https://travis-ci.org/katyukha/odoo-helper-scripts) [![Coverage Status](https://codecov.io/gh/katyukha/odoo-helper-scripts/branch/dev/graph/badge.svg)](https://codecov.io/gh/katyukha/odoo-helper-scripts/branch/dev) |   | [![Last Commit](https://img.shields.io/github/last-commit/katyukha/odoo-helper-scripts/dev.svg)](https://github.com/katyukha/odoo-helper-scripts/commits/dev) | [![CHANGELOG](https://img.shields.io/badge/CHANGELOG-dev-yellow.svg)](https://github.com/katyukha/odoo-helper-scripts/blob/dev/CHANGELOG.md) |

## Features

- Easily manage few instances of odoo that ran on same machine
- High usage of [virtualenv](https://virtualenv.pypa.io/en/stable/) for isolation purpose
- Use [nodeenv](https://pypi.python.org/pypi/nodeenv) to install [node.js](https://nodejs.org/en/), [phantom.js](http://phantomjs.org/), etc in isolated [virtualenv](https://virtualenv.pypa.io/en/stable/)
- Powerful testing capabilities, including support for:
    - python and js code check via [pylint\_odoo](https://pypi.python.org/pypi/pylint-odoo) (which uses [ESLint](https://eslint.org/) to check JS files)
    - python code check via [flake8](https://pypi.python.org/pypi/flake8)
    - styles (*.css*, *.scss*, *.less* files) check via [stylelint](https://stylelint.io/)  (**experimental**)
    - compute test code coverage via [coverage.py](https://coverage.readthedocs.io)
    - Test web tours via [phantom.js](http://phantomjs.org/)
- Easy addons installation
    - Automatiacly resolve and fetch dependencies
        - oca\_dependencies.txt ([sample](https://github.com/OCA/maintainer-quality-tools/blob/master/sample_files/oca_dependencies.txt), [mqt tool code](https://github.com/OCA/maintainer-quality-tools/blob/master/sample_files/oca_dependencies.txt))
        - [requirements.txt](https://pip.readthedocs.io/en/stable/user_guide/#requirements-files)
    - Specific file format to track addon dependencies: [odoo\_requirements.txt](docs/odoo-requirements-txt.md)
    - installation from *git* repositories
    - installation from *Mercurial* repositories (**experimental**)
    - installation of python dependencies from [PyPI](pypi.python.org/pypi) or any [vcs supported by setuptools](https://setuptools.readthedocs.io/en/latest/setuptools.html?highlight=develop%20mode#dependencies-that-aren-t-in-pypi) (automatically process *requirements.txt* files in repository and anddon directories.
    - shortcuts that simplifies fetching addons from [OCA](https://github.com/OCA) or [github](https://github.com)
    - works good with long recursive dependencies.
      One of the reasons for this script collection development was,
      ability to automaticaly install more that 50 addons,
      that depend on each other, and where each addon have it's own git repo.
- Supported odoo versions:
    - *7.0* (some functionality may not work),
    - *8.0*
    - *9.0*
    - *10.0*
    - *11.0*
- OS support:
    - On *Ubuntu* should work nice
    - Also should work on *Debian* based systems, but some troubles may happen with installation of system dependencies.
    - Other linux systems - in most cases should work, but system dependecies must be installed manualy.


## Documentation

***Note*** Documentaion in this readme, or in other sources, may not be up to date!!!
So use ``--help`` option, which is available for most of commands.

- [Documentation](docs/README.md)
- [Installation](docs/installation.md)
- [Frequently used commands](docs/frequently-used-commands.md)


## Usage note

This script collection is designed to simplify life of addons developer.
This project ***is not*** designed, to install and configure production ready Odoo instances!!!
To install Odoo in production read [Odoo official installation doc](https://www.odoo.com/documentation/10.0/setup/install.html) first.
Also, it is possible to manage almost any Odoo intance with this project, if it will be configured right.

## Installation

For full list of installation options look at [installation documentation](docs/installation.md)

To install *odoo-helper-scripts* system-wide do folowing:

```bash
# Install odoo-helper-scripts
wget -O - https://raw.githubusercontent.com/katyukha/odoo-helper-scripts/master/install-system.bash | sudo bash -s

# Install system dependencies required for odoo-helper-scripts
# NOTE: Works only on debian-based systems
odoo-helper install pre-requirements
```

or more explicit way:

```bash
# Download installation script
wget -O /tmp/odoo-helper-install.bash https://raw.githubusercontent.com/katyukha/odoo-helper-scripts/master/install-system.bash;

# Install odoo-helper-scripts
sudo bash /tmp/odoo-helper-install.bash;

#  Intall system pre-requirements for odoo-helper-scripts
# NOTE: Works only on debian-based systems
odoo-helper install pre-requirements
```

## Test your OS support

It is possible to run basic tests via docker. For this task, odoo-helper-scripts repo
contains script ```run_docker_test.bash```. Run ```bash run_docker_test.bash --help``` to
see all available options for that script.

For example to test, how odoo-helper-scripts will work on debian:stretch, do following:
```cd $ODOO_HELPER_ROOT; bash run_docker_test.bash --docker-ti --docker-image debian:stretch```


## Usage

And after install you will have available folowing scripts in your path:

- odoo-install
- odoo-helper

Each script have ``-h`` or ``--help`` option which display most relevant information
about script and all possible options and subcommands of script

Also there are some aliases for common commands:

- odoo-helper-addons
- odoo-helper-db
- odoo-helper-fetch
- odoo-helper-log
- odoo-helper-restart
- odoo-helper-server
- odoo-helper-test

For more info look at [documentation](docs/README.md). (currently documentation status is *work-in-progress*).
Also look at [Frequently used commands](docs/frequently-used-commands.md)

Also look at [odoo-helper-scripts tests](./tests/test.bash) to get complete usage example (look for *Start test* comment).
