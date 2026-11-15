#!/usr/bin/env python3
"""Initial plan from track geometry and tire: entry speed = highest speed whose curve push stays within the tire's full-lock authority.
Usage: tools/mkplan.py TRACK TIRE OUT.lua   (TRACK 1..3 = rival 0..2; curves from out/turns_trackN.txt)"""
import sys, re, math
track, tire, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
G = 8.0 * 160 / (128 + [32, 20, 8, -4, -16][tire])
turns = []
for ln in open(f'out/turns_track{track}.txt'):
    m = re.search(r'TURN \d+ start=(\d+) len=(\d+) dir=(\w) r=(\d+)', ln)
    if m: turns.append((int(m.group(1)), int(m.group(2)), m.group(3), int(m.group(4))))
def push(v, r): return (2 / 3) * (math.floor(round(410 / r) * v / 110) + 1)
with open(out, 'w') as f:
    f.write('return {\n')
    for i, (s, ln, d, r) in enumerate(turns):
        vt = 241
        while vt > 60 and push(vt, r) > G: vt -= 1
        nxt = turns[i + 1] if i + 1 < len(turns) else None
        lead = 40 if nxt and nxt[0] <= s + ln + 2 and nxt[2] != d else 0
        f.write('  [%d] = { vt = %d, a = 1.00, lead = %d, marg = 0, rel = 20 },\n' % (s, vt, lead))
    f.write('}\n')
