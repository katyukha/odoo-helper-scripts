# -*- coding: utf-8 -*-
# Copyright © 2017-2018 Dmytro Katyukha <dmytro.katyukha@gmail.com>

#######################################################################
# This Source Code Form is subject to the terms of the Mozilla Public #
# License, v. 2.0. If a copy of the MPL was not distributed with this #
# file, You can obtain one at http://mozilla.org/MPL/2.0/.            #
#######################################################################

""" Local odoo connection lib
"""
import io
import os
import re
import sys
import json
import atexit
import logging
import functools
import contextlib
import pkg_resources

import click


# Import odoo package
try:
    # Odoo 10.0+

    # this is required if there are addons installed via setuptools_odoo
    # Also, this needed to make odoo10 work, if running this script with
    # current working directory set to project root
    if sys.version_info.major == 2:
        pkg_resources.declare_namespace('odoo.addons')

    # import odoo itself
    import odoo
    import odoo.release  # to avoid 9.0 with odoo.py on path
except (ImportError, KeyError):
    try:
        # Odoo 9.0 and less versions
        import openerp as odoo
    except ImportError:
        raise

if odoo.release.version_info < (8,):
    raise ImportError(
        "Odoo version %s is not supported!" % odoo.release.version_info)

_logger = logging.getLogger(__name__)

# Color constants
NC = '\x1b[0m'
REDC = '\x1b[31m'
GREENC = '\x1b[32m'
YELLOWC = '\x1b[33m'
BLUEC = '\x1b[34m'
LBLUEC = '\x1b[94m'

# Prepare odoo environments
os.putenv('TZ', 'UTC')
os.putenv('PGAPPNAME', 'lodoo')


class LocalModel(object):
    """ Simple wrapper for Odoo models

        just proxy method calls to model class
    """
    def __init__(self, client, name):
        self._client = client
        self._name = name

    def __getattr__(self, name):
        def wrapper(*args, **kwargs):
            """ Model method wrapper
            """
            return self._client.call_method(self._name, name, *args, **kwargs)
        return wrapper


