#!/usr/bin/env python3
"""Convert a search plan (scripts/plan_trackN_tT_q.lua) into the human-friendly tunable layout (aligned columns, turn comments).
Usage: python3 tools/mktune.py scripts/plan_trackN_tT_q.lua TRACK TIRE tune/trackN_tT.lua"""
import sys, re, subprocess
plan, track, tire, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
rows = []
for ln in open(plan):
    m = re.match(r'\s*\[(\d+)\]\s*=\s*\{(.*)\}', ln)
    if m: rows.append((int(m[1]), dict((k, float(v)) for k, v in re.findall(r'(\w+)\s*=\s*([-\d.]+)', m[2]))))
rows.sort()
def f(x): return ('%g' % x)
kw = max(len('[%d] =' % k) for k, _ in rows)
base = ['vt', 'a', 'lead', 'marg', 'rel']; opt = ['ine', 'send']
w = {k: max(len(f(r.get(k, 0))) for _, r in rows) for k in base}
hdr = open('tune/track1_t0.lua').read().split('return {')[0]
hdr = re.sub(r'^-- Track 1, tire 0: tunable plan \(copy of the search result plan_track1_t0_q.lua\)',
             f'-- Track {track}, tire {tire}: tunable plan (copy of the search result {plan.split("/")[-1]})', hdr)
hdr = hdr.replace('tune/track1_t0.lua', f'tune/track{track}_t{tire}.lua')
params = open('tune/track1_t0.lua').read().split('return {\n')[1].split('  },\n')[0] + '  },\n'
params = re.sub(r'track = \d+,  tire = \d+,', f'track = {track},  tire = {tire},', params)
lines = [hdr + 'return {\n' + params.rstrip('\n')]
for i, (k, r) in enumerate(rows):
    key = ('[%d] =' % k).ljust(kw)
    parts = []
    for j, n in enumerate(base):
        v = f(r.get(n, 0)); parts.append(f'{n} = {v}' + (',' if j < len(base) - 1 or any(o in r for o in opt) else ''))
        parts[-1] = parts[-1].ljust(len(n) + 3 + w[n] + 1) if j < len(base) - 1 else parts[-1]
    extra = ', '.join(f'{o} = {f(r[o])}' for o in opt if o in r)
    body = ' '.join(parts)
    if extra: body += ' ' + extra
    lines.append(f'  {key} {{ {body} }},  -- T{i+1}')
lines.append('}')
open(out, 'w').write('\n'.join(lines) + '\n')
