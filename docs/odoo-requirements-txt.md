# odoo\_requirements.txt

*odoo_requirements.txt* parsed line by line, and each line
must be set of options for [odoo-helper fetch](./command-reference.md#odoo-helper-fetch) command.

## Format

### Fetch addons form any git repository

```
-r|--repo <git repository>  [-b|--branch <git branch>] [-m|--module <odoo module name>] [-n|--name <repo name>]
```

### Fetch addons from github repository

```
--github <github username/reponame> [-b|--branch <git branch>] [-m|--module <odoo module name>] [-n|--name <repo name>]
```

### Fetch [OCA](https://odoo-community.org/) addons from any [OCA github repository](https://github.com/OCA)

```
--oca <OCA reponame> [-b|--branch <git branch>] [-m|--module <odoo module name>] [-n|--name <repo name>]
```

### Fetch addons direcly from [Odoo Apps](https://apps.odoo.com/apps)

```
--odoo-app <app name>
```

### Parse another *odoo_requirments.txt* file

```
--requirements <requirements file>
```

## Notes

***Note*** *odoo_requirements.txt* must end with newline symbol.

## Examples

```
--github crnd-inc/generic-addon --module generic_tags -b 12.0
--oca project -m project_description
--odoo-app bureaucrat_helpdesk_lite
```

For details run ```odoo-helper fetch --help```
