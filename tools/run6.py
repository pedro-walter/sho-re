#!/usr/bin/env python3
"""One v6 autopilot run without video. Usage: tools/run6.py PLAN.lua TAG [key=val ...]   keys: track tire laps frame engine brake muffler oil turbo
Prints per-lap time, skid/off frames and the max speed. Log: out/r6/TAG.txt (nice 19)."""
import re, sys, os, subprocess
plan, tag = sys.argv[1], sys.argv[2]
P = dict(track=3, tire=3, laps=3, frame=0, engine=0, brake=0, muffler=0, oil=0, turbo=0)
txt = re.sub(r'--[^\n]*', '', open(plan).read()); m = re.search(r'params\s*=\s*\{(.*?)\}', txt, re.S)
if m:
    for k, v in re.findall(r'(\w+)\s*=\s*([^,\s]+)', m[1]):
        if k in P: P[k] = int(v)
for a in sys.argv[3:]:
    k, v = a.split('='); P[k] = int(v)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = f'out/r6/{tag}.txt'
env = dict(os.environ, SHO_ROOT=ROOT, SHO_ONELAP=str(P['laps']), SHO_SNAP='', SHO_GENT='80', SHO_GFADE='40', SHO_NOBOTS='1', SHO_NOCHAIN='1', SHO_PLAN=plan, SHO_LEAD='40', SHO_BMARG='1.25', SHO_BR='0.35',
           SHO_LOADSTATE=f"race{P['track']}", SHO_REL='20', SHO_MARG='0', SHO_TPRE='150', SHO_DUTY='1.0', SHO_RIVAL=str(P['track'] - 1), SHO_TIRE=str(P['tire']), SHO_ENGINE=str(P['engine']), SHO_FRAME=str(P['frame']),
           SHO_BRAKET=str(P['brake']), SHO_MUFFLER=str(P['muffler']), SHO_OIL=str(P['oil']), SHO_LOG='3', SHO_MLOG=os.environ.get('MLOG', ''), SHO_FRAMES=str(11000 * P['laps'] + 3000), SHO_TAG=tag)
env.pop('SHO_SNAP')
if not env.get('SHO_MLOG'): env.pop('SHO_MLOG', None)
if P['turbo']: env['SHO_TURBO'] = '1'
with open(os.path.join(ROOT, log), 'w') as lf: subprocess.run(['nice', '-n', '19', 'tools/mame.sh', 'scripts/' + os.environ.get('SCRIPT', 'autolap6.lua')], cwd=ROOT, env=env, stdout=lf, stderr=subprocess.STDOUT)
ends = []; L = P['laps']; sk = [0] * L; of = [0] * L; mv = [0] * L
for ln in open(os.path.join(ROOT, log)):
    mm = re.search(r'LAP \d->\d at k=(\d+)', ln)
    if mm: ends.append(int(mm[1]))
    mm = re.search(r' T k=\d+ d=\d+ lap=(\d) .* lat=(-?\d+) .* v=(\d+) skid=(\d+)', ln)
    if mm and int(mm[1]) < L:
        l = int(mm[1]); mv[l] = max(mv[l], int(mm[3]))
        if int(mm[4]): sk[l] += 3
        if abs(int(mm[2])) > 270: of[l] += 3
laps = [(ends[i] - (ends[i - 1] if i else 0)) / 60 for i in range(len(ends))]
print(tag, ' '.join(f'{k}={v}' for k, v in P.items()))
for i, t in enumerate(laps): print(f'  lap {i+1}: {t:.2f} s  skid={sk[i]} off={of[i]} vmax={round(mv[i]*1.1625)} km/h')
print(f'  total {sum(laps):.2f} s ({len(laps)}/{L} laps)')
