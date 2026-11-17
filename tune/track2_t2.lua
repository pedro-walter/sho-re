-- Track 2, tire 2: tunable plan (copy of the search result plan_track2_t2_o1.lua). Run it with:
--   tools/lap.sh tune/track2_t2.lua my_try1     (about 40 s, writes out/video/my_try1.mp4 and prints the per-turn table)
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
    track = 2,  tire = 2,  laps = 1,                 -- which track (1-3) and tire tier (0-4) to drive, and how many laps to render
    gent = 80,   gfade = 40,                          -- radius from which a curve is steered gently (proportional), and frames over which that steering fades at its end
    lead = 40,   rel = 20,   marg = 0,                -- defaults for the per-curve lead / rel / marg below
    br = 0.35,   tpre = 150, duty = 1.0,              -- braking factor, steering pre-press frames, press duty cycle
    frame = 0,   engine = 0, brake = 0,  muffler = 0, oil = 1,   -- part tiers (tire is above): frame 0-5, engine 0-5, brake 0-4, muffler 0-3, oil 0-3, tire 0-4
    start_kmh = 0,                                    -- speed at the start of the first lap in HUD km/h: 0 = standing start, 280 = full speed
    bmargin = 1.25,                                   -- safety factor on the braking distance (the controller learns the real brake deceleration while it drives): 1 = brake as late as the model allows
    stop_turn = 0,                                    -- 0 = full run; N = stop (and render only) up to the end of turn N of the first lap (fast tuning of early turns)
    start_after_turn = 0,                             -- 0 = start at the line; N = drive turns 1..N unrendered and start the render/log at the end of turn N, at start_kmh (the pre-roll still runs the plan from a standing start)
    script = "autolap5.lua",                          -- controller script
  },
  [84] =   { vt = 241, a = 1, lead = 55, marg = 0,  rel = 20 },  -- T1
  [171] =  { vt = 188, a = 1, lead = 55, marg = 0,  rel = 20, ine = 180 },  -- T2
  [235] =  { vt = 203, a = 1, lead = 55, marg = 0,  rel = 20, ine = 210 },  -- T3
  [291] =  { vt = 117, a = 1, lead = 0,  marg = 0,  rel = 20 },  -- T4
  [441] =  { vt = 241, a = 1, lead = 0,  marg = 20, rel = 20, ine = 225 },  -- T5
  [580] =  { vt = 196, a = 1, lead = 0,  marg = 20, rel = 20, ine = 270 },  -- T6
  [642] =  { vt = 133, a = 1, lead = 0,  marg = 0,  rel = 20 },  -- T7
  [727] =  { vt = 125, a = 1, lead = 0,  marg = 0,  rel = 20 },  -- T8
  [757] =  { vt = 219, a = 1, lead = 55, marg = 0,  rel = 20, ine = 210 },  -- T9
  [835] =  { vt = 148, a = 1, lead = 0,  marg = 0,  rel = 20 },  -- T10
  [1102] = { vt = 225, a = 1, lead = 0,  marg = 0,  rel = 20, ine = 210 },  -- T11
  [1241] = { vt = 241, a = 1, lead = 0,  marg = 0,  rel = 20, ine = 210 },  -- T12
  [1402] = { vt = 241, a = 1, lead = 0,  marg = 0,  rel = 20, ine = 270 },  -- T13
  [1494] = { vt = 151, a = 1, lead = 40, marg = 0,  rel = 20 },  -- T14
  [1547] = { vt = 219, a = 1, lead = 0,  marg = 0,  rel = 20 },  -- T15
  [1699] = { vt = 241, a = 1, lead = 0,  marg = 0,  rel = 20, ine = 270 },  -- T16
  [1977] = { vt = 167, a = 1, lead = 0,  marg = 10, rel = 20 },  -- T17
}
