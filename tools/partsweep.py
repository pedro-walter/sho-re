#!/usr/bin/env python3
"""Full-factorial part sweep: one lap per combination of part tiers with a FIXED plan, headless, PAR laps at a time.
Usage: tools/partsweep.py PLAN.lua TRACK TIRE OUT.csv   (two laps per run: lap 1 standing start, lap 2 flying)
Sweeps engine/frame/muffler/oil/brake over {0,1} (env TIERS="0,1" to change), tire fixed. Standing start, no backmarkers.
CSV: engine,frame,muffler,oil,brake,lap1_s,lap2_s,total_s,skid1,off1,skid2,off2,maxv_kmh,finished"""
import re, sys, os, itertools, subprocess, concurrent.futures as cf
PLAN, TRACK, TIRE, OUT = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
PAR = int(os.environ.get('PAR', 8)); TIERS = [int(x) for x in os.environ.get('TIERS', '0,1').split(',')]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def run(c):
    e, f, m, o, b = c
    tag = f'ps{TRACK}_{TIRE}_{e}{f}{m}{o}{b}'; log = f'/tmp/{tag}.txt'
    env = dict(os.environ, SHO_ROOT=ROOT, SHO_ONELAP='2', SHO_GENT='80', SHO_GFADE='40', SHO_NOBOTS='1', SHO_NOCHAIN='1', SHO_PLAN=PLAN, SHO_LEAD='40', SHO_BR='0.35',
               SHO_LOADSTATE=f'race{TRACK}', SHO_REL='20', SHO_MARG='0', SHO_TPRE='150', SHO_DUTY='1.0', SHO_RIVAL=str(TRACK - 1), SHO_TIRE=str(TIRE),
               SHO_ENGINE=str(e), SHO_FRAME=str(f), SHO_MUFFLER=str(m), SHO_OIL=str(o), SHO_BRAKET=str(b), SHO_BRKLEARN=os.environ.get('SHO_BRKLEARN', '0'), SHO_LOG='3', SHO_FRAMES='24000', SHO_TAG=tag)
    with open(log, 'w') as lf: subprocess.run(['tools/mame.sh', 'scripts/autolap5.lua'], cwd=ROOT, env=env, stdout=lf, stderr=subprocess.STDOUT)
    ends = []; sk = [0, 0]; of = [0, 0]; vs = []
    for ln in open(log):
        mm = re.search(r'LAP \d->\d at k=(\d+)', ln)
        if mm: ends.append(int(mm[1]))
        mm = re.search(r' T k=\d+ d=\d+ lap=(\d) .* lat=(-?\d+) .* v=(\d+) skid=(\d+)', ln)
        if mm:
            l = min(int(mm[1]), 1)
            if int(mm[4]): sk[l] += 3
            if abs(int(mm[2])) > 270: of[l] += 3
            vs.append(int(mm[3]))
    f2 = lambda x: f'{x/60:.2f}'
    l1 = f2(ends[0]) if ends else ''; l2 = f2(ends[1] - ends[0]) if len(ends) > 1 else ''; tot = f2(ends[1]) if len(ends) > 1 else ''
    return c, l1, l2, tot, sk[0], of[0], sk[1], of[1], round(max(vs) * 1.1625) if vs else 0, 'yes' if len(ends) > 1 else 'no'
combos = list(itertools.product(TIERS, repeat=5))
with cf.ThreadPoolExecutor(PAR) as ex: res = list(ex.map(run, combos))
with open(os.path.join(ROOT, OUT), 'w') as f:
    f.write('engine,frame,muffler,oil,brake,lap1_s,lap2_s,total_s,skid1,off1,skid2,off2,maxv_kmh,finished\n')
    for r in res: f.write(','.join(map(str, r[0])) + ',' + ','.join(map(str, r[1:])) + '\n')
print('wrote', OUT, len(res))