class LocalRegistry(object):
    """ Simple proxy for Odoo registry
    """
    def __init__(self, client, dbname):
        self._client = client
        self._dbname = dbname

        self.registry = self.odoo.registry(self._dbname)
        self.cursor = self.registry.cursor()
        self._env = self.odoo.api.Environment(
            self.cursor, self.odoo.SUPERUSER_ID, {})

    @property
    def odoo(self):
        return self._client.odoo

    @property
    def env(self):
        return self._env

    @property
    def cr(self):
        return self.env.cr

    def recompute_fields(self, model, fields):
        """ Recompute specifed model fields

            This usualy applicable for stored, field, that was not recomputed
            due to errors in compute method for example.
        """
        Model = self.env[model]
        records = Model.search([])
        for field in fields:
            self.env.add_todo(Model._fields[field], records)
        Model.recompute()
        self.env.cr.commit()

    def recompute_parent_store(self, model):
        """ Recompute parent store

            some times parent left/right was not recomputed after update.
            this method can fix it
        """
        self.env[model]._parent_store_compute()
        self.env.cr.commit()

    def compute_translation_rate(self, lang, addons):
        trans = self.env['ir.translation'].search([
            ('module', 'in', addons),
            ('lang', '=', lang),
        ])

        def filter_bad_translations(t):
            """ Return True if translation is bad, otherwise return False
            """
            return (
                not t.value or
                not t.value.strip() or
                t.src == t.value or
                (getattr(t, 'source', None) and t.source == t.value)
            )

        bad_translations = trans.filtered(filter_bad_translations)

        rate_by_addon = {}
        for addon in addons:
            addon_data = rate_by_addon[addon] = {}

            addon_data['terms_total'] = trans_total = len(trans.filtered(
                lambda r: r.module == addon))
            addon_data['terms_untranslated'] = trans_fail = len(
                bad_translations.filtered(lambda r: r.module == addon))

            if trans_total:
                addon_data['rate'] = 1.0 - (float(trans_fail) /
                                            float(trans_total))
            else:
                addon_data['rate'] = 1.0

            addon_data['rate'] *= 100.0

        if trans:
            total_rate = 1.0 - float(len(bad_translations)) / float(len(trans))
        else:
            total_rate = 0.0

        total_rate *= 100.0
        return {
            'total_rate': total_rate,
            'terms_total': len(trans),
            'terms_untranslated': len(bad_translations),
            'by_addon': rate_by_addon,
        }

    def print_translation_rate(self, translation_rate, colored=False):
        """ Print translation rate computed by `compute_translation_rate`
        """
        name_col_width = max([len(i) for i in translation_rate['by_addon']])

        header_format_str = "%%-%ds | %%10s | %%15s | %%+10s" % name_col_width
        row_format_str = "%%-%ds | %%10s | %%15s | %%7.2f" % name_col_width
        row_format_colored_str = (
            "%%-%ds | %%10s | %%15s | {color}%%7.2f{nocolor}" % name_col_width)
        spacer_str = "-" * (name_col_width + 3 + 10 + 3 + 15 + 3 + 10)

        def format_addon_rate(addon, rate_data, colored=colored):
            rate = rate_data['rate']
            format_str = row_format_str
            if colored and rate < 75.0:
                format_str = row_format_colored_str.format(
                    color=REDC, nocolor=NC)
            elif colored and rate < 90:
                format_str = row_format_colored_str.format(
                    color=YELLOWC, nocolor=NC)
            elif colored:
                format_str = row_format_colored_str.format(
                    color=GREENC, nocolor=NC)
            return format_str % (
                addon, rate_data['terms_total'],
                rate_data['terms_untranslated'],
                rate_data['rate'],
            )

        # Print header
        print(header_format_str % (
            'Addon', 'Total', 'Untranslated', 'Rate'))
        print(spacer_str)

        # Print translation rate by addon
        for addon, rate_data in translation_rate['by_addon'].items():
            print(format_addon_rate(addon, rate_data, colored=colored))

        # Print total translation rate
        print(spacer_str)
        print(
            row_format_str % (
                'TOTAL', translation_rate['terms_total'],
                translation_rate['terms_untranslated'],
                translation_rate['total_rate']))

    def assert_translation_rate(self, rate, min_total_rate=None,
                                min_addon_rate=None):
        """ Check translation rate, and return number, that can be used as exit
            code
        """
        if min_total_rate is not None and rate['total_rate'] < min_total_rate:
            return 1

        if min_addon_rate is not None:
            for addon, rate_data in rate['by_addon'].items():
                if rate_data['rate'] < min_addon_rate:
                    return 2
        return 0

    def check_translation_rate(self, lang, addons, min_total_rate=None,
                               min_addon_rate=None, colored=False):
        """ Check translation rate
        """
        trans_rate = self.compute_translation_rate(lang, addons)
        self.print_translation_rate(trans_rate, colored=colored)
        return self.assert_translation_rate(
            trans_rate,
            min_total_rate=min_total_rate,
            min_addon_rate=min_addon_rate)

    def generate_pot_file(self, module_name, remove_dates):
        """ Generate .pot file for a module
        """
        try:
            module_path = self.odoo.modules.module.get_module_path(module_name)
            i18n_dir = os.path.join(module_path, 'i18n')
            if not os.path.exists(i18n_dir):
                os.mkdir(i18n_dir)
            pot_file = os.path.join(i18n_dir, '%s.pot' % module_name)

            with contextlib.closing(io.BytesIO()) as buf:
                self.odoo.tools.trans_export(
                    None, [module_name], buf, 'po', self.cr)
                data = buf.getvalue().decode('utf-8')

            if remove_dates:
                data = re.sub(
                    r'"POT?-(Creation|Revision)-Date:.*?"[\n\r]',
                    '', data, flags=re.MULTILINE)

            with open(pot_file, 'wb') as pot_f:
                pot_f.write(data.encode('utf-8'))
        except Exception:
            _logger.error("Error", exc_info=True)
            raise

    def call_method(self, model, method, *args, **kwargs):
        """ Simple wrapper to call local model methods for database
        """
        # TODO: do we need this?
        # For odoo 8, 9, 10, +(?) there is special function `odoo.registry`
        # to get registry instance for db
        return getattr(self.env[model], method)(*args, **kwargs)

    def __getitem__(self, name):
        # TODO: may be it have sense to return here env[name] ?
        return LocalModel(self, name)


