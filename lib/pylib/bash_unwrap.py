#!/usr/bin/env python3

import os
import sys
import subprocess

# Unset bash variables
os.unsetenv('PS4')
os.unsetenv('BASH_TRACEFD')
os.unsetenv('SHELLOPTS')

# Forward arguments to bash
exit(
    subprocess.call([
        'bash',
        *sys.argv[1:]
    ])
)
