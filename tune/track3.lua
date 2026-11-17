-- Track 3, tire 0: tunable plan (copy of the search result plan_track3_s0.lua). Run it with:
--   tools/lap.sh tune/track3.lua my_try1     (about 40 s, writes out/video/my_try1.mp4 and prints the per-turn table)
-- Keys are the curve start distances (turn number in the comment). Fields per curve:
--   (params: run settings read by lap.sh; track and tire are required, the rest are defaults.)
--   vt    planned speed at the curve start (raw units; HUD km/h = raw*1.1625). Higher = brakes later / carries more speed in.
--   a     how far toward the inside edge the bike is at the curve start (1.0 = edge at 240; 0.5 = halfway). Pressing starts to reach it.
--   ine   (optional) inside-edge target, default 240; up to 290 goes over the road edge line (270).
--   lead  frames before the curve end at which the lock switches to the NEXT curve (only matters when the next curve is the opposite way).
--   marg  extra frames of early turn-in before the curve starts (positive = turn earlier).
--   rel   frames before the curve end at which the full lock is eased (when a straight follows).
--   send  (optional) gentle curves only: distance units before the end where the push really stops.
--   vexit ignored by the autopilot (planner leftover).
return {
  params = {                                      -- read by tools/lap.sh
    track = 3,  tire = 0,  laps = 1,                 -- which track (1-3) and tire tier (0-4) to drive, and how many laps to render
    gent = 80,   gfade = 40,                          -- radius from which a curve is steered gently (proportional), and frames over which that steering fades at its end
    lead = 40,   rel = 20,   marg = 0,                -- defaults for the per-curve lead / rel / marg below
    br = 0.35,   tpre = 150, duty = 1.0,              -- braking factor, steering pre-press frames, press duty cycle
    frame = 0,   engine = 0, brake = 0,  muffler = 0, oil = 0,   -- part tiers (tire is above): frame 0-5, engine 0-5, brake 0-4, muffler 0-3, oil 0-3, tire 0-4
    start_kmh = 0,                                    -- speed at the start of the first lap in HUD km/h: 0 = standing start, 280 = full speed
    bmargin = 1.25,                                   -- safety factor on the braking distance (the controller learns the real brake deceleration while it drives): 1 = brake as late as the model allows
    stop_turn = 0,                                    -- 0 = full run; N = stop (and render only) up to the end of turn N of the first lap (fast tuning of early turns)
    start_after_turn = 0,                             -- 0 = start at the line; N = drive turns 1..N unrendered and start the render/log at the end of turn N, at start_kmh (the pre-roll still runs the plan from a standing start)
    script = "autolap5.lua",                          -- controller script
  },
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