class LocalDBService(object):
    def __init__(self, client):
        self._client = client
        self._dispatch = None

    @property
    def odoo(self):
        return self._client.odoo

    @property
    def dispatch(self):
        if self._dispatch is None:
            self._dispatch = functools.partial(
                self.odoo.http.dispatch_rpc, 'db')
        return self._dispatch

    def create_database(self, *args, **kwargs):
        return self.odoo.service.db.exp_create_database(*args, **kwargs)

    def list_databases(self):
        if odoo.release.version_info < (9,):
            return self.list()
        return self.odoo.service.db.list_dbs(True)

    def restore_database(self, db_name, dump_file):
        self.odoo.service.db.restore_db(db_name, dump_file)
        return True

    def backup_database(self, db_name, backup_format, file_path):
        with open(file_path, 'wb') as f:
            self.odoo.service.db.dump_db(db_name, f, backup_format)
        return True

    def dump_db_manifest(self, dbname):
        """ Generate db manifest for backup

            :return str: JSON representation of manifest
        """
        registry = self.odoo.registry(dbname)
        with registry.cursor() as cr:
            # Just copy-paste from original Odoo code
            pg_version = "%d.%d" % divmod(
                cr._obj.connection.server_version / 100, 100)
            cr.execute("""
                SELECT name, latest_version
                FROM ir_module_module
                WHERE state = 'installed'
            """)
            modules = dict(cr.fetchall())
            manifest = {
                'odoo_dump': '1',
                'db_name': cr.dbname,
                'version': self.odoo.release.version,
                'version_info': self.odoo.release.version_info,
                'major_version': self.odoo.release.major_version,
                'pg_version': pg_version,
                'modules': modules,
            }
        return json.dumps(manifest, indent=4)

    def __getattr__(self, name):
        def db_service_method(*args):
            return self.dispatch(name, args)
        return db_service_method


class LOdoo(object):
    """ Wrapper for local odoo instance

        (Singleton)
    """
    __lodoo = None

    def __new__(cls, *args, **kwargs):
        if not cls.__lodoo:
            cls.__lodoo = super(LOdoo, cls).__new__(cls)
        return cls.__lodoo

    def __init__(self, conf_path):
        self._conf_path = conf_path
        self._odoo = None
        self._registries = {}
        self._db_service = None

    def start_odoo(self, options=None, no_http=False):
        """ Start the odoo services.
            Optionally provide extra options
        """
        if self._odoo:
            raise Exception("Odoo already started!")

        options = options[:] if options is not None else []

        if not any(
                o.startswith('--conf') or o.startswith('-c') for o in options):
            options += ["--conf=%s" % self._conf_path]

        # Set workers = 0 if other not specified
        if not any(o.startswith('--workers') for o in options):
            options.append('--workers=0')

        if no_http and odoo.release.version_info < (11,):
            options.append('--no-xmlrpc')
        elif no_http:
            options.append('--no-http')

        odoo.tools.config.parse_config(options)
        if odoo.tools.config.get('sentry_enabled', False):
            odoo.tools.config['sentry_enabled'] = False

        if odoo.release.version_info < (15,):
            if not hasattr(odoo.api.Environment._local, 'environments'):
                odoo.api.Environment._local.environments = (
                    odoo.api.Environments())

        # Load server-wide modules
        odoo.service.server.load_server_wide_modules()

        # Save odoo var on object level
        self._odoo = odoo

    @property
    def odoo(self):
        """ Return initialized Odoo package
        """
        if self._odoo is None:
            raise Exception(
                "Odoo is not started. please call 'start_odoo' method first.")
        return self._odoo

    @property
    def db(self):
        """ Return database management service
        """
        if self._db_service is None:
            self._db_service = LocalDBService(self)
        return self._db_service

    def get_registry(self, dbname):
        registry = self._registries.get(dbname, None)
        if registry is None:
            registry = self._registries[dbname] = LocalRegistry(self, dbname)
        return registry

    def __getitem__(self, name):
        return self.get_registry(name)


