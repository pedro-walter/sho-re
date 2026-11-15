#!/bin/bash
# Search on autolap5 (no corrective braking inside curves): tracks 1 and 2 with tires 0-2, track 3 with tires 0-4; tires chained.
cd "$(dirname "$0")/.."
export PAR=8 SCRIPT=autolap5.lua
rm -f /tmp/ov3_done.txt
run() { # track tire start out rounds
  TRACK=$1 SEED=5 python3 tools/plansearch.py $2 $3 $4 $5 > /tmp/ov3_$1_$2.log 2>&1
}
python3 tools/mkplan.py 2 0 out/plans/init_t2_0.lua
starts=(scripts/plan_track1_t0_p4.lua out/plans/init_t2_0.lua scripts/plan_track3_s0.lua)
for tr in 1 2 3; do
  prev=${starts[$((tr-1))]}
  tires="0 1 2"; [ $tr = 3 ] && tires="0 1 2 3 4"
  for t in $tires; do
    run $tr $t $prev scripts/plan_track${tr}_t${t}_q.lua 40
    prev=scripts/plan_track${tr}_t${t}_q.lua
  done
done
echo ALLDONE > /tmp/ov3_done.txt
