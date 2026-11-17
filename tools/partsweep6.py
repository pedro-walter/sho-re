#!/usr/bin/env python3
"""Part sweep with the v6 autopilot: one standing-start lap per combination of frame/engine/brake/muffler/oil in {0,1} x tire 0..2, each tire with its own tune.
Usage: tools/partsweep6.py TRACK OUT.csv   (uses tune/v6/trackTRACK_tT.lua; env PAR=parallel runs, TIERS="0,1", TIRES="0,1,2", TUNEDIR=dir to override)
CSV: tire,frame,engine,brake,muffler,oil,lap_s,skid,off,maxv_kmh,finished"""
import re, sys, os, itertools, subprocess, concurrent.futures as cf
TRACK, OUT = int(sys.argv[1]), sys.argv[2]
PAR = int(os.environ.get('PAR', 12)); TIERS = [int(x) for x in os.environ.get('TIERS', '0,1').split(',')]; TIRES = [int(x) for x in os.environ.get('TIRES', '0,1,2').split(',')]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TUNES = os.environ.get('TUNEDIR', 'tune/v6'); LAPS = int(os.environ.get('LAPS', 1))
def run(c):
    t, f, e, b, m, o = c
    tag = f'p6_{TRACK}_{t}{f}{e}{b}{m}{o}'; log = f'/tmp/{tag}.txt'
    env = dict(os.environ, SHO_ROOT=ROOT, SHO_ONELAP=str(LAPS), SHO_SNAP='3', SHO_GENT='80', SHO_GFADE='40', SHO_NOBOTS='1', SHO_NOCHAIN='1', SHO_PLAN=f'{TUNES}/track{TRACK}_t{t}.lua', SHO_LEAD='40', SHO_BMARG='1.25', SHO_BR='0.35',
               SHO_LOADSTATE=f'race{TRACK}', SHO_REL='20', SHO_MARG='0', SHO_TPRE='150', SHO_DUTY='1.0', SHO_RIVAL=str(TRACK - 1), SHO_TIRE=str(t), SHO_ENGINE=str(e), SHO_FRAME=str(f),
               SHO_BRAKET=str(b), SHO_MUFFLER=str(m), SHO_OIL=str(o), SHO_LOG='3', SHO_FRAMES=str(11000 * LAPS), SHO_TAG=tag)
    with open(log, 'w') as lf: subprocess.run(['nice', '-n', '19', 'tools/mame.sh', 'scripts/autolap6.lua'], cwd=ROOT, env=env, stdout=lf, stderr=subprocess.STDOUT)
    ends = []; sk = [0] * LAPS; of = [0] * LAPS; vs = []
    for ln in open(log):
        mm = re.search(r'LAP \d->\d at k=(\d+)', ln)
        if mm: ends.append(int(mm[1]))
        mm = re.search(r' T k=\d+ d=\d+ lap=(\d) .* lat=(-?\d+) .* v=(\d+) skid=(\d+)', ln)
        if mm and int(mm[1]) < LAPS:
            l = int(mm[1])
            if int(mm[4]): sk[l] += 3
            if abs(int(mm[2])) > 270: of[l] += 3
            vs.append(int(mm[3]))
    laps = [(ends[i] - (ends[i - 1] if i else 0)) / 60 for i in range(len(ends))]
    if LAPS == 1: return c, f'{laps[0]:.2f}' if laps else '', sk[0], of[0], round(max(vs) * 1.1625) if vs else 0, 'yes' if laps else 'no'
    return (c,) + tuple(f'{laps[i]:.2f}' if i < len(laps) else '' for i in range(LAPS)) + (f'{sum(laps):.2f}' if len(laps) == LAPS else '',) + tuple(sk) + tuple(of) + (round(max(vs) * 1.1625) if vs else 0, 'yes' if len(laps) == LAPS else 'no')
combos = [(t,) + r for t in TIRES for r in itertools.product(TIERS, repeat=5)]
with cf.ThreadPoolExecutor(PAR) as ex: res = list(ex.map(run, combos))
with open(os.path.join(ROOT, OUT), 'w') as f:
    f.write('tire,frame,engine,brake,muffler,oil,lap_s,skid,off,maxv_kmh,finished\n' if LAPS == 1 else 'tire,frame,engine,brake,muffler,oil,' + ','.join(f'lap{i+1}_s' for i in range(LAPS)) + ',total_s,' + ','.join(f'skid{i+1}' for i in range(LAPS)) + ',' + ','.join(f'off{i+1}' for i in range(LAPS)) + ',maxv_kmh,finished\n')
    for r in res: f.write(','.join(map(str, r[0])) + ',' + ','.join(map(str, r[1:])) + '\n')
print('wrote', OUT, len(res))
