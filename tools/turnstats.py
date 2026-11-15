#!/usr/bin/env python3
"""Per-turn statistics from an autolap run logged with SHO_LOG=3. Usage: tools/turnstats.py LOG [OFF]"""
import re, sys
turns = []
_t = [(int(m.group(1)), int(m.group(2))) for m in (re.search(r'TURN \d+ start=(\d+) len=(\d+)', l) for l in open(sys.argv[1])) if m]
for _i, (_s, _l) in enumerate(_t): turns.append((_s, _t[_i+1][0] if _i+1 < len(_t) else 2048, _i+1))
OFF = int(sys.argv[2]) if len(sys.argv) > 2 else 270
rows = []
for ln in open(sys.argv[1]):
    m = re.match(r'\S+ T k=(\d+) d=(\d+) lap=(\d+) st=\d+ r=\d+ lat=(-?\d+) tgt=(-?\d+) s=(-?\d+) sd=(-?\d+) v=(\d+) skid=(\d+)', ln)
    if m: g = list(map(int, m.groups())); rows.append((g[0], g[1], g[3], g[4], g[5], g[6], g[7], g[8], g[2]))
laps = sorted(set(x[8] for x in rows))
for lp in laps:
    if len(laps) > 1: print(f"-- lap {lp + 1}")
    for a, b, n in turns:
        r = [x for x in rows if x[8] == lp and a <= x[1] < b]
        if not r: continue
        print(f"T{n:2d} frames={len(r)*3:4d} v_in={r[0][6]*279//240:3d} v_out={r[-1][6]*279//240:3d} v_min={min(x[6] for x in r)*279//240:3d} lat_in={r[0][2]:5d} lat_out={r[-1][2]:5d} max|lat|={max(abs(x[2]) for x in r):3d} off={sum(1 for x in r if abs(x[2])>OFF)*3:3d} skid={sum(1 for x in r if x[7])*3}")
