# Syntax of odoo\_requirements.txt

*odoo_requirements.txt* parsed line by line, and each line
must be just set of options for ```odoo-helper fetch``` command:

```
-r|--repo <git repository>  [-b|--branch <git branch>] [-m|--module <odoo module name>] [-n|--name <repo name>]
--requirements <requirements file>
-p|--python <python module>

```

Also there are shorter syntax for specific repository sources:

- ```--github user/repository``` for github repositories
- ```--oca repository``` of Odoo Comunity Assiciation repositories

Fore example:

```
--github katyukha/base_tags --module base_tags -b master
--oca project-service -m project_sla
```

For details run ```odoo-helper fetch --help```


