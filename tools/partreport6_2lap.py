#!/usr/bin/env python3
"""Markdown report of a LAPS=2 tools/partsweep6.py CSV. Usage: tools/partreport6_2lap.py docs/data/partsweep6_track1_2lap.csv > docs/14-part-comparison-2laps.md
A lap is flagged `outlier` when it is more than 3 s slower than the median of the same lap of the runs with the same tire and engine tier; outlier laps are left out of the effect tables."""
import csv, sys, statistics as S
K = ('tire', 'frame', 'engine', 'brake', 'muffler', 'oil')
R = {tuple(int(x[k]) for k in K): x for x in csv.DictReader(open(sys.argv[1]))}
L = lambda k, n: float(R[k][f'lap{n}_s'])
med = {(t, e, n): S.median(L(k, n) for k in R if k[0] == t and k[2] == e) for t in (0, 1, 2) for e in (0, 1) for n in (1, 2)}
out = lambda k, n: L(k, n) > med[(k[0], k[2], n)] + 3
print('# 14 - Part comparison on track 1, two laps (v6 autopilot)\n')
print('All 96 combinations (frame, engine, brake, muffler, oil in {0,1}, tire 0-2), two laps from a standing start; lap 1 is the standing-start lap, lap 2 starts at full speed. '
      'Same tunes and autopilot as doc 13. A lap is flagged `outlier` when it is >3 s slower than the median of the same lap with the same tire and engine tier (excluded from the effect tables). '
      'Tool: `LAPS=2 tools/partsweep6.py 1 OUT.csv` + `tools/partreport6_2lap.py`.\n')
print('## Effect of each part (tier 0 -> 1, mean change in s, outlier laps excluded)\n\n| part | lap 1 | lap 2 | lap 2 pairs |\n|---|---|---|---|')
for i, n in enumerate(K[1:], 1):
    row = []
    for l in (1, 2):
        d = [L(k[:i] + (1,) + k[i + 1:], l) - L(k, l) for k in R if k[i] == 0 and not out(k, l) and not out(k[:i] + (1,) + k[i + 1:], l)]
        row.append((S.mean(d), len(d)))
    print(f'| {n} | {row[0][0]:+.2f} | {row[1][0]:+.2f} | {row[1][1]} |')
for a, b in ((0, 1), (1, 2)):
    row = []
    for l in (1, 2):
        d = [L((b,) + k[1:], l) - L((a,) + k[1:], l) for k in R if k[0] == a and not out(k, l) and not out((b,) + k[1:], l)]
        row.append((S.mean(d), len(d)))
    print(f'| tire {a} -> {b} | {row[0][0]:+.2f} | {row[1][0]:+.2f} | {row[1][1]} |')
print('\n## Best total per tire\n\n| tire | best total | F E B M O | lap 1 | lap 2 |\n|---|---|---|---|---|')
for t in (0, 1, 2):
    k = min((k for k in R if k[0] == t and not out(k, 1) and not out(k, 2)), key=lambda k: float(R[k]['total_s']))
    print(f"| {t} | {R[k]['total_s']} | {' '.join(map(str, k[1:]))} | {R[k]['lap1_s']} | {R[k]['lap2_s']} |")
print('\n## All combinations (sorted by tire, then F E B M O)\n\n| tire | F E B M O | lap 1 | lap 2 | total | lap 1 - lap 2 | skid 1/2 | off 1/2 | |\n|---|---|---|---|---|---|---|---|---|')
for k in sorted(R):
    x = R[k]; fl = ' '.join(f'lap{n} outlier' for n in (1, 2) if out(k, n))
    print(f"| {k[0]} | {' '.join(map(str, k[1:]))} | {x['lap1_s']} | {x['lap2_s']} | {x['total_s']} | {L(k,1)-L(k,2):.2f} | {x['skid1']}/{x['skid2']} | {x['off1']}/{x['off2']} | {fl} |")
