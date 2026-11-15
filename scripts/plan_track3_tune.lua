-- Track 3, tire 0: tunable plan (copy of the search result plan_track3_s0.lua). Run it with:
--   tools/lap.sh scripts/plan_track3_tune.lua 3 0 my_try1     (about 40 s, writes out/video/my_try1.mp4 and prints the per-turn table)
-- Keys are the curve start distances (turn number in the comment). Fields per curve:
--   vt    planned speed at the curve start (raw units; HUD km/h = raw*1.1625). Higher = brakes later / carries more speed in.
--   a     how far toward the inside edge the bike is at the curve start (1.0 = edge at 240; 0.5 = halfway). Pressing starts to reach it.
--   ine   (optional) inside-edge target, default 240; up to 290 goes over the road edge line (270).
--   lead  frames before the curve end at which the lock switches to the NEXT curve (only matters when the next curve is the opposite way).
--   marg  extra frames of early turn-in before the curve starts (positive = turn earlier).
--   rel   frames before the curve end at which the full lock is eased (when a straight follows).
--   send  (optional) gentle curves only: distance units before the end where the push really stops.
--   vexit ignored by the autopilot (planner leftover).
return {
  [116] = {  vt = 999, a = 1,    lead = 85, marg = 0,  rel = 20 },  -- T1
  [385] = {  vt = 999, a = 1,    lead = 0,  marg = 0,  rel = 0 },  -- T2
  [670] = {  vt = 154, a = 1,    lead = 0,  marg = 0,  rel = 0 },  -- T3
  [743] = {  vt = 999, a = 1,    lead = 0,  marg = 0,  rel = 10 },  -- T4
  [979] = {  vt = 160, a = 1,    lead = 0,  marg = 15, rel = 0 },  -- T5
  [1232] = { vt = 146, a = 1.01, lead = 0,  marg = 25, rel = 0 },  -- T6
  [1411] = { vt = 145, a = 1,    lead = 40, marg = 0,  rel = 20 },  -- T7
  [1478] = { vt = 999, a = 1,    lead = 70, marg = 0,  rel = 40 },  -- T8
  [1549] = { vt = 139, a = 1,    lead = 0,  marg = 0,  rel = 30 },  -- T9
  [1659] = { vt = 999, a = 1,    lead = 0,  marg = 0,  rel = 20 },  -- T10
  [1810] = { vt = 128, a = 1,    lead = 0,  marg = 0,  rel = 0 },  -- T11
}
