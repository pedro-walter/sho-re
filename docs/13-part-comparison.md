# 13 - Part comparison on track 1 (v6 autopilot)

All 96 combinations of frame, engine, brake, muffler, oil in {0,1} and tire 0, 1, 2. One standing-start lap of track 1, no bots, `scripts/autolap6.lua` with the tire's tune (`tune/v6/track1_tT.lua`, tuned with oil 1 and the other parts at 0, **not** re-tuned per combination). Skid / off-road frames are listed but do not exclude a run; a run is flagged `outlier` only when it is more than 3 s slower than the median of the runs with the same tire and engine tier. Tool: `tools/partsweep6.py 1 OUT.csv` + `tools/partreport6.py`; data: `docs/data/partsweep6_track1.csv`.

## Effect of each part (tier 0 -> 1, same everything else; non-outlier pairs)

| part | mean | median | min .. max | pairs |
|---|---|---|---|---|
| frame | +0.17 s | +0.08 s | -0.30 .. +0.85 | 48 |
| engine | -2.78 s | -2.80 s | -4.20 .. -1.95 | 48 |
| brake | -0.08 s | -0.05 s | -0.70 .. +0.20 | 48 |
| muffler | -0.73 s | -0.73 s | -1.70 .. -0.25 | 48 |
| oil | -0.73 s | -0.73 s | -1.70 .. -0.25 | 48 |
| tire 0 -> 1 | -0.96 s | -0.90 s | -1.70 .. -0.40 | 32 |
| tire 1 -> 2 | -2.54 s | -2.52 s | -3.50 .. -1.75 | 32 |

## Best lap per tire

| tire | best | F E B M O | stock |
|---|---|---|---|
| 0 | 112.73 | 0 1 1 1 1 | 117.13 |
| 1 | 111.43 | 0 1 0 1 1 | 116.03 |
| 2 | 109.58 | 0 1 1 1 1 | 113.33 |

## All combinations (sorted by tire, then F E B M O)

