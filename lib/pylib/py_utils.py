""" Find python dependencies from manifest
"""
import click


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
    manifest = eval(open('%s/__manifest__.py' % addon_path, 'rt').read())
    python_deps = manifest.get(
        'external_dependencies', {}
    ).get('python', [])
    click.echo(' '.join(python_deps), nl=False)


if __name__ == '__main__':
    cli()
