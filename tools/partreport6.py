#!/usr/bin/env python3
"""Markdown report of a tools/partsweep6.py CSV. Usage: tools/partreport6.py docs/data/partsweep6_track1.csv > docs/13-part-comparison.md
Rows are sorted by tire, then by the F E B M O code (binary order, so a combination is easy to find); a row is flagged `outlier` when it is more than 3 s slower
than the median of the rows with the same tire and engine tier (those are runs where the tune no longer fits the part combination)."""
import csv, sys, statistics as S
K = ('tire', 'frame', 'engine', 'brake', 'muffler', 'oil')
R = {tuple(int(x[k]) for k in K): x for x in csv.DictReader(open(sys.argv[1]))}
lap = lambda k: float(R[k]['lap_s']) if R[k]['lap_s'] else None
med = {}
for t in {k[0] for k in R}:
    for e in (0, 1):
        v = [lap(k) for k in R if k[0] == t and k[2] == e and lap(k)]; med[(t, e)] = S.median(v)
out = lambda k: lap(k) is None or lap(k) > med[(k[0], k[2])] + 3
print('# 13 - Part comparison on track 1 (v6 autopilot)\n')
print(f'All {len(R)} combinations of frame, engine, brake, muffler, oil in {{0,1}} and tire 0, 1, 2. One standing-start lap of track 1, no bots, `scripts/autolap6.lua` with the tire\'s tune '
      '(`tune/v6/track1_tT.lua`, tuned with oil 1 and the other parts at 0, **not** re-tuned per combination). Skid / off-road frames are listed but do not exclude a run; '
      'a run is flagged `outlier` only when it is more than 3 s slower than the median of the runs with the same tire and engine tier. Tool: `tools/partsweep6.py 1 OUT.csv` + `tools/partreport6.py`; data: `docs/data/partsweep6_track1.csv`.\n')
print('## Effect of each part (tier 0 -> 1, same everything else; non-outlier pairs)\n')
print('| part | mean | median | min .. max | pairs |\n|---|---|---|---|---|')
for i, n in enumerate(K[1:], 1):
    d = [lap(k[:i] + (1,) + k[i + 1:]) - lap(k) for k in R if k[i] == 0 and not out(k) and not out(k[:i] + (1,) + k[i + 1:])]
    print(f'| {n} | {S.mean(d):+.2f} s | {S.median(d):+.2f} s | {min(d):+.2f} .. {max(d):+.2f} | {len(d)} |')
for a, b in ((0, 1), (1, 2)):
    d = [lap((b,) + k[1:]) - lap((a,) + k[1:]) for k in R if k[0] == a and not out(k) and not out((b,) + k[1:])]
    print(f'| tire {a} -> {b} | {S.mean(d):+.2f} s | {S.median(d):+.2f} s | {min(d):+.2f} .. {max(d):+.2f} | {len(d)} |')
print('\n## Best lap per tire\n')
print('| tire | best | F E B M O | stock |\n|---|---|---|---|')
for t in (0, 1, 2):
    k = min((k for k in R if k[0] == t and not out(k)), key=lap); print(f'| {t} | {lap(k):.2f} | {" ".join(map(str, k[1:]))} | {lap((t, 0, 0, 0, 0, 0)):.2f} |')
print('\n## All combinations (sorted by tire, then F E B M O)\n')
print('| tire | F E B M O | lap (s) | vs stock | skid | off | |\n|---|---|---|---|---|---|---|')
for k in sorted(R):
    x = R[k]; st = lap((k[0], 0, 0, 0, 0, 0))
    print(f"| {k[0]} | {' '.join(map(str, k[1:]))} | {x['lap_s']} | {lap(k) - st:+.2f} | {x['skid']} | {x['off']} | {'outlier' if out(k) else ''} |")
