#!/usr/bin/env python3 -I
"""RAM diff: tools/ramdiff.py a.bin b.bin [--min N]   (dumps from scripts/play.lua SHO_DUMP, RAM base $FF0000)
Prints changed ranges as FFxxxx: old -> new (hex bytes), merging bytes within 4 of each other."""
import sys
a = sys.argv[1:]
mn = 0
if "--min" in a: i = a.index("--min"); mn = int(a[i+1]); del a[i:i+2]
x, y = open(a[0], "rb").read(), open(a[1], "rb").read()
ch = [i for i in range(min(len(x), len(y))) if x[i] != y[i]]
runs = []
for i in ch:
    if runs and i - runs[-1][1] <= 4: runs[-1][1] = i
    else: runs.append([i, i])
print(len(ch), "bytes differ,", len(runs), "runs")
for lo, hi in runs:
    if hi - lo + 1 < mn: continue
    print("%06X: %s -> %s" % (0xFF0000 + lo, x[lo:hi+1].hex(" "), y[lo:hi+1].hex(" ")))
