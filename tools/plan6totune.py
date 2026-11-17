#!/usr/bin/env python3
"""Write a v6 tune file (tune/v6/trackN_tT.lua) from a plansearch6 result plan.
Usage: tools/plan6totune.py PLAN6.lua TRACK TIRE OUT.lua [oil] [laps]"""
import re, sys
plan, track, tire, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
oil = sys.argv[5] if len(sys.argv) > 5 else '1'; laps = sys.argv[6] if len(sys.argv) > 6 else '1'
rows = sorted((int(m[1]), dict((k, float(v)) for k, v in re.findall(r'(\w+)\s*=\s*([-\d.]+)', m[2]))) for m in re.finditer(r'\[(\d+)\]\s*=\s*\{([^}]*)\}', open(plan).read()))
hdr = f'''-- v6 plan (scripts/autolap6.lua), track {track}, tire {tire}: per curve only the entry speed and the entry position; the timing of the steering and braking is computed from the exact model (docs/12).
-- Run it with:  tools/lap.sh {out} my_try     (writes out/video/my_try.mp4, prints the per-turn table and the lap time)
--   vt  entry speed at the curve start (raw units; HUD km/h = raw*1.1625). 999 = no braking for this curve. Omit the field = computed automatically (optimistic for hairpins).
--   a   entry position: lateral offset toward the inside edge at the curve start as a fraction of 240 (1 = inside edge, 0 = road centre, <0 = outside).
--   cruise  optional, cruise = 1: keep a constant speed through this curve (the entry speed) instead of accelerating (e.g. to prepare the next curve).
return {{
  params = {{                                      -- read by tools/lap.sh
    track = {track},  tire = {tire},  laps = {laps},                 -- which track (1-3) and tire tier (0-4) to drive, and how many laps to render
    frame = 0,   engine = 0, brake = 0,  muffler = 0, oil = {oil},   -- part tiers (tire is above): frame 0-5, engine 0-5, brake 0-4, muffler 0-3, oil 0-3, tire 0-4
    start_kmh = 0,                                    -- speed at the start of the first lap in HUD km/h: 0 = standing start, 280 = full speed
    stop_turn = 0,                                    -- 0 = full run; N = stop (and render only) up to the end of turn N of the first lap
    start_after_turn = 0,                             -- 0 = start at the line; N = drive turns 1..N unrendered and start the render at the end of turn N, at start_kmh
    script = "autolap6.lua",                          -- controller script
  }},
'''
body = ''.join(f'  [{s}] = {{ vt = {r["vt"]:g}, a = {r["a"]:g}{", cruise = 1" if r.get("cruise") else ""} }},  -- T{i+1}\n' for i, (s, r) in enumerate(rows))
open(out, 'w').write(hdr + body + '}\n')
