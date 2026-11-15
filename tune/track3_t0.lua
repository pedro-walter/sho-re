-- Track 3, tire 0: tunable plan (copy of the search result plan_track3_t0_q.lua). Run it with:
--   tools/lap.sh tune/track3_t0.lua my_try1     (about 40 s, writes out/video/my_try1.mp4 and prints the per-turn table)
-- Keys are the curve start distances (turn number in the comment). Fields per curve:
--   (params: run settings read by lap.sh; track and tire are required, the rest are defaults.)
--   vt    planned speed at the curve start (raw units; HUD km/h = raw*1.1625). Higher = brakes later / carries more speed in.
--   a     how far toward the inside edge the bike is at the curve start (1.0 = edge at 240; 0.5 = halfway). Pressing starts to reach it.
--   lead  frames before the curve end at which the lock switches to the NEXT curve (only matters when the next curve is the opposite way).
--   marg  extra frames of early turn-in before the curve starts (positive = turn earlier).
--   rel   frames before the curve end at which the full lock is eased (when a straight follows).
--   ine   (optional) inside-edge target, default 240; up to 290 goes over the road edge line (270).
--   ext   (optional) distance units the push really continues after the curve's table end (the push follows the drawn road, which can outlast the curve list). Keeps steering through it.
--   send  (optional) gentle curves only: distance units before the end where the push really stops.
return {
  params = {                                      -- read by tools/lap.sh
    track = 3,  tire = 0,  laps = 1,                 -- which track (1-3) and tire tier (0-4) to drive, and how many laps to render
    gent = 80,   gfade = 40,                          -- radius from which a curve is steered gently (proportional), and frames over which that steering fades at its end
    lead = 40,   rel = 20,   marg = 0,                -- defaults for the per-curve lead / rel / marg below
    br = 0.35,   tpre = 150, duty = 1.0, engine = 0,  -- braking factor, steering pre-press frames, press duty cycle, engine tier
    script = "autolap5.lua",                          -- controller script
  },
  [116] =  { vt = 225, a = 1,    lead = 85, marg = 0,  rel = 20 },  -- T1
  [385] =  { vt = 241, a = 0.75, lead = 20, marg = 0,  rel = 20 },  -- T2
  [670] =  { vt = 149, a = 1,    lead = 0,  marg = 0,  rel = 20 },  -- T3
  [743] =  { vt = 999, a = 1,    lead = 0,  marg = 0,  rel = 30 },  -- T4
  [979] =  { vt = 140, a = 1,    lead = 0,  marg = 25, rel = 20 },  -- T5
  [1232] = { vt = 140, a = 1,    lead = 0,  marg = 25, rel = 20 },  -- T6
  [1411] = { vt = 145, a = 1,    lead = 40, marg = 0,  rel = 20 },  -- T7
  [1478] = { vt = 105, a = 0.5,  lead = 70, marg = 0,  rel = 20 },  -- T8
  [1549] = { vt = 129, a = 1,    lead = 25, marg = 0,  rel = 30 },  -- T9
  [1659] = { vt = 241, a = 0.75, lead = 20, marg = 0,  rel = 20 },  -- T10
  [1810] = { vt = 125, a = 1,    lead = 0,  marg = 0,  rel = 0 },  -- T11
}
