""" Find python dependencies from manifest
"""
import os
import click


def read_addon_manifest(addon_path):
    if os.path.exists(os.path.join(addon_path, '__manifest__.py')):
        return eval(open('%s/__manifest__.py' % addon_path, 'rt').read())
    if os.path.exists(os.path.join(addon_path, '__openerp__.py')):
        return eval(open('%s/__manifest__.py' % addon_path, 'rt').read())
    return False


@click.group()
@click.pass_context
def cli(ctx):
    pass


@cli.command(
    'addon-py-deps',
    help="Print space-separated list of python dependencies from addon's "
         "manifest file.")
@click.option(
    '--addon-path', type=click.Path(exists=True,
                                    dir_okay=True,
                                    file_okay=False,
                                    resolve_path=True),
    help='Path to addon folder.')
@click.pass_context
def addon_py_deps(ctx, addon_path):
    manifest = read_addon_manifest(addon_path)
    python_deps = manifest.get(
        'external_dependencies', {}
    ).get('python', [])
    click.echo(' '.join(python_deps), nl=False)


@cli.command(
    'addon-is-installable',
    help="Check if addon is installable")
@click.option(
    '--addon-path', type=click.Path(exists=True,
                                    dir_okay=True,
                                    file_okay=False,
                                    resolve_path=True),
    help='Path to addon folder.')
@click.pass_context
def addon_is_installable(ctx, addon_path):
    manifest = read_addon_manifest(addon_path)
    if not manifest.get('installable', True):
        return ctx.exit(1)

if __name__ == '__main__':
    cli()
