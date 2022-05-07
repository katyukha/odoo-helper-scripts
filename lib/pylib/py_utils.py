""" Find python dependencies from manifest
"""
import os
import re
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



@cli.command(
    'install-parse-deb-deps',
    help="Parse deb control file to find dependencies")
@click.option(
    '--path', type=click.Path(exists=True,
                                  dir_okay=False,
                                  file_okay=True,
                                  resolve_path=True),
    help='Path to debian control file.')
@click.pass_context
def install_parse_deb_debendencies(ctx, path):
    RE_DEPS=re.compile(
        r'.*Depends:(?P<deps>(\n [^,]+,)+).*',
        re.MULTILINE | re.DOTALL)
    m = RE_DEPS.match(open(path).read())
    deps = m and m.groupdict().get('deps', '')
    deps = deps.replace(',', '').replace(' ', '').split('\n')
    click.echo(
        '\n'.join(filter(lambda l: l and not l.startswith('${'), deps))
    )

if __name__ == '__main__':
    cli()
