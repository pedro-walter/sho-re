-- v6 plan (scripts/autolap6.lua), track 1, tire 1: per curve only the entry speed and the entry position; the timing of the steering and braking is computed from the exact model (docs/12).
-- Run it with:  tools/lap.sh tune/v6/track1_t1.lua my_try     (writes out/video/my_try.mp4, prints the per-turn table and the lap time)
--   vt  entry speed at the curve start (raw units; HUD km/h = raw*1.1625). 999 = no braking for this curve. Omit the field = computed automatically (optimistic for hairpins).
--   a   entry position: lateral offset toward the inside edge at the curve start as a fraction of 240 (1 = inside edge, 0 = road centre, <0 = outside).
return {
  params = {                                      -- read by tools/lap.sh
    track = 1,  tire = 1,  laps = 1,                 -- which track (1-3) and tire tier (0-4) to drive, and how many laps to render
    frame = 0,   engine = 0, brake = 0,  muffler = 0, oil = 1,   -- part tiers (tire is above): frame 0-5, engine 0-5, brake 0-4, muffler 0-3, oil 0-3, tire 0-4
    start_kmh = 0,                                    -- speed at the start of the first lap in HUD km/h: 0 = standing start, 280 = full speed
    stop_turn = 0,                                    -- 0 = full run; N = stop (and render only) up to the end of turn N of the first lap
    start_after_turn = 0,                             -- 0 = start at the line; N = drive turns 1..N unrendered and start the render at the end of turn N, at start_kmh
    script = "autolap6.lua",                          -- controller script
  },
  [104] = { vt = 999, a = 1 },  -- T1
  [251] = { vt = 235, a = 1 },  -- T2
  [378] = { vt = 999, a = 1 },  -- T3
  [532] = { vt = 233, a = 1 },  -- T4
  [600] = { vt = 184, a = 1 },  -- T5
  [639] = { vt = 190, a = 1 },  -- T6
  [861] = { vt = 999, a = 1 },  -- T7
  [961] = { vt = 999, a = 1 },  -- T8
  [1020] = { vt = 999, a = 1 },  -- T9
  [1128] = { vt = 999, a = 1 },  -- T10
  [1250] = { vt = 233, a = 1 },  -- T11
  [1320] = { vt = 999, a = 1 },  -- T12
  [1581] = { vt = 219, a = 1 },  -- T13
  [1625] = { vt = 999, a = 1 },  -- T14
  [1836] = { vt = 999, a = 1.1 },  -- T15
}