@atexit.register
def cleanup():
    """ Do clean up and close database connections on exit
    """
    if odoo.release.version_info < (10,):
        dbnames = odoo.modules.registry.RegistryManager.registries.keys()
    elif odoo.release.version_info < (13,):
        dbnames = odoo.modules.registry.Registry.registries.keys()
    else:
        dbnames = odoo.modules.registry.Registry.registries.d.keys()

    for db in dbnames:
        odoo.sql_db.close_db(db)


# Command Line Interface
@click.group()
@click.option('--conf', type=click.Path(exists=True))
@click.pass_context
def cli(ctx, conf):
    ctx.obj = LOdoo(conf)


@cli.command('db-list')
@click.pass_context
def db_list_databases(ctx):
    ctx.obj.start_odoo(['--logfile=/dev/null'])
    dbs = ctx.obj.db.list_databases()
    click.echo('\n'.join(['%s' % d for d in dbs]))


@cli.command('db-create')
@click.argument('dbname', required=True)
@click.option('--demo/--no-demo', type=bool, default=False)
@click.option('--lang', default='en_US')
@click.option('--password', default=None)
@click.option('--country', default=None)
@click.pass_context
def db_create_database(ctx, dbname, demo, lang, password, country):
    ctx.obj.start_odoo()
    kwargs = {}
    if password:
        kwargs['user_password'] = password
    if country and ctx.obj.odoo.release.version_info > (8,):
        kwargs['country_code'] = country
    ctx.obj.db.create_database(dbname, demo, lang, **kwargs)


@cli.command('db-exists')
@click.argument('dbname')
@click.pass_context
def db_exists_database(ctx, dbname):
    ctx.obj.start_odoo(['--logfile=/dev/null'])
    success = ctx.obj.db.db_exist(dbname)
    if not success:
        ctx.exit(1)


@cli.command('db-drop')
@click.argument('dbname')
@click.pass_context
def db_drop_database(ctx, dbname):
    ctx.obj.start_odoo()

    # TODO: Find a way to avoid reading it from config
    success = ctx.obj.db.drop(
        ctx.obj.odoo.tools.config['admin_passwd'], dbname)
    if not success:
        ctx.exit(1)
        raise click.ClickException("Cannot drop database %s" % dbname)


@cli.command('db-rename')
@click.argument('oldname')
@click.argument('newname')
@click.pass_context
def db_rename_database(ctx, oldname, newname):
    ctx.obj.start_odoo()

    ctx.obj.db.rename(
        ctx.obj.odoo.tools.config['admin_passwd'], oldname, newname)


@cli.command('db-copy')
@click.argument('srcname')
@click.argument('newname')
@click.pass_context
def db_copy_database(ctx, srcname, newname):
    ctx.obj.start_odoo()

    ctx.obj.db.duplicate_database(
        ctx.obj.odoo.tools.config['admin_passwd'], srcname, newname)


@cli.command('db-backup')
@click.argument('dbname')
@click.argument('dumpfile', type=click.Path(exists=False))
@click.option(
    '--format', '-f', '_format',
    type=click.Choice(['zip', 'sql']),
    default='zip')
@click.pass_context
def db_backup_database(ctx, dbname, dumpfile, _format):
    ctx.obj.start_odoo()
    ctx.obj.db.backup_database(dbname, _format, dumpfile)


@cli.command('db-restore')
@click.argument('dbname')
@click.argument('backup', type=click.Path(exists=True))
@click.pass_context
def db_restore_database(ctx, dbname, backup):
    ctx.obj.start_odoo()

    success = ctx.obj.db.restore_database(dbname, backup)
    if not success:
        ctx.exit(1)


