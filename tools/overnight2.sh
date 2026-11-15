#!/bin/bash
# Second search: new plan fields (ine, a, send), gentle-curve fade for r>=80, track 1 then track 2, tires chained 0->4.
cd "$(dirname "$0")/.."
export PAR=8
rm -f /tmp/ov2_done.txt
TRACK=1 SEED=3 python3 tools/plansearch.py 0 scripts/plan_track1_t0_p3.lua scripts/plan_track1_t0_p4.lua 60 > /tmp/ov2_1_0.log 2>&1
prev=scripts/plan_track1_t0_p4.lua
for t in 1 2 3 4; do TRACK=1 SEED=3 python3 tools/plansearch.py $t $prev scripts/plan_track1_t${t}_p4.lua 40 > /tmp/ov2_1_$t.log 2>&1; prev=scripts/plan_track1_t${t}_p4.lua; done
python3 tools/mkplan.py 2 0 out/plans/init_t2_0.lua
TRACK=2 SEED=3 python3 tools/plansearch.py 0 out/plans/init_t2_0.lua scripts/plan_track2_t0_p4.lua 60 > /tmp/ov2_2_0.log 2>&1
prev=scripts/plan_track2_t0_p4.lua
for t in 1 2 3 4; do TRACK=2 SEED=3 python3 tools/plansearch.py $t $prev scripts/plan_track2_t${t}_p4.lua 40 > /tmp/ov2_2_$t.log 2>&1; prev=scripts/plan_track2_t${t}_p4.lua; done
echo ALLDONE > /tmp/ov2_done.txt
