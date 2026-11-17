#!/usr/bin/env python3
"""Convert an autolap5 tune file into a v6 tune file: keeps only the entry speed vt and the entry position a per curve.
Usage: tools/mktune6.py tune/track1_t0.lua tune/v6/track1_t0.lua"""
import re, sys
src, dst = sys.argv[1], sys.argv[2]
txt = open(src).read()
params = re.search(r'params\s*=\s*\{.*?\n  \},\n', txt, re.S)[0]
params = re.sub(r'script = "[^"]*"', 'script = "autolap6.lua"', params)
rows = []
for ln in txt.split('\n'):
    m = re.match(r'\s*\[(\d+)\]\s*=\s*\{(.*)\},?\s*(--.*)?$', ln)
    if m:
        f = dict((k, float(v)) for k, v in re.findall(r'(\w+)\s*=\s*([-\d.]+)', m[2]))
        rows.append((int(m[1]), f.get('vt', 999), f.get('a', 1.0), m[3] or ''))
rows.sort()
hdr = f'''-- v6 plan (scripts/autolap6.lua): per curve only the entry speed and the entry position; the steering timing is computed from the exact lateral model.
-- Run it with:  tools/lap.sh {dst} my_try     (writes out/video/my_try.mp4, prints the per-turn table and the lap time)
--   vt  entry speed at the curve start (raw units; HUD km/h = raw*1.1625). 999 = never brake for this curve.
--   a   entry position: lateral offset toward the inside edge at the curve start as a fraction of 240 (1 = inside edge, 0 = road centre, <0 = outside).
'''
out = hdr + 'return {\n' + params
for s, vt, a, c in rows:
    out += f'  [{s}] = {{ vt = {vt:g}, a = {a:g} }},  {c}\n'
out += '}\n'
open(dst, 'w').write(out)