@cli.command('db-dump-manifest')
@click.argument('dbname')
@click.pass_context
def db_dump_database_manifest(ctx, dbname):
    ctx.obj.start_odoo()
    click.echo(ctx.obj.db.dump_db_manifest(dbname))


@cli.command('addons-uninstall')
@click.argument('dbname')
@click.argument('addons')
@click.pass_context
def addons_uninstall_addons(ctx, dbname, addons):
    ctx.obj.start_odoo(
        ['--stop-after-init', '--max-cron-threads=0', '--pidfile=/dev/null'],
        no_http=True)

    db = ctx.obj[dbname]
    modules = db['ir.module.module'].search([
        ('name', 'in', addons.split(',')),
        ('state', 'in', ('installed', 'to upgrade', 'to remove')),
    ])
    modules.button_immediate_uninstall()
    click.echo(", ".join(modules.mapped('name')))


@cli.command('addons-update-list')
@click.argument('dbname')
@click.pass_context
def addons_update_module_list(ctx, dbname):
    ctx.obj.start_odoo(
        ['--stop-after-init', '--max-cron-threads=0', '--pidfile=/dev/null'],
        no_http=True,
    )

    db = ctx.obj[dbname]
    updated, added = db['ir.module.module'].update_list()
    db.cursor.commit()
    click.echo("updated: %d\nadded: %d\n" % (updated, added))


@cli.command('tr-generate-pot-file')
@click.argument('dbname')
@click.argument('addon')
@click.option('--remove-dates/--no-remove-dates', type=bool, default=False)
@click.pass_context
def translations_generate_pot_file(ctx, dbname, addon, remove_dates):
    ctx.obj.start_odoo()
    ctx.obj[dbname].generate_pot_file(addon, remove_dates)


@cli.command('tr-check-translation-rate')
@click.argument('dbname', type=str)
@click.argument('addons', type=str)
@click.option('--lang', '-l', type=str, required=True)
@click.option('--min-total-rate', type=int, default=None)
@click.option('--min-addon-rate', type=int, default=None)
@click.option('--colors/--no-colors', type=bool, default=False)
@click.pass_context
def translations_check_translations_rate(ctx, dbname, addons, lang,
                                         min_total_rate, min_addon_rate,
                                         colors):
    ctx.obj.start_odoo()
    res = ctx.obj[dbname].check_translation_rate(
        lang, addons.split(','),
        min_total_rate=min_total_rate,
        min_addon_rate=min_addon_rate,
        colored=colors,
    )
    ctx.exit(res)


@cli.command('odoo-recompute')
@click.argument('dbname')
@click.argument('model')
@click.option('--parent-store', type=bool, is_flag=True, default=False)
@click.option('--field', '-f', 'fields', multiple=True, default=[])
@click.pass_context
def odoo_recompute_fields(ctx, dbname, model, parent_store, fields):
    ctx.obj.start_odoo()

    if parent_store:
        ctx.obj[dbname].recompute_parent_store(model)
    else:
        ctx.obj[dbname].recompute_fields(model, fields)


@cli.command('run-py-script')
@click.argument('dbname')
@click.argument(
    'script-path',
    type=click.Path(
        exists=True, dir_okay=False, file_okay=True, resolve_path=True))
@click.pass_context
def odoo_run_python_script(ctx, dbname, script_path):
    ctx.obj.start_odoo(
        ['--stop-after-init', '--max-cron-threads=0', '--pidfile=/dev/null'],
        no_http=True)

    context = {
        'env': ctx.obj[dbname].env,
        'cr': ctx.obj[dbname].cr,
        'registry': ctx.obj[dbname].registry,
        'odoo': ctx.obj.odoo,
    }

    if sys.version_info.major < 3:
        execfile(script_path, globals(), context)  # noqa
    else:
        with open(script_path, "rt") as script_file:
            exec(script_file.read(), globals(), context)


if __name__ == '__main__':
    cli()
