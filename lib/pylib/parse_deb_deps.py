import re
import argparse


def parse_deb_dependencies(path):
    RE_DEPS = re.compile(
        r'.*Depends:(?P<deps>(\n [^,]+,)+).*',
        re.MULTILINE | re.DOTALL)
    m = RE_DEPS.match(open(path).read())
    deps = m and m.groupdict().get('deps', '')
    deps = deps.replace(',', '').replace(' ', '').split('\n')
    return filter(lambda line: line and not line.startswith('${'), deps)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Parse dependencies of deb file')
    parser.add_argument(
        'path',
        help='Path to debian control file.')
    args = parser.parse_args()
    print("\n".join(parse_deb_dependencies(args.path)))
