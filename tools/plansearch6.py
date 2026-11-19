#!/usr/bin/env python3
"""Random coordinate search for autolap6 plans: per curve only the entry speed vt and the entry position a.
Each candidate = one headless MAME lap from the race savestate. Score = lap time + 0.015 s per skid frame + 0.003 s per off-road frame (not finished: 200 s + progress).
Usage: TRACK=1 PAR=8 SEED=1 OIL=1 tools/plansearch6.py TIRE START_PLAN.lua OUT.lua ROUNDS"""
import re, sys, os, random, subprocess, json, concurrent.futures as cf
TIRE, START, OUT, ROUNDS = int(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
TRACK = int(os.environ.get('TRACK', 1)); SEED = int(os.environ.get('SEED', 0)); STEP0 = None; PAR = int(os.environ.get('PAR', 8))
LAPS = int(os.environ.get('LAPS', 1)); OIL = os.environ.get('OIL', '0'); FRAME = os.environ.get('FRAME', '0'); ENGINE = os.environ.get('ENGINE', '0'); BRAKET = os.environ.get('BRAKET', '0'); MUFFLER = os.environ.get('MUFFLER', '0')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VCAP = int(os.environ.get('VCAP', 241))   # entry speed from which a curve counts as 'no braking' (999): 241, or 279 with turbo
STEP = {'vt': 8, 'a': 0.1}
LIM = {"vt": (40, 999), "a": (0.2, 1.3)}
def parse(path):
    plan = {}
    for m in re.finditer(r'\[(\d+)\]\s*=\s*\{([^}]*)\}', open(path).read()):
        d = {k: float(v) for k, v in re.findall(r'(\w+)\s*=\s*([-\d.]+)', m.group(2))}
        d.setdefault('a', 1.0); d.setdefault('vt', 999.0)
        plan[int(m.group(1))] = d
    return plan
def write(plan, path):
    with open(path, 'w') as f:
        f.write('return {\n')
        for c, d in sorted(plan.items()): f.write('  [%d] = { vt = %g, a = %g%s },\n' % (c, d['vt'], round(d['a'], 2), ', cruise = 1' if d.get('cruise') else ''))
        f.write('}\n')
def evaluate(plan, tag):
    pf = f'out/plans/s6_{TRACK}_{TIRE}_{SEED}_{tag}.lua'; write(plan, os.path.join(ROOT, pf))
    log = f'/tmp/s6_{TRACK}_{TIRE}_{SEED}_{tag}.txt'
    env = dict(os.environ, SHO_ROOT=ROOT, SHO_ONELAP=str(LAPS), SHO_NOBOTS='1', SHO_PLAN=pf, SHO_LOADSTATE=f'race{TRACK}', SHO_RIVAL=str(TRACK - 1), SHO_TRACK=str(TRACK),
               SHO_TIRE=str(TIRE), SHO_ENGINE=ENGINE, SHO_OIL=OIL, SHO_FRAME=FRAME, SHO_BRAKET=BRAKET, SHO_MUFFLER=MUFFLER, SHO_LOG='3', SHO_FRAMES=str(11000 * LAPS), SHO_ABORT=os.environ.get('ABORT', '300'), SHO_TAG='s')
    with open(log, 'w') as lf: subprocess.run(['nice', '-n', '19', 'tools/mame.sh', 'scripts/' + os.environ.get('SCRIPT', 'autolap6.lua')], cwd=ROOT, env=env, stdout=lf, stderr=subprocess.STDOUT)
    ends = []; skid = off = 0
    for ln in open(log):
        m = re.search(r'LAP \d->\d at k=(\d+)', ln)
        if m: ends.append(int(m.group(1)))
        m = re.search(r' T k=\d+ d=\d+ lap=\d .* lat=(-?\d+) .* skid=(\d+)', ln)
        if m:
            if int(m.group(2)): skid += 3
            if abs(int(m.group(1))) > 270: off += 3
    pen = 0.03 * skid + 0.01 * off
    if len(ends) < LAPS: return 1000 * (LAPS - len(ends)) + pen, ('DNF', len(ends), skid, off)
    laps = [(ends[i] - (ends[i - 1] if i else 0)) / 60 for i in range(LAPS)]
    return sum(laps) + pen, (' '.join('%.2f' % x for x in laps), skid, off)
plan = parse(START)
best, info = evaluate(plan, 'base')
print('start', best, info, flush=True)
write(plan, os.path.join(ROOT, OUT))
random.seed(TIRE + 100 * SEED + 1000 * TRACK)
curves = sorted(plan)
for r in range(ROUNDS):
    cands = []
    for _ in range(PAR):
        c = random.choice(curves); k = random.choice(['vt', 'vt', 'a'])
        n = json.loads(json.dumps({str(a): b for a, b in plan.items()})); n = {int(a): b for a, b in n.items()}
        cur = n[c][k]
        if k == 'vt' and cur >= 900: cur = VCAP
        step = STEP[k] * random.choice([-3, -2, -1, 1, 1, 2, 3])
        lo, hi = LIM[k]; v = min(hi, max(lo, cur + step))
        if k == 'vt' and v >= VCAP: v = 999
        n[c][k] = v
        cands.append((c, k, n))
    with cf.ThreadPoolExecutor(PAR) as ex: res = list(ex.map(lambda a: evaluate(a[1][2], f'{a[0]}'), enumerate(cands)))
    i = min(range(PAR), key=lambda j: res[j][0])
    msg = ' '.join('%d.%s=%g:%.1f' % (c, k, n[c][k], sc) for (c, k, n), (sc, _) in zip(cands, res))
    if res[i][0] < best - 1e-6:
        best, info, plan = res[i][0], res[i][1], cands[i][2]; write(plan, os.path.join(ROOT, OUT))
        print(f'round {r} IMPROVED {best:.2f} {info}  [{msg}]', flush=True)
    else: print(f'round {r} no gain [{msg}]', flush=True)
write(plan, os.path.join(ROOT, OUT)); print('done', best, info)
