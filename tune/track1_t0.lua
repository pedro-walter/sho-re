-- Track 1, tire 0: tunable plan (copy of the search result plan_track1_t0_q.lua). Run it with:
--   tools/lap.sh tune/track1_t0.lua my_try1     (about 40 s, writes out/video/my_try1.mp4 and prints the per-turn table)
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
    track = 1,  tire = 0,  laps = 2,                 -- which track (1-3) and tire tier (0-4) to drive, and how many laps to render
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
  [104] =  { vt = 999, inside = 100, marg = 0,  rel = 20 },  -- T1
  [251] =  { vt = 207, inside = 100, marg = 0,  rel = 0 },  -- T2
  [378] =  { vt = 999, inside = 100, marg = 25, rel = 0 },  -- T3
  [532] =  { vt = 999, inside = 100, marg = 0,  rel = 20 },  -- T4
  [600] =  { vt = 190, inside = 100, marg = 0,  rel = 0 },  -- T5
  [639] =  { vt = 181, inside = 100, marg = 0,  rel = 0 },  -- T6
  [861] =  { vt = 999, inside = 100, marg = 0,  rel = 20 },  -- T7
  [961] =  { vt = 999, inside = 100, marg = 0,  rel = 20 },  -- T8
  [1020] = { vt = 999, inside = 103, marg = 0,  rel = 20 },  -- T9
  [1128] = { vt = 999, inside = 100, marg = 0,  rel = 20 },  -- T10
  [1250] = { vt = 999, inside = 103, marg = 0,  rel = 20 },  -- T11
  [1320] = { vt = 999, inside = 100, marg = 0,  rel = 20, ine = 255, send = 15 },  -- T12
  [1581] = { vt = 199, inside = 100, marg = 20, rel = 20 },  -- T13
  [1625] = { vt = 999, inside = 100, marg = 0,  rel = 0,  ine = 270, ext = 51 },  -- T14
  [1836] = { vt = 999, inside = 100, marg = 10, rel = 20, ine = 270, send = 108 },  -- T15
}
