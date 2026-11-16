#!/usr/bin/env python3
"""Summarise a tools/partsweep.py CSV as markdown tables. Usage: tools/partreport.py docs/data/partsweep_trackN_tireT.csv"""
import csv, sys
P = ['engine', 'frame', 'muffler', 'oil', 'brake']
rows = list(csv.DictReader(open(sys.argv[1])))
R = {tuple(int(r[p]) for p in P): r for r in rows}
f = lambda r, c: float(r[c]) if r[c] else None
base = R[(0,) * 5]
bad = lambda r: f"{int(r['skid1']) + int(r['skid2'])} / {int(r['off1']) + int(r['off2'])}"
print(f"Stock parts (all tier 0): lap 1 **{base['lap1_s']} s**, lap 2 **{base['lap2_s']} s**, total **{base['total_s']} s**; skid / off-road frames {bad(base)}.\n")
print('One part at tier 1, the others at tier 0:\n')
print('| part | lap 1 | lap 2 | total | total vs stock | skid / off frames |\n|---|---|---|---|---|---|')
for i, p in enumerate(P):
    r = R[tuple(1 if j == i else 0 for j in range(5))]
    print(f"| {p} 1 | {r['lap1_s']} | {r['lap2_s']} | {r['total_s']} | {f(base,'total_s') - f(r,'total_s'):+.2f} | {bad(r)} |")
print('\nAll 32 combinations, sorted by total time (E F M O B = engine frame muffler oil brake tier):\n')
print('| E F M O B | lap 1 | lap 2 | total | vs stock | skid / off frames |\n|---|---|---|---|---|---|')
for k, r in sorted(R.items(), key=lambda kv: f(kv[1], 'total_s') or 1e9):
    print(f"| {' '.join(map(str, k))} | {r['lap1_s']} | {r['lap2_s']} | {r['total_s']} | {f(base,'total_s') - f(r,'total_s'):+.2f} | {bad(r)} |")
clean = lambda r: int(r['skid1']) + int(r['skid2']) <= 100 and int(r['off1']) + int(r['off2']) <= 400
print('\nPaired effect of each part: for every pair of combinations that differ only in that part (tier 0 -> 1) and where **both** laps are clean (<= 100 skid and <= 400 off-road frames in total), the change in total time (negative = faster):\n')
print('| part | clean pairs | mean change (s) | lap 1 (s) | lap 2 (s) | min..max (s) |\n|---|---|---|---|---|---|')
for i, p in enumerate(P):
    d = []
    for k, r in R.items():
        if k[i] == 0:
            k1 = k[:i] + (1,) + k[i + 1:]; r1 = R[k1]
            if clean(r) and clean(r1): d.append((f(r1, 'total_s') - f(r, 'total_s'), f(r1, 'lap1_s') - f(r, 'lap1_s'), f(r1, 'lap2_s') - f(r, 'lap2_s')))
    if d: print(f"| {p} | {len(d)} | {sum(x[0] for x in d)/len(d):+.2f} | {sum(x[1] for x in d)/len(d):+.2f} | {sum(x[2] for x in d)/len(d):+.2f} | {min(x[0] for x in d):+.2f} .. {max(x[0] for x in d):+.2f} |")
    else: print(f'| {p} | 0 | no clean pair | | | |')
