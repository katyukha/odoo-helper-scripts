""" Fix code after forwardport

This module, contains tools to automatically fix code to be compatible with
specific odoo versions.
"""
import os
import re
from glob import iglob

import click

CHECKS = {}

# Auto checks for 13.0
CHECKS['13.0'] = {
    '.py': [
        ("replace",
            r"\.sudo\((?P<user>[^/)]+?)\)",
            r".with_user(\g<user>)",
            "Replaced sudo(user) -> with_user(user)"),
        ("replace",
            r".*@api.one.*\n",
            "",
            "Remove @api.one"),
        ("replace",
            r".*@api.multi.*\n",
            "",
            "Remove @api.multi"),
        ("replace",
            r"\._find_partner_from_emails\(",
            "._mail_find_partner_from_emails(",
            ("Rename _find_partner_from_emails -> "
                "_mail_find_partner_from_emails")),
    ],
    '.xml': [
        ("replace",
            r"[\s\t]*<field name=['\"]view_type['\"]>.*</field>\n",
            "",
            "Remove <field name='view_type'>...</field>"),
    ],
}

CHECKS['14.0'] = {
    '.py': [
        ("replace",
            r"track_visibility\s*=\s*['\"]\w+['\"]",
            "tracking=True",
            "Replace track_visibility='...' with tracking=True"),
    ],
}


def run_command_replace(fpath, fcontent, expr, subst, msg):
    """ Replace all occurences of <expr> in <fcontent> by <subst>

        :return str: modified file content
    """
    if not subst:
        subst = ""
    fcontent, changes = re.subn(expr, subst, fcontent)

    if changes:
        print("File %s updated: %s" % (fpath, msg))
    return fcontent


def run_command(fpath, fcontent, command, args):
    if command == 'replace':
        fcontent = run_command_replace(fpath, fcontent, *args)

    return fcontent


@click.command()
@click.option(
    '--version', help='Odoo version to apply checks for.')
@click.option(
    '--path', type=click.Path(exists=True,
                              dir_okay=True,
                              file_okay=False,
                              resolve_path=True),
    help='Path to directory to check code in.')
@click.pass_context
def main(ctx, version, path):
    checks = CHECKS.get(version)
    if not checks:
        click.echo("There are no checks for version %s" % version)
        ctx.exit(1)

    for fpath in iglob("%s/**" % path, recursive=True):
        if not os.path.isfile(fpath):
            continue

        __, fext = os.path.splitext(fpath)

        fchecks = checks.get(fext)
        if not fchecks:
            continue

        with open(fpath, 'r+') as f:
            fcontent = f.read()
            for command in fchecks:
                fcontent = run_command(
                    fpath, fcontent, command[0], command[1:])
            f.seek(0)
            f.write(fcontent)
            f.truncate(f.tell())
            f.flush()


if __name__ == '__main__':
    main()
