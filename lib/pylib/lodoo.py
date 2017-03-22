# -*- coding: utf-8 -*-
""" Local odoo connection lib
"""
import os
import atexit


import erppeek

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
    try:
        import openerp as odoo
    except:
        import odoo
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
