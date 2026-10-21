#!/usr/bin/env python3 -I
"""Print a slice of the generated listing: tools/show.py START END [listing]   (hex addresses, inclusive)"""
import sys, re
lo, hi = int(sys.argv[1], 16), int(sys.argv[2], 16)
f = sys.argv[3] if len(sys.argv) > 3 else "disasm/sho.asm"
for l in open(f):
    m = re.match(r"^  ([0-9A-F]{6})  ", l)
    if m:
        if lo <= int(m.group(1), 16) <= hi: print(l.rstrip()[:130])
    elif re.match(r"^\w+:$", l) or l.startswith(";"):
        pend = l
        continue
