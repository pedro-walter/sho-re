-- Track 1, tire 0: tunable plan (copy of the search result plan_track1_t0_q.lua). Run it with:
--   tools/lap.sh scripts/plan_track1_tune_t0.lua 1 0 my_try1     (about 40 s, writes out/video/my_try1.mp4 and prints the per-turn table)
-- Keys are the curve start distances (turn number in the comment). Fields per curve:
--   vt    planned speed at the curve start (raw units; HUD km/h = raw*1.1625). Higher = brakes later / carries more speed in.
--   a     how far toward the inside edge the bike is at the curve start (1.0 = edge at 240; 0.5 = halfway). Pressing starts to reach it.
--   lead  frames before the curve end at which the lock switches to the NEXT curve (only matters when the next curve is the opposite way).
--   marg  extra frames of early turn-in before the curve starts (positive = turn earlier).
--   rel   frames before the curve end at which the full lock is eased (when a straight follows).
--   ine   (optional) inside-edge target, default 240; up to 290 goes over the road edge line (270).
--   send  (optional) gentle curves only: distance units before the end where the push really stops.
return {
  [104] =  { vt = 999, a = 1,   lead = 0,   marg = 0,  rel = 20 },  -- T1
  [251] =  { vt = 999, a = 1,   lead = 0,   marg = 0,  rel = 20 },  -- T2
  [378] =  { vt = 999, a = 1,   lead = 20,   marg = 0,  rel = 20 },  -- T3
  [532] =  { vt = 999, a = 1,   lead = 55,  marg = 0,  rel = 20 },  -- T4
  [600] =  { vt = 188, a = 1,   lead = 0,   marg = 0,  rel = 20 },  -- T5
  [639] =  { vt = 170, a = 1,   lead = 0,   marg = 0,  rel = 20 },  -- T6
  [861] =  { vt = 999, a = 1,   lead = 55,  marg = 0,  rel = 20 },  -- T7
  [961] =  { vt = 999, a = 1.3, lead = 0,   marg = 0,  rel = 20 },  -- T8
  [1020] = { vt = 999, a = 1,   lead = 0,   marg = 0,  rel = 20 },  -- T9
  [1128] = { vt = 999, a = 1,   lead = 130, marg = 0,  rel = 20 },  -- T10
  [1250] = { vt = 999, a = 1.3, lead = 0,   marg = 0,  rel = 20 },  -- T11
  [1320] = { vt = 999, a = 1,   lead = 0,   marg = 0,  rel = 20, ine = 255, send = 15 },   -- T12
  [1581] = { vt = 194, a = 1,   lead = 0,   marg = 20, rel = 20 },  -- T13
  [1625] = { vt = 999, a = 1,   lead = 0,   marg = 0,  rel = 20, ine = 180 },              -- T14
  [1836] = { vt = 999, a = 1,   lead = 0,   marg = 10, rel = 20, ine = 270, send = 108 },  -- T15
}
