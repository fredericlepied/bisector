#!/usr/bin/env python

import sys

lines = sys.stdin.readlines()

mid = len(lines) / 2

open('before', 'w').write(''.join(lines[:mid]))
open('after', 'w').write(''.join(lines[mid + 1:]))

print lines[mid],
