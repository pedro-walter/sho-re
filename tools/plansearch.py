#!/usr/bin/env python3
"""Stochastic coordinate search over the per-curve plan fields (vt, lead, marg, rel) for one tire.
Each candidate = one headless MAME lap from the race3 savestate. Usage: tools/plansearch.py TIRE START_PLAN.lua OUT.lua ROUNDS"""
import re, sys, os, random, subprocess, json, concurrent.futures as cf
TIRE, START, OUT, ROUNDS = int(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
TRACK = int(os.environ.get('TRACK', 3)); SEED = int(os.environ.get('SEED', 0))
PAR = int(os.environ.get('PAR', 8))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEP = {'vt': 8, 'lead': 15, 'marg': 10, 'rel': 10, 'ine': 15, 'a': 0.1, 'send': 15}
LIM = {'vt': (40, 241), 'lead': (0, 140), 'marg': (0, 80), 'rel': (0, 60), 'ine': (180, 290), 'a': (0.5, 1.2), 'send': (0, 140)}
def parse(path):
    plan = {}
    for m in re.finditer(r'\[(\d+)\] = \{([^}]*)\}', open(path).read()):
        d = {}
        for k, v in re.findall(r'(\w+) = ([\d.]+)', m.group(2)): d[k] = float(v)
        d.setdefault('marg', 0); d.setdefault('rel', 20); d.setdefault('lead', 0)
        plan[int(m.group(1))] = d
    return plan
def write(plan, path):
    with open(path, 'w') as f:
        f.write('return {\n')
        for c, d in sorted(plan.items()):
            f.write('  [%d] = { %s },\n' % (c, ', '.join('%s = %g' % kv for kv in d.items())))
        f.write('}\n')
def evaluate(plan, tag):
    pf = f'out/plans/w{TRACK}_{TIRE}_{SEED}_{tag}.lua'; write(plan, os.path.join(ROOT, pf))
    log = f'/tmp/w{TRACK}_{TIRE}_{SEED}_{tag}.txt'
    env = dict(os.environ, SHO_ROOT=ROOT, SHO_ONELAP='1', SHO_GENT=os.environ.get('GENT','80'), SHO_GFADE='40', SHO_NOBOTS='1', SHO_NOCHAIN='1', SHO_PLAN=pf, SHO_LEAD='40', SHO_BR='0.35',
               SHO_LOADSTATE=f'race{TRACK}', SHO_REL='20', SHO_MARG='0', SHO_TPRE='150', SHO_DUTY='1.0', SHO_RIVAL=str(TRACK - 1), SHO_TIRE=str(TIRE), SHO_ENGINE='0', SHO_LOG='3', SHO_FRAMES='11000', SHO_TAG='s')
    with open(log, 'w') as lf: subprocess.run(['tools/mame.sh', 'scripts/' + os.environ.get('SCRIPT', 'autolap4.lua')], cwd=ROOT, env=env, stdout=lf, stderr=subprocess.STDOUT)
    lap = None; skid = off = 0; dmax = 0
    for ln in open(log):
        m = re.search(r'LAP 0->1 at k=(\d+)', ln)
        if m: lap = int(m.group(1))
        m = re.search(r' T k=\d+ d=(\d+) lap=0 ', ln)
        if m: dmax = max(dmax, int(m.group(1)))
        m = re.search(r' T k=\d+ d=\d+ lap=0 .* lat=(-?\d+) .* skid=(\d+)', ln)
        if m:
            if int(m.group(2)): skid += 3
            if abs(int(m.group(1))) > 270: off += 3
    if lap is None: return 200 + 0.015 * skid + 0.003 * off + (2048 - dmax) * 0.05, ('DNF', skid, off, dmax)
    return lap / 60 + 0.015 * skid + 0.003 * off, (lap / 60, skid, off)
plan = parse(START)
best, info = evaluate(plan, 'base')
print('start', best, info, flush=True)
random.seed(TIRE + 100 * SEED + 1000 * TRACK)
curves = sorted(plan)
for r in range(ROUNDS):
    cands = []
    for _ in range(PAR):
        c = random.choice(curves); k = random.choice(['vt', 'vt', 'lead', 'marg', 'rel', 'ine', 'a', 'send'])
        n = json.loads(json.dumps({str(a): b for a, b in plan.items()})); n = {int(a): b for a, b in n.items()}
        step = STEP[k] * random.choice([-2, -1, 1, 1, 2]) 
        lo, hi = LIM[k]; n[c][k] = min(hi, max(lo, n[c].get(k, 240 if k == 'ine' else 1.0 if k == 'a' else 0) + step))
        cands.append((c, k, n))
    with cf.ThreadPoolExecutor(PAR) as ex: res = list(ex.map(lambda a: evaluate(a[1][2], f'{a[0]}'), enumerate(cands)))
    i = min(range(PAR), key=lambda j: res[j][0])
    msg = ' '.join('%d.%s=%g:%.2f' % (c, k, n[c][k], sc) for (c, k, n), (sc, _) in zip(cands, res))
    if res[i][0] < best - 1e-6:
        best, info, plan = res[i][0], res[i][1], cands[i][2]; write(plan, os.path.join(ROOT, OUT))
        print(f'round {r} IMPROVED {best:.2f} {info}  [{msg}]', flush=True)
    else: print(f'round {r} no gain [{msg}]', flush=True)
write(plan, os.path.join(ROOT, OUT)); print('done', best, info)
