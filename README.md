# Odoo helper scripts collection

| Master        | [![pipeline status](https://gitlab.com/katyukha/odoo-helper-scripts/badges/master/pipeline.svg)](https://gitlab.com/katyukha/odoo-helper-scripts/commits/master) |  [![coverage report](https://gitlab.com/katyukha/odoo-helper-scripts/badges/master/coverage.svg)](https://gitlab.com/katyukha/odoo-helper-scripts/commits/master)| [![CHANGELOG](https://img.shields.io/badge/CHANGELOG-master-brightgreen.svg)](https://gitlab.com/katyukha/odoo-helper-scripts/blob/master/CHANGELOG.md)              |
| ------------- |:---------------|:--------------|:------------|
| Dev           | [![pipeline status](https://gitlab.com/katyukha/odoo-helper-scripts/badges/dev/pipeline.svg)](https://gitlab.com/katyukha/odoo-helper-scripts/commits/dev) | [![coverage report](https://gitlab.com/katyukha/odoo-helper-scripts/badges/dev/coverage.svg)](https://gitlab.com/katyukha/odoo-helper-scripts/commits/dev) | [![CHANGELOG](https://img.shields.io/badge/CHANGELOG-dev-yellow.svg)](https://gitlab.com/katyukha/odoo-helper-scripts/blob/dev/CHANGELOG.md) |

## Overview

This project aims to simplify development process of Odoo addons as much as possible.

odoo-helper-scripts will do all routine operations for you:
- install odoo with ALL dependencies (even those not mentioned in odoo's requirements.txt like [python-slugify](https://pypi.org/project/python-slugify/))
- manage local development databases
- install custom addons
- check if versions of modules are updated before pushing changes.
- generate / regenerate translations
- run tests
- and a lot more

If you have any routine operation that you would like to automate with odoo-helper-scripts, just fill an issue or do pull request, and may be that feature will be available in one of next releases.

## Canonical source

The canonical source of odoo-helper-scripts is hosted on [GitLab](https://gitlab.com/katyukha/odoo-helper-scripts).

## Features

- Easily manage multiple instances of odoo that ran on same machine
- High usage of [virtualenv](https://virtualenv.pypa.io/en/stable/) for isolation purpose
- Use [nodeenv](https://pypi.python.org/pypi/nodeenv) to install [node.js](https://nodejs.org/en/), [phantom.js](http://phantomjs.org/), etc in isolated [virtualenv](https://virtualenv.pypa.io/en/stable/)
- The easiest way to install Odoo for development purposes
- Powerful testing capabilities, including support for:
    - *python* and *js* code check via [pylint\_odoo](https://pypi.python.org/pypi/pylint-odoo) (which uses [ESLint](https://eslint.org/) to check JS files)
    - *python* code check via [flake8](https://pypi.python.org/pypi/flake8)
    - styles (*.css*, *.scss*, *.less* files) check via [stylelint](https://stylelint.io/)
    - compute test code coverage via [coverage.py](https://coverage.readthedocs.io)
    - Test web tours via [phantom.js](http://phantomjs.org/) or *chromium browser* (Odoo 12.0+)
- Easy addons installation
    - Automatiacly resolve and fetch dependencies
        - oca\_dependencies.txt ([sample](https://github.com/OCA/maintainer-quality-tools/blob/master/sample_files/oca_dependencies.txt), [mqt tool code](https://github.com/OCA/maintainer-quality-tools/blob/master/sample_files/oca_dependencies.txt))
        - [requirements.txt](https://pip.readthedocs.io/en/stable/user_guide/#requirements-files)
    - Own file format to track addon dependencies: [odoo\_requirements.txt](https://katyukha.gitlab.io/odoo-helper-scripts/odoo-requirements-txt/)
    - installation directly from [Odoo Market](https://apps.odoo.com/apps) (**experimental**)
        - Only free addons
        - Including dependencies
        - Semi-automatic upgrade when new version released
    - installation from *git* repositories
    - installation from *Mercurial* repositories (**experimental**)
    - installation of python dependencies from [PyPI](pypi.python.org/pypi) or any [vcs supported by setuptools](https://setuptools.readthedocs.io/en/latest/setuptools.html?highlight=develop%20mode#dependencies-that-aren-t-in-pypi)
    - automatically processing of [requirements.txt](https://pip.pypa.io/en/stable/user_guide/#requirements-files) files located inside repository root and addon directories.
    - shortcuts that simplifies fetching addons from [OCA](https://github.com/OCA) or [github](https://github.com)
    - works good with long recursive dependencies.
      One of the reasons for this script collection development was,
      ability to automaticaly install more that 50 addons,
      that depend on each other, and where each addon have it's own git repo.
- Easy database management
    - easily create / drop / backup / rename / copy databases
- Continious Integration related features
    - ensure addon version changed
    - ensure repository version changed
    - ensure each addon have icon
    - ensure all changed addon has correct versions
    - simplify forward-port process (move changes from older serie to newer (for example from 11.0 to 12.0))
- Translation management from command line
    - import / export translations by command from shell
    - test translation rate for specified language
    - regenerate translations for specified language
    - generate *.pot* files for modules
    - load language (for one db or for old databases)
- Supported odoo versions:
    - *8.0*
    - *9.0*
    - *10.0*
    - *11.0*
    - *12.0*
    - *13.0* (requires ubuntu 18.04+ or other linux distribution with python 3.6+)
    - *14.0* (experimental support)
- OS support:
    - On *Ubuntu* should work nice (auto tested on *Ubuntu 16.04, 18.04, 20.04*)
    - Also should work on *Debian* based systems, but some troubles may happen with installation of system dependencies.
    - Other linux systems - in most cases should work, but system dependecies must be installed manualy.
- Missed feature? [Fill an issue](https://gitlab.com/katyukha/odoo-helper-scripts/issues/new)


## Documentation

***Note*** Documentaion in this readme, or in other sources, may not be up to date!!!
So use ``--help`` option, which is available for most of commands.

- [Documentation](https://katyukha.gitlab.io/odoo-helper-scripts/)
- [Installation](https://katyukha.gitlab.io/odoo-helper-scripts/installation/)
- [Frequently used commands](https://katyukha.gitlab.io/odoo-helper-scripts/frequently-used-commands/)
- [Command Reference](https://katyukha.gitlab.io/odoo-helper-scripts/command-reference/)


## Usage note

This script collection is designed to simplify life of addons developer.
This project ***is not*** designed, to install and configure production ready Odoo instances, unless you know what you do!

For **production-ready** installations take a look at [crnd-deploy](http://github.com/crnd-inc/crnd-deploy) project - just a single command allows you to get production-ready odoo instance with configured [PostgreSQL](https://www.postgresql.org/) and [Nginx](https://nginx.org/).

Also take a look at [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit) project, and discover the easiest way to manage your production Odoo installations with automated billing and support of custom addons.

[![Yodoo Cockpit](https://crnd.pro/web/image/18846/banner_2_4_gif_animation_cut.gif)](https://crnd.pro/yodoo-cockpit)

Just short notes about [Yodoo Cockpit](https://crnd.pro/yodoo-cockpit):
- start new production-ready odoo instance in 1-2 minutes.
- add custom addons to your odoo instances in 5-10 minutes.
- out-of-the-box email configuration: just press button and add some records to your DNS, and get a working email
- make your odoo instance available to external world (internet) in 30 seconds (just add single record in your DNS)


## Level up your service quality

Level up your service quality with [Helpdesk](https://crnd.pro/solutions/helpdesk) / [Service Desk](https://crnd.pro/solutions/service-desk) / [ITSM](https://crnd.pro/itsm) solution by [CR&D](https://crnd.pro/).

Just test it at [yodoo.systems](https://yodoo.systems/saas/templates): choose template you like, and start working.

Test all available features of [Bureaucrat ITSM](https://crnd.pro/itsm) with [this template](https://yodoo.systems/saas/template/bureaucrat-itsm-demo-data-95).


## Installation

For full list of installation options look at [installation documentation](https://katyukha.gitlab.io/odoo-helper-scripts/installation/)

*Starting from 0.1.7 release odoo-helper-scripts could be installed as* [.deb packages](https://katyukha.gitlab.io/odoo-helper-scripts/installation#install-as-deb-package)*,
but this feature is still experimental. See* [releases](https://gitlab.com/katyukha/odoo-helper-scripts/tags) *page.*

To install *odoo-helper-scripts* system-wide (the recommended way) do folowing:

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

## Test your OS support

It is possible to run basic tests via docker.
For this task, odoo-helper-scripts repo contains script `scripts/run_docker_test.bash`.
Run `bash scripts/run_docker_test.bash --help` to see all available options for that script.

For example to test, how odoo-helper-scripts will work on debian:stretch, do following:

```bash
cd $ODOO_HELPER_ROOT
bash scripts/run_docker_test.bash --docker-ti --docker-image debian:stretch
```

Note, running tests may take more then 1:30 hours.


## Usage

And after install you will have available folowing scripts in your path:

- odoo-install
- odoo-helper

Each script have `-h` or `--help` option which display most relevant information
about script and all possible options and subcommands of script

Also there are some aliases for common commands:

- odoo-helper-addons
- odoo-helper-db
- odoo-helper-fetch
- odoo-helper-log
- odoo-helper-restart
- odoo-helper-server
- odoo-helper-test

For more info look at [documentation](https://katyukha.gitlab.io/odoo-helper-scripts/). (currently documentation status is *work-in-progress*).
Also look at [Frequently used commands](https://katyukha.gitlab.io/odoo-helper-scripts/frequently-used-commands/) and [Command reference](https://katyukha.gitlab.io/odoo-helper-scripts/command-reference/)

Also look at [odoo-helper-scripts tests](./tests/test.bash) to get complete usage example (look for *Start test* comment).

## Support

Have you any quetions? Just [fill an issue](https://gitlab.com/katyukha/odoo-helper-scripts/issues/new) or [send email](mailto:incoming+katyukha/odoo-helper-scripts@incoming.gitlab.com)
