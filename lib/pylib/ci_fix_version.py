import re
import sys

RE_GIT_VERSION_CONFLICT = re.compile(
    r"^<<<<<<< HEAD\n"
    r"(\s+[\"']version[\"']:\s[\"'][\d\.]+[\"'],\n)"
    r"=======\n"
    r"(\s+[\"']version[\"']:\s[\"'][\d\.]+[\"'],\n)"
    r">>>>>>> .*\n", flags=re.MULTILINE)

if __name__ == "__main__":
    file_path = sys.argv[1]
    with open(file_path, "rt") as f:
        file_content = f.read()

    file_content = RE_GIT_VERSION_CONFLICT.sub(r"\2", file_content)

    with open(file_path, "wt") as f:
        f.write(file_content)
