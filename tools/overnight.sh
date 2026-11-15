#!/bin/bash
# Overnight plan search: track 3 (tires 0,2,3,4 chained from the tire-1 result), then tracks 1 and 2 (tire-specific initial plans, two 60-round phases each).
cd "$(dirname "$0")/.."
export PAR=8
prev=scripts/plan_track3_s1.lua
for t in 0 2 3 4; do
  src=$prev; [ $t = 0 ] && src=scripts/plan_track3_v8.lua
  TRACK=3 SEED=1 python3 tools/plansearch.py $t $src scripts/plan_track3_s$t.lua 30 > /tmp/ov_3_${t}_p1.log 2>&1
  prev=scripts/plan_track3_s$t.lua
done
for tr in 1 2; do
  for t in 0 1 2 3 4; do
    python3 tools/mkplan.py $tr $t out/plans/init_t${tr}_$t.lua
    TRACK=$tr SEED=1 python3 tools/plansearch.py $t out/plans/init_t${tr}_$t.lua scripts/plan_track${tr}_t${t}_p1.lua 30 > /tmp/ov_${tr}_${t}_p1.log 2>&1
  done
done
for tr in 1 2; do
  for t in 0 1 2 3 4; do
    TRACK=$tr SEED=2 python3 tools/plansearch.py $t scripts/plan_track${tr}_t${t}_p1.lua scripts/plan_track${tr}_t${t}_p2.lua 30 > /tmp/ov_${tr}_${t}_p2.log 2>&1
  done
done
echo ALLDONE > /tmp/ov_done.txt