| tire | F E B M O | lap (s) | vs stock | skid | off | |
|---|---|---|---|---|---|---|
| 0 | 0 0 0 0 0 | 117.13 | +0.00 | 84 | 171 |  |
| 0 | 0 0 0 0 1 | 115.88 | -1.25 | 90 | 153 |  |
| 0 | 0 0 0 1 0 | 115.88 | -1.25 | 90 | 153 |  |
| 0 | 0 0 0 1 1 | 115.08 | -2.05 | 84 | 159 |  |
| 0 | 0 0 1 0 0 | 117.03 | -0.10 | 90 | 168 |  |
| 0 | 0 0 1 0 1 | 115.83 | -1.30 | 96 | 183 |  |
| 0 | 0 0 1 1 0 | 115.83 | -1.30 | 96 | 183 |  |
| 0 | 0 0 1 1 1 | 114.98 | -2.15 | 99 | 186 |  |
| 0 | 0 1 0 0 0 | 113.93 | -3.20 | 84 | 210 |  |
| 0 | 0 1 0 0 1 | 113.63 | -3.50 | 105 | 192 |  |
| 0 | 0 1 0 1 0 | 113.63 | -3.50 | 105 | 192 |  |
| 0 | 0 1 0 1 1 | 112.88 | -4.25 | 96 | 201 |  |
| 0 | 0 1 1 0 0 | 113.83 | -3.30 | 108 | 192 |  |
| 0 | 0 1 1 0 1 | 113.28 | -3.85 | 96 | 180 |  |
| 0 | 0 1 1 1 0 | 113.28 | -3.85 | 96 | 180 |  |
| 0 | 0 1 1 1 1 | 112.73 | -4.40 | 87 | 183 |  |
| 0 | 1 0 0 0 0 | 117.98 | +0.85 | 207 | 276 |  |
| 0 | 1 0 0 0 1 | 116.28 | -0.85 | 117 | 168 |  |
| 0 | 1 0 0 1 0 | 116.28 | -0.85 | 117 | 168 |  |
| 0 | 1 0 0 1 1 | 115.18 | -1.95 | 105 | 159 |  |
| 0 | 1 0 1 0 0 | 117.28 | +0.15 | 102 | 333 |  |
| 0 | 1 0 1 0 1 | 116.03 | -1.10 | 93 | 144 |  |
| 0 | 1 0 1 1 0 | 116.03 | -1.10 | 93 | 144 |  |
| 0 | 1 0 1 1 1 | 115.23 | -1.90 | 87 | 189 |  |
| 0 | 1 1 0 0 0 | 113.78 | -3.35 | 99 | 312 |  |
| 0 | 1 1 0 0 1 | 113.33 | -3.80 | 87 | 162 |  |
| 0 | 1 1 0 1 0 | 113.33 | -3.80 | 87 | 162 |  |
| 0 | 1 1 0 1 1 | 112.93 | -4.20 | 99 | 186 |  |
| 0 | 1 1 1 0 0 | 113.93 | -3.20 | 105 | 243 |  |
| 0 | 1 1 1 0 1 | 113.23 | -3.90 | 105 | 183 |  |
| 0 | 1 1 1 1 0 | 113.23 | -3.90 | 105 | 183 |  |
| 0 | 1 1 1 1 1 | 112.88 | -4.25 | 117 | 216 |  |
| 1 | 0 0 0 0 0 | 116.03 | +0.00 | 129 | 165 |  |
| 1 | 0 0 0 0 1 | 115.38 | -0.65 | 150 | 234 |  |
| 1 | 0 0 0 1 0 | 115.38 | -0.65 | 150 | 234 |  |
| 1 | 0 0 0 1 1 | 114.38 | -1.65 | 150 | 213 |  |
| 1 | 0 0 1 0 0 | 115.83 | -0.20 | 60 | 93 |  |
| 1 | 0 0 1 0 1 | 114.98 | -1.05 | 99 | 174 |  |
| 1 | 0 0 1 1 0 | 114.98 | -1.05 | 99 | 174 |  |
| 1 | 0 0 1 1 1 | 114.13 | -1.90 | 57 | 120 |  |
| 1 | 0 1 0 0 0 | 112.78 | -3.25 | 42 | 81 |  |
| 1 | 0 1 0 0 1 | 111.93 | -4.10 | 78 | 162 |  |
| 1 | 0 1 0 1 0 | 111.93 | -4.10 | 78 | 162 |  |
| 1 | 0 1 0 1 1 | 111.43 | -4.60 | 48 | 93 |  |
| 1 | 0 1 1 0 0 | 112.68 | -3.35 | 99 | 132 |  |
| 1 | 0 1 1 0 1 | 111.88 | -4.15 | 60 | 108 |  |
| 1 | 0 1 1 1 0 | 111.88 | -4.15 | 60 | 108 |  |
| 1 | 0 1 1 1 1 | 111.43 | -4.60 | 84 | 147 |  |
| 1 | 1 0 0 0 0 | 116.78 | +0.75 | 210 | 246 |  |
| 1 | 1 0 0 0 1 | 115.38 | -0.65 | 138 | 162 |  |
| 1 | 1 0 0 1 0 | 115.38 | -0.65 | 138 | 162 |  |
| 1 | 1 0 0 1 1 | 114.78 | -1.25 | 204 | 264 |  |
| 1 | 1 0 1 0 0 | 116.58 | +0.55 | 177 | 222 |  |
| 1 | 1 0 1 0 1 | 115.43 | -0.60 | 168 | 219 |  |
| 1 | 1 0 1 1 0 | 115.43 | -0.60 | 168 | 219 |  |
| 1 | 1 0 1 1 1 | 114.73 | -1.30 | 189 | 261 |  |
| 1 | 1 1 0 0 0 | 113.18 | -2.85 | 204 | 231 |  |
| 1 | 1 1 0 0 1 | 112.28 | -3.75 | 177 | 210 |  |
| 1 | 1 1 0 1 0 | 112.28 | -3.75 | 177 | 210 |  |
| 1 | 1 1 0 1 1 | 112.03 | -4.00 | 207 | 243 |  |
| 1 | 1 1 1 0 0 | 113.08 | -2.95 | 156 | 213 |  |
| 1 | 1 1 1 0 1 | 112.48 | -3.55 | 198 | 240 |  |
| 1 | 1 1 1 1 0 | 112.48 | -3.55 | 198 | 240 |  |
| 1 | 1 1 1 1 1 | 111.78 | -4.25 | 174 | 243 |  |
| 2 | 0 0 0 0 0 | 113.33 | +0.00 | 3 | 60 |  |
| 2 | 0 0 0 0 1 | 112.53 | -0.80 | 15 | 81 |  |
| 2 | 0 0 0 1 0 | 112.53 | -0.80 | 15 | 81 |  |
| 2 | 0 0 0 1 1 | 111.63 | -1.70 | 12 | 69 |  |
| 2 | 0 0 1 0 0 | 113.33 | +0.00 | 9 | 30 |  |
| 2 | 0 0 1 0 1 | 112.58 | -0.75 | 12 | 87 |  |
| 2 | 0 0 1 1 0 | 112.58 | -0.75 | 12 | 87 |  |
| 2 | 0 0 1 1 1 | 111.68 | -1.65 | 0 | 48 |  |
| 2 | 0 1 0 0 0 | 110.53 | -2.80 | 12 | 81 |  |
| 2 | 0 1 0 0 1 | 110.03 | -3.30 | 9 | 57 |  |
| 2 | 0 1 0 1 0 | 110.03 | -3.30 | 9 | 57 |  |
| 2 | 0 1 0 1 1 | 109.68 | -3.65 | 30 | 81 |  |
| 2 | 0 1 1 0 0 | 110.38 | -2.95 | 12 | 27 |  |
| 2 | 0 1 1 0 1 | 110.03 | -3.30 | 15 | 72 |  |
| 2 | 0 1 1 1 0 | 110.03 | -3.30 | 15 | 72 |  |
| 2 | 0 1 1 1 1 | 109.58 | -3.75 | 9 | 72 |  |
| 2 | 1 0 0 0 0 | 113.28 | -0.05 | 9 | 36 |  |
| 2 | 1 0 0 0 1 | 112.38 | -0.95 | 9 | 39 |  |
| 2 | 1 0 0 1 0 | 112.38 | -0.95 | 9 | 39 |  |
| 2 | 1 0 0 1 1 | 111.63 | -1.70 | 15 | 57 |  |
| 2 | 1 0 1 0 0 | 113.38 | +0.05 | 15 | 45 |  |
| 2 | 1 0 1 0 1 | 112.38 | -0.95 | 9 | 42 |  |
| 2 | 1 0 1 1 0 | 112.38 | -0.95 | 9 | 42 |  |
| 2 | 1 0 1 1 1 | 111.73 | -1.60 | 18 | 48 |  |
| 2 | 1 1 0 0 0 | 110.48 | -2.85 | 9 | 42 |  |
| 2 | 1 1 0 0 1 | 109.98 | -3.35 | 9 | 39 |  |
| 2 | 1 1 0 1 0 | 109.98 | -3.35 | 9 | 39 |  |
| 2 | 1 1 0 1 1 | 109.58 | -3.75 | 12 | 60 |  |
| 2 | 1 1 1 0 0 | 110.43 | -2.90 | 9 | 42 |  |
| 2 | 1 1 1 0 1 | 109.93 | -3.40 | 9 | 48 |  |
| 2 | 1 1 1 1 0 | 109.93 | -3.40 | 9 | 48 |  |
| 2 | 1 1 1 1 1 | 109.63 | -3.70 | 21 | 57 |  |

