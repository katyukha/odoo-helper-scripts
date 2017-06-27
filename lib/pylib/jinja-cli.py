#!/usr/bin/env python2
# -*- coding: utf-8 -*-

# Based on: https://github.com/mattrobenolt/jinja2-cli/blob/master/jinja2cli/cli.py

import os
import os.path
import sys
from optparse import OptionParser, Option

import six

import jinja2
from jinja2 import Environment, FileSystemLoader


class UConverter(object):
    """ Simple converter to unicode

        Create instance with specified list of encodings to be used to
        try to convert value to unicode

        Example::

            ustr = UConverter(['utf-8', 'cp-1251'])
            my_unicode_str = ustr(b'hello - привет')
    """
    default_encodings = ['utf-8', 'ascii', 'utf-16']

    def __init__(self, hint_encodings=None):
        if hint_encodings:
            self.encodings = hint_encodings
        else:
            self.encodings = self.default_encodings[:]

    def __call__(self, value):
        """ Convert value to unicode

        :param value: the value to convert
        :raise: UnicodeError if value cannot be coerced to unicode
        :return: unicode string representing the given value
        """
        # it is unicode
        if isinstance(value, six.text_type):
            return value

        # it is not binary type (str for python2 and bytes for python3)
        if not isinstance(value, six.binary_type):
            try:
                value = six.text_type(value)
            except Exception:
                # Cannot directly convert to unicode. So let's try to convert
                # to binary, and that try diferent encoding to it
                try:
                    value = six.binary_type(value)
                except:
                    raise UnicodeError('unable to convert to unicode %r'
                                       '' % (value,))
            else:
                return value

        # value is binary type (str for python2 and bytes for python3)
        for ln in self.encodings:
            try:
                res = six.text_type(value, ln)
            except Exception:
                pass
            else:
                return res

        raise UnicodeError('unable to convert to unicode %r' % (value,))


# default converter instance
ustr = UConverter()


def render(template_path, data, extensions, strict=False):
    """ Render jinja2 template
    """
    env = Environment(
        loader=FileSystemLoader(os.path.dirname(template_path)),
        extensions=extensions,
        keep_trailing_newline=True,
    )
    if strict:
        from jinja2 import StrictUndefined
        env.undefined = StrictUndefined

    # Add environ global
    env.globals['environ'] = os.environ.get

    output = env.get_template(os.path.basename(template_path)).render(data)
    return output


def parse_kv_string(pairs):
    """ Parse options (-D)
    """
    res = {}
    for pair in pairs:
        var, value = pair.split('=', 1)
        res[var] = ustr(value)
    return res


def cli(opts, args):
    # TODO: make template path configurable via CLI option
    template_path = os.path.abspath(args[0])

    data = {}

    extensions = []
    for ext in opts.extensions:
        # Allow shorthand and assume if it's not a module
        # path, it's probably trying to use builtin from jinja2
        if '.' not in ext:
            ext = 'jinja2.ext.' + ext
        extensions.append(ext)

    data.update(parse_kv_string(opts.D or []))

    output = render(template_path, data, extensions, opts.strict)

    output = ustr(output)

    sys.stdout.write(output.encode('utf-8'))
    return 0
#------------

def main():
    parser = OptionParser(
        usage="usage: %prog [options] <input template>",
        version="Jinja2 v%s" % jinja2.__version__,
    )
    parser.add_option(
        '-e', '--extension',
        help='extra jinja2 extensions to load',
        dest='extensions', action='append',
        default=['do', 'with_', 'autoescape', 'loopcontrols'])
    parser.add_option(
        '-D',
        help='Define template variable in the form of key=value',
        action='append', metavar='key=value')
    parser.add_option(
        '--strict',
        help='Disallow undefined variables to be used within the template',
        dest='strict', action='store_true')
    opts, args = parser.parse_args()

    # Dedupe list
    opts.extensions = set(opts.extensions)

    if not args:
        parser.print_help()
        sys.exit(1)

    if args[0] == 'help':
        parser.print_help()
        sys.exit(1)

    sys.exit(cli(opts, args))


if __name__ == '__main__':
    main()
