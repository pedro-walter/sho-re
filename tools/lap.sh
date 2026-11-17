#!/bin/bash
# Drive the lap(s) described by a tune/plan file and render the review video.
# Usage: tools/lap.sh PLAN.lua NAME     -> out/video/NAME.mp4 + per-turn table
# Everything else (track, tire, laps, controller settings) is read from the `params = { ... }` block at the top of PLAN.lua.
set -e
cd "$(dirname "$0")/.."
PLAN=$1; NAME=$2
[ -n "$PLAN" ] && [ -n "$NAME" ] || { echo "usage: tools/lap.sh PLAN.lua NAME"; exit 1; }
export SHO_ROOT=$PWD
PARAMS=$(python3 - "$PLAN" <<'PY'
import re, sys
D = dict(track=None, tire=None, laps=1, script='autolap5.lua', gent=80, gfade=40, lead=40, br=0.35, tpre=150, duty=1.0, rel=20, marg=0, engine=0, frame=0, brake=0, muffler=0, oil=0, start_kmh=0, bmargin=1.25, stop_turn=0, start_after_turn=0)
txt = re.sub(r'--[^\n]*', '', open(sys.argv[1]).read())
m = re.search(r'params\s*=\s*\{(.*?)\}', txt, re.S)
if m:
    for k, v in re.findall(r'(\w+)\s*=\s*([^,\s]+)', m[1]):
        if k not in D: sys.exit(f'unknown param {k} in {sys.argv[1]}')
        D[k] = v.strip('"\'')
for k in ('track', 'tire'):
    if D[k] is None: sys.exit(f'{sys.argv[1]}: params.{k} is missing (add a params = {{ track = .., tire = .. }} block)')
for k, v in D.items(): print(f'P_{k}={v}')
PY
) || exit 1
eval "$PARAMS"
SHO_STARTAFTER=$([ "$P_start_after_turn" != 0 ] && echo $P_start_after_turn) SHO_STOPTURN=$([ "$P_stop_turn" != 0 ] && echo $P_stop_turn) SHO_STARTV=$(awk -v k=$P_start_kmh 'BEGIN{printf "%d", k/1.1625+0.5}') SHO_ONELAP=$P_laps SHO_SNAP=3 SHO_GENT=$P_gent SHO_GFADE=$P_gfade SHO_NOBOTS=1 SHO_NOCHAIN=1 SHO_PLAN=$PLAN SHO_LEAD=$P_lead SHO_BMARG=$P_bmargin SHO_BR=$P_br SHO_LOADSTATE=race$P_track SHO_REL=$P_rel SHO_MARG=$P_marg SHO_TPRE=$P_tpre SHO_DUTY=$P_duty SHO_RIVAL=$((P_track-1)) SHO_TIRE=$P_tire SHO_ENGINE=$P_engine SHO_FRAME=$P_frame SHO_BRAKET=$P_brake SHO_MUFFLER=$P_muffler SHO_OIL=$P_oil SHO_LOG=3 SHO_FRAMES=$((11000 * P_laps)) SHO_TAG=$NAME tools/mame.sh scripts/$P_script > /tmp/$NAME.txt 2>&1
grep "LAP \|STOP " /tmp/$NAME.txt || true
python3 tools/turnstats.py /tmp/$NAME.txt
python3 tools/mkvideo.py /tmp/$NAME.txt $NAME out/video/$NAME.mp4 20 | tail -n 1
python3 - /tmp/$NAME.txt <<'PY'
import re, sys
t = open(sys.argv[1]).read()
r = re.search(r'RENDER START after turn (\d+) k=(\d+)', t); k0 = int(r[2]) if r else 0
if r: print(f'render started at the end of turn {r[1]} (t = {k0/60:.2f} s into the run)')
for m in re.finditer(r'LAP (\d+)->(\d+) at k=(\d+) \(([\d.]+) s\) lap_frames=(\d+)', t):
    print(f'END lap {int(m[1])+1} finished: lap time {int(m[5])/60:.2f} s  (run time {m[4]} s)')
m = re.search(r'STOP at end of turn (\d+) k=(\d+)', t)
if m: print(f'END stopped at the end of turn {m[1]}: run time {int(m[2])/60:.2f} s' + (f', {(int(m[2])-k0)/60:.2f} s since render start' if r else ''))
PY
