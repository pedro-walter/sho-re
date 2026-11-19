# 16 - Engine 2 early vs engine 3 on Appliance (track 3)

Question: after Appliance 1, is it better to buy engine 2 early and engine 3 after Appliance 5, or replace engine 1 and go straight to engine 3 after Appliance 4?

## Method
- v6 autopilot, track 3 (Appliance, 3 laps, standing start), no bots, no crashes (skid=0, only a handful of off-road frames).
- Bike: tire 3, frame 1, oil 1, muffler 0, brake 0. A separate plan was tuned per engine with `tools/plansearch6.py` (random coordinate search, LAPS=3 scoring; E3 searched with 2 laps and verified over 3).
- New turbo-capable autopilot copies: `scripts/autolap6t.lua`, `scripts/model6t.lua` (identical to the originals for engine < 3). Engines >= 3 reach 279 raw with C held (turbo), using the turbo push profile `data/roadprofile_track3_turbo.lua` (measured at turbo speeds, elsewhere 1.7x the normal profile).
- Runner: `python3 tools/run6.py PLAN.lua TAG [key=val ...]`, logs in `out/r6/`.
- Plans: `tune/v6/track3_t3_e{1,2,3}.lua` (seed `start3.lua`).

## Results
| Engine | Lap 1 | Lap 2 | Lap 3 | Total | vs E1 |
|---|---|---|---|---|---|
| 1 | 114.83 | 107.35 | 107.30 | 329.48 | - |
| 2 | 111.63 | 106.60 | 106.65 | 324.88 | -4.6 |
| 3 | 111.43 | 104.85 | 105.30 | 321.58 | -7.9 |

## Conclusions
- Engine 2 gains ~4.6 s/race, mostly on lap 1 (standing start); flying laps gain ~0.75 s each.
- Engine 3 adds only ~3.3 s over engine 2. The raw-model estimate of ~26 s per 2-lap race (docs/08) does not apply: Appliance has short straights, turbo matters only on the final straight.
- Recommendation: engine 2 early, engine 3 after Appliance 5. Postponing engine 3 costs ~3 s per race; engine 2 early gains more in total (~12 s over the sequence).

## Caveats
- Untested against bots; single-seed plan search (about +-1 s tuning noise).
- The turbo push profile is an estimate away from measured points (+-1 s on E3).
- E1 and E3 runs have ~12 trivial off-road frames each, no skids.
- Appliance 1 (frame 0, engine 1), wear and breakdown risk were not simulated.
