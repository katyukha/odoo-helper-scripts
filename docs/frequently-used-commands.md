## Frequently used command

Brief list of frequently used odoo-helper commands

### Odoo server management
- `odoo-helper start` - start odoo server
- `odoo-helper restart` - restart odoo server
- `odoo-helper stop` - stop odoo-helper server
- `odoo-helper log` - see odoo server logs
- `odoo-helper server ps` - display odoo server processes for current project

### Odoo addons management
- `odoo-helper addons list <path>` - list odoo addons in specified directory
- `odoo-helper addons update-list` - update list of available addons in all databases available for this server
- `odoo-helper addons install <addon1> [addonn]` - install specified odoo addons for all databases available for this server
- `odoo-helper addons update <addon1> [addonn]` - update specified odoo addons for all databases available for this server
- `odoo-helper addons uninstall <addon1> [addonn]` - uninstall specified odoo addons for all databases available for this server

### Postgres related
- `odoo-helper postgres psql [-d database]` - connect to db via psql (same credentials as used by odoo server)
- `sudo odoo-helper postgres user-create <user name> <password>` - create postgres user for odoo

### Tests
- `odoo-helper test -m <module>` - test single module
- `odoo-helper test --dir .` - test all installable addons in current directory
- `odoo-helper test --coverage-html -m <module>` - test single module and create html coverage report in current dir
- `odoo-helper test --coverage-html --dir .` - test all installable addons in current directory and create html coverage report in current dir
- `odoo-helper test -m <module> --recreate-db` - test single module, but recreate test database first
- `odoo-helper test -m <module> --create-test-db` - test single module on just created clean database. database dropt after tests

### Linters
- `odoo-helper lint pylint .` - run pylint for all addons in current directory
- `odoo-helper lint flake8 .` - run flake8 for all addons in current directory
- `odoo-helper lint style .` - run stylelint for all addons in current directories
- `odoo-helper pylint` - alias for `odoo-helper lint pylint`
- `odoo-helper flake8` - alias for `odoo-helper lint flake8`
- `odoo-helper style` - alias for odoo-helper lint style`

### Fetch addons
- `odoo-helper link .` - create symlinks for all addons in current directory in `custom_addons` folder to make them visible for odoo
- `odoo-helper fetch --oca web` - fetch all addons from [OCA](https://odoo-community.org/) repository [web](https://github.com/OCA/web)
- `odoo-helper fetch --repo <repository url> --branch 11.0` - fetch all addons from specified repository

### Database management
- `odoo-helper db list` - list all databases available for current odoo instance
- `odoo-helper db create my_db` - create database
- `odoo-helper db backup my_db zip` - backup *my\_db* as ZIP archive (with filestore)
- `odoo-helper db backup my_db sql` - backup *my\_db* as SQL dump only (without filestore)
- `odoo-helper db drop my_db` - drop database

### Other
- `odoo-helper pip` - run `pip` inside current project's virtual environment [virtualenv](https://virtualenv.pypa.io/en/stable/).
- `odoo-helper npm` - run `npm` inside current project's virtual environment [nodeenv](https://pypi.python.org/pypi/nodeenv)
- `odoo-helper exec my-command` - run command inside project's virtual env


