# -*- coding: utf-8 -*-
""" Local odoo connection lib
"""
import os
import atexit
import pkg_resources


import erppeek


def get_odoo_pkg():
    try:
        # Odoo 10.0+

        # this is required if there are addons installed via setuptools_odoo
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
    return odoo


# Based on code: https://github.com/tinyerp/erppeek
# With PR applied: https://github.com/tinyerp/erppeek/pull/92
def start_odoo_services(options=None, appname='odoo-helper'):
    """Initialize the Odoo services.
    Import the ``openerp`` package and load the Odoo services.
    The argument `options` receives the command line arguments
    for ``openerp``.  Example:
      ``['-c', '/path/to/openerp-server.conf', '--without-demo', 'all']``.
    Return the ``openerp`` package.
    """
    odoo = get_odoo_pkg()
    odoo._api_v7 = odoo.release.version_info < (8,)
    if not (odoo._api_v7 and odoo.osv.osv.service):
        os.putenv('TZ', 'UTC')
        if appname is not None:
            os.putenv('PGAPPNAME', appname)
        odoo.tools.config.parse_config(options or [])
        if odoo.release.version_info < (10,):
            odoo._registry = odoo.modules.registry.RegistryManager
        else:
            odoo._registry = odoo.modules.registry.Registry
        if odoo.release.version_info < (7,):
            odoo.netsvc.init_logger()
            odoo.osv.osv.start_object_proxy()
            odoo.service.web_services.start_web_services()
        elif odoo._api_v7:
            odoo.service.start_internal()
        else:   # Odoo v8
            try:
                odoo.api.Environment._local.environments = \
                    odoo.api.Environments()
            except AttributeError:
                pass

        def close_all():
            for db in odoo._registry.registries.keys():
                odoo.sql_db.close_db(db)
        atexit.register(close_all)

    return odoo


# Monkeypatch erppeeks start services to be compatible with odoo 10.0
erppeek.start_odoo_services = start_odoo_services

# look same as erppeek
from erppeek import *


class LocalModel(object):
    def __init__(self, client, name):
        self._client = client
        self._name = name

    def __getattr__(self, name):
        def wrapper(*args, **kwargs):
            return self._client.call_method(self._name, name, *args, **kwargs)
        return wrapper


class LocalClient(object):
    """ Wrapper for local odoo instance
    """
    def __init__(self, db, options=None):
        if options is None:
            options = []

        self.odoo = start_odoo_services(options)
        if self.odoo._api_v7:
            self.registry = self.odoo.modules.registry.RegistryManager.get(db)
            self.cursor = self.registry.db.cursor()
            self._env = None
        else:
            # For odoo 8, 9, 10, +(?) there is special function `odoo.registry`
            # to get registry instance for db
            self.registry = self.odoo.registry(db)
            self.cursor = self.registry.cursor()
            self._env = self.odoo.api.Environment(
                self.cursor, self.odoo.SUPERUSER_ID, {})

    @property
    def env(self):
        self.require_v8_api()
        return self._env

    def require_v8_api(self):
        if self.odoo._api_v7:
            raise NotImplementedError(
                "Using *env* is not supported for this Odoo version")

    def recompute_fields(self, model, fields):
        """ Recompute specifed model fields

            This usualy applicable for stored, field, that was not recomputed
            due to errors in compute method for example.
        """
        model = self.env[model]
        records = model.search([])
        for field in fields:
            self.env.add_todo(model._fields[field], records)
        model.recompute()
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
        bad_translations = trans.filtered(
            lambda r: not r.value or
                      not r.value.strip() or
                      r.src == r.value or
                      r.source == r.value)

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
                addon_data['rate'] = 0.0

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

    def print_translation_rate(self, translation_rate):
        """ Print translation rate computed by `compute_translation_rate`
        """
        name_col_width = max([len(i) for i in translation_rate['by_addon']])

        header_format_str = "%%-%ds | %%10s | %%15s | %%+10s" % name_col_width
        row_format_str = "%%-%ds | %%10s | %%15s | %%7.2f" % name_col_width
        spacer_str = "-" * (name_col_width + 3 + 10 + 3 + 15 + 3 + 10)

        # Print header
        print (header_format_str % (
               'Addon', 'Total', 'Untranslated', 'Rate'))
        print (spacer_str)

        # Print translation rate by addon
        for addon, rate_data in translation_rate['by_addon'].items():
            print(row_format_str % (
                  addon, rate_data['terms_total'],
                  rate_data['terms_untranslated'],
                  rate_data['rate']))

        # Print total translation rate
        print (spacer_str)
        print(row_format_str % (
              'TOTAL', translation_rate['terms_total'],
              translation_rate['terms_untranslated'],
              translation_rate['total_rate'],
        ))

    def assert_translation_rate(self, rate, min_total_rate=None,
                                min_addon_rate=None):
        """ Check translation rate, and return number, that can be used as exit
            code
        """
        if min_total_rate is not None and rate['total_rate'] < min_total_rate:
            return 1;

        if min_addon_rate is not None:
            for addon, rate_data in rate['by_addon'].items():
                if rate_data['rate'] < min_addon_rate:
                    return 2;
        return 0;

    def call_method(self, model, method, *args, **kwargs):
        """ Simple wrapper to call local model methods for database
        """
        if self.odoo._api_v7:
            return getattr(self.registry[model], method)(
                self.cursor, self.odoo.SUPERUSER_ID, *args, **kwargs)
        else:
            # For odoo 8, 9, 10, +(?) there is special function `odoo.registry`
            # to get registry instance for db
            return getattr(self.env[model], method)(*args, **kwargs)

    def __getitem__(self, name):
        return LocalModel(self, name)
