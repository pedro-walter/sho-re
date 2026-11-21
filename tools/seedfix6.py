#!/usr/bin/env python3
"""Make a crash-free seed plan: run the plan, find the first skid/off-road tick, lower vt of the curve at/before it (and the one before when the crash is on a straight), repeat.
Usage: seedfix6.py PLAN.lua OUT.lua TAG [key=val ...]  (run6 keys). Env STEP (default 14), MAXIT (default 40)."""
import re, sys, os, subprocess, shutil
plan, out, tag = sys.argv[1], sys.argv[2], sys.argv[3]; extra = sys.argv[4:]
STEP = int(os.environ.get('STEP', 14)); MAXIT = int(os.environ.get('MAXIT', 40))
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
txt = open(plan).read(); shutil.copy(plan, out)
def keys(t): return [(int(m[1]), float(m[2])) for m in re.finditer(r'\[(\d+)\]\s*=\s*\{\s*vt\s*=\s*([\d.]+)', t)]
for it in range(MAXIT):
    txt = open(out).read()
    r = subprocess.run(['python3', 'tools/run6.py', out, f'{tag}_{it}'] + extra, cwd=ROOT, capture_output=True, text=True).stdout
    bad = None
    for ln in open(f'{ROOT}/out/r6/{tag}_{it}.txt'):
        m = re.search(r' T k=\d+ d=(\d+) lap=\d .* lat=(-?\d+) .* skid=(\d+)', ln)
        if m and (int(m[3]) or abs(int(m[2])) > 300): bad = int(m[1]); break
    m = re.search(r'total ([\d.]+) s \((\d)/(\d) laps', r)
    print(it, r.strip().splitlines()[-1], 'bad at', bad, flush=True)
    if bad is None and m and m[2] == m[3]: print('CLEAN'); break
    ks = keys(txt); d = (bad if bad is not None else 99999) % 2048
    cand = [s for s, v in ks if s <= d]; tgt = cand[-1] if cand else ks[-1][0]
    idx = [s for s, v in ks].index(tgt)
    for j in ([idx] if True else []):
        s, v = ks[j]; nv = min(v, 260) - STEP
        txt = re.sub(r'(\[%d\]\s*=\s*\{\s*vt\s*=\s*)[\d.]+' % s, lambda mm: mm[1] + str(max(60, nv)), txt)
    # on a crash early in a curve, the previous curve's exit is usually the cause: lower it a bit too
    if idx > 0 and os.environ.get('PREV','1')=='1':
        s, v = ks[idx - 1]; nv = min(v, 260) - STEP // 2
        txt = re.sub(r'(\[%d\]\s*=\s*\{\s*vt\s*=\s*)[\d.]+' % s, lambda mm: mm[1] + str(max(60, nv)), txt)
    open(out, 'w').write(txt)
