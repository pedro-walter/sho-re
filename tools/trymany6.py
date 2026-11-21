#!/usr/bin/env python3
"""Evaluate several plan variants in parallel (nice 19, via run6) and print the per-lap time / skid / off-road frames.
Usage: trymany6.py BASE.lua 'CURVE.key=val;CURVE.key=val' 'CURVE.key=val' ...   (key vt|a|cruise; '' = unchanged)
Env: TRACK TIRE ENGINE OIL FRAME LAPS (defaults 4 3 2 1 1 1), SCRIPT (autolap6t.lua), PAR (8)."""
import re, sys, os, subprocess, concurrent.futures as cf
base = sys.argv[1]; variants = sys.argv[2:]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
E = os.environ
def apply(txt, ed):
    c, kv = ed.split('.', 1); k, v = kv.split('=')
    m = re.search(r'(\[%s\]\s*=\s*\{)([^}]*)\}' % c, txt); body = m[2]
    if re.search(r'\b%s\s*=' % k, body): body = re.sub(r'\b%s\s*=\s*[-\d.]+' % k, f'{k} = {v}', body)
    else: body = body.rstrip() + f', {k} = {v} '
    return txt[:m.start()] + m[1] + body + '}' + txt[m.end():]
def run(i):
    txt = open(base).read()
    for ed in variants[i].split(';'):
        if ed: txt = apply(txt, ed)
    pf = f'out/plans/try_{os.getpid()}_{i}.lua'; open(os.path.join(ROOT, pf), 'w').write(txt)
    args = ['python3', 'tools/run6.py', pf, f'try{i}'] + [f'{k}={E.get(K, d)}' for k, K, d in (('track', 'TRACK', 4), ('tire', 'TIRE', 3), ('engine', 'ENGINE', 2), ('oil', 'OIL', 1), ('frame', 'FRAME', 1), ('laps', 'LAPS', 1))]
    r = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, env=dict(E, SCRIPT=E.get('SCRIPT', 'autolap6t.lua'))).stdout
    return i, r
with cf.ThreadPoolExecutor(int(E.get('PAR', 8))) as ex:
    for i, r in ex.map(run, range(len(variants))):
        print(repr(variants[i]), '|', ' / '.join(l.strip() for l in r.splitlines()[1:]), flush=True)
