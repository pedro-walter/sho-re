#!/usr/bin/env python3
"""Per-turn statistics from an autolap run logged with SHO_LOG=3. Usage: tools/turnstats.py LOG [OFF]"""
import re, sys
turns = [(116,385,1),(385,670,2),(670,743,3),(743,851,4),(979,1082,5),(1232,1335,6),(1411,1478,7),(1478,1549,8),(1549,1659,9),(1659,1810,10),(1810,1933,11)]  # track 3
OFF = int(sys.argv[2]) if len(sys.argv) > 2 else 270
rows = []
for ln in open(sys.argv[1]):
    m = re.match(r'\S+ T k=(\d+) d=(\d+) lap=0 st=\d+ r=\d+ lat=(-?\d+) tgt=(-?\d+) s=(-?\d+) sd=(-?\d+) v=(\d+) skid=(\d+)', ln)
    if m: rows.append(tuple(map(int, m.groups())))
for a, b, n in turns:
    r = [x for x in rows if a <= x[1] < b]
    if not r: continue
    print(f"T{n:2d} frames={len(r)*3:4d} v_in={r[0][6]*279//240:3d} v_out={r[-1][6]*279//240:3d} v_min={min(x[6] for x in r)*279//240:3d} lat_in={r[0][2]:5d} lat_out={r[-1][2]:5d} max|lat|={max(abs(x[2]) for x in r):3d} off={sum(1 for x in r if abs(x[2])>OFF)*3:3d} skid={sum(1 for x in r if x[7])*3}")