## Investigation: frame 1 combinations that were far too slow (first sweep)

In the first sweep many tire 1 + frame 1 runs lost 5-15 s (120-131 s against 116 s for frame 0) and some skidded to a standstill at T6. Findings:

* The steering model is exact with frame 1 (`tools/steermodel.py` on an `SHO_MLOG` run: 498 cycles, 0 mismatches in handlebar, steering, lean and lateral), so the autopilot *does* adapt to the faster handlebar; that was not the cause.
* The cause is the replan inside a curve (`next_cmd` in `scripts/model6.lua`). In T4 (left, inside entry, push too strong for the lock to hold the line) the real lateral position differed by 6-8 units from the prediction at d=549 (the push jitters between -5 and -6 there). That crosses the 8-unit deviation threshold and triggers `best_plan` towards the curve's own line (240). That plan cannot arrive in the curve, so it arrives after the exit and **releases the steering** (s from -127 to -73) while still in the curve. The bike falls outward 10 units/tick, is at lat -288 (beyond the road edge) when T5 starts, and arrives at T5/T6 with no lock. With frame 0 the prediction happened to stay inside the threshold, so the lock was held. It was luck, not frame 1 handling: any small mismatch triggers it.
* Fix: inside a curve, when the steering is already saturated toward the target (|steer| >= 120) and the target is within 90 units, the continuous hold law is used instead of a replan (`sat_hold` in `model6.lua`, `SHO_SATHOLD`). Frame 1 runs 126-131 s -> 113-115 s; 23 of 96 runs changed, none got slower.
* **Tire 0 is excluded (`SHO_SATHOLD=0` for tire 0)**: with the lock held, tire 0 gets 5-15 s *slower* in almost every combination (the T4 -> T5 swing then starts too late/early and T5 is lost). Tire 0's old behaviour depends on the mid-curve replan releasing the lock; I did not find a rule that is right for both. Open.
* Frame 1 is still worth about +0.17 s on average on this fixed tune (not faster): the tunes are limited by the tire, as you said, and the extra handlebar speed is not used by the plan (e.g. `hb_target` waits for the settle time with the same margins).
