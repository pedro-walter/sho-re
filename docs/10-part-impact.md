# 10 - Impact of each part on lap time (track 1, tire 0)

Goal: measure what each part tier is worth in lap time, as input for the speedrun route planner (doc 08).

## Method

* Track 1 (rival 0), **tire 0**, two laps per run: lap 1 is a standing start, lap 2 starts at the lap-1 exit speed (flying).
* Full factorial over **engine, frame, muffler, oil, brake**, each tier 0 or 1: 32 runs (`tools/partsweep.py`, headless MAME, 8 at a time, no backmarkers, health forced to 15).
* **One fixed plan for every run**: `scripts/plan_track1_t0_q.lua` (overnight search result for the stock car) plus `ext = 51` on T14. The plan is **not** re-tuned per combination, so a run with a lot of skid/off-road time is a plan that does not fit the car, not a measure of the part.
* Raw data: `docs/data/partsweep_track1_tire0.csv`. Tables below come from `python3 tools/partreport.py docs/data/partsweep_track1_tire0.csv`.
* Controller: `scripts/autolap5.lua` (no braking inside curves). Part tiers are poked into `$FFB618+2s` every frame (`SHO_FRAME`, `SHO_ENGINE`, `SHO_BRAKET`, `SHO_MUFFLER`, `SHO_OIL`, `SHO_TIRE`), set from the `params` block of a tune file (`tools/lap.sh`).

## Results

Stock parts (all tier 0): lap 1 **121.68 s**, lap 2 **112.25 s**, total **233.93 s**; skid / off-road frames 27 / 96.

One part at tier 1, the others at tier 0:

| part | lap 1 | lap 2 | total | total vs stock | skid / off frames |
|---|---|---|---|---|---|
| engine 1 | 131.93 | 124.15 | 256.08 | -22.15 | 873 / 858 |
| frame 1 | 137.53 | 127.80 | 265.33 | -31.40 | 948 / 945 |
| muffler 1 | 121.28 | 111.65 | 232.93 | +1.00 | 51 / 255 |
| oil 1 | 121.28 | 111.65 | 232.93 | +1.00 | 51 / 255 |
| brake 1 | 121.73 | 112.45 | 234.18 | -0.25 | 33 / 150 |

All 32 combinations, sorted by total time (E F M O B = engine frame muffler oil brake tier):

| E F M O B | lap 1 | lap 2 | total | vs stock | skid / off frames |
|---|---|---|---|---|---|
| 1 0 0 1 0 | 117.78 | 110.75 | 228.53 | +5.40 | 81 / 210 |
| 1 0 1 0 0 | 117.78 | 110.75 | 228.53 | +5.40 | 81 / 210 |
| 0 0 1 1 0 | 119.58 | 111.20 | 230.78 | +3.15 | 84 / 183 |
| 0 0 1 1 1 | 119.88 | 111.15 | 231.03 | +2.90 | 54 / 153 |
| 0 0 0 1 1 | 121.03 | 111.70 | 232.73 | +1.20 | 57 / 216 |
| 0 0 1 0 1 | 121.03 | 111.70 | 232.73 | +1.20 | 57 / 216 |
| 0 0 0 1 0 | 121.28 | 111.65 | 232.93 | +1.00 | 51 / 255 |
| 0 0 1 0 0 | 121.28 | 111.65 | 232.93 | +1.00 | 51 / 255 |
| 0 0 0 0 0 | 121.68 | 112.25 | 233.93 | +0.00 | 27 / 96 |
| 0 0 0 0 1 | 121.73 | 112.45 | 234.18 | -0.25 | 33 / 150 |
| 1 1 1 1 0 | 128.43 | 121.65 | 250.08 | -16.15 | 978 / 990 |
| 1 0 1 1 1 | 129.28 | 122.55 | 251.83 | -17.90 | 834 / 906 |
| 1 1 0 1 0 | 129.53 | 122.30 | 251.83 | -17.90 | 936 / 963 |
| 1 1 1 0 0 | 129.53 | 122.30 | 251.83 | -17.90 | 936 / 963 |
| 1 0 1 1 0 | 129.28 | 122.70 | 251.98 | -18.05 | 849 / 864 |
| 1 0 0 1 1 | 130.53 | 123.35 | 253.88 | -19.95 | 864 / 861 |
| 1 0 1 0 1 | 130.53 | 123.35 | 253.88 | -19.95 | 864 / 861 |
| 1 1 0 0 1 | 130.88 | 123.10 | 253.98 | -20.05 | 966 / 999 |
| 1 1 0 0 0 | 130.78 | 123.30 | 254.08 | -20.15 | 987 / 996 |
| 1 0 0 0 0 | 131.93 | 124.15 | 256.08 | -22.15 | 873 / 858 |
| 0 1 1 1 0 | 133.83 | 125.20 | 259.03 | -25.10 | 948 / 984 |
| 0 1 1 1 1 | 133.98 | 125.15 | 259.13 | -25.20 | 975 / 975 |
| 0 1 0 1 1 | 135.28 | 126.40 | 261.68 | -27.75 | 933 / 918 |
| 0 1 1 0 1 | 135.28 | 126.40 | 261.68 | -27.75 | 933 / 918 |
| 0 1 0 1 0 | 135.43 | 126.40 | 261.83 | -27.90 | 927 / 909 |
| 0 1 1 0 0 | 135.43 | 126.40 | 261.83 | -27.90 | 927 / 909 |
| 1 1 1 1 1 | 141.08 | 121.60 | 262.68 | -28.75 | 990 / 1362 |
| 0 1 0 0 1 | 137.28 | 127.55 | 264.83 | -30.90 | 930 / 936 |
| 1 1 0 1 1 | 142.58 | 122.45 | 265.03 | -31.10 | 1353 / 1332 |
| 1 1 1 0 1 | 142.58 | 122.45 | 265.03 | -31.10 | 1353 / 1332 |
| 0 1 0 0 0 | 137.53 | 127.80 | 265.33 | -31.40 | 948 / 945 |
| 1 0 0 0 1 | 144.53 | 136.95 | 281.48 | -47.55 | 1626 / 1596 |

Paired effect of each part: for every pair of combinations that differ only in that part (tier 0 -> 1) and where **both** laps are clean (<= 100 skid and <= 400 off-road frames in total), the change in total time (negative = faster):

| part | clean pairs | mean change (s) | lap 1 (s) | lap 2 (s) | min..max (s) |
|---|---|---|---|---|---|
| engine | 2 | -4.40 | -3.50 | -0.90 | -4.40 .. -4.40 |
| frame | 0 | no clean pair | | | |
| muffler | 4 | -1.58 | -0.99 | -0.59 | -2.15 .. -1.00 |
| oil | 4 | -1.58 | -0.99 | -0.59 | -2.15 .. -1.00 |
| brake | 4 | +0.02 | -0.04 | +0.06 | -0.20 .. +0.25 |

## What the numbers say

* **Oil and muffler are interchangeable.** Their rows are identical (232.93 s each), as expected from doc 02/08: both just add `(oil + muffler) / 4` to the acceleration multiplier. One of them is worth **-1.0 s over two laps** at stock; both together **-3.15 s** (230.78 s, E F M O B = 0 0 1 1 0). The gain is mostly lap 1 (the standing start, -0.4 to -1.0 s) and about -0.6 s on a flying lap 2, from regaining speed after the corners.
* **Engine 0 -> 1** is the biggest clean gain: **-4.4 s over two laps (-3.5 s on the standing-start lap, -0.9 s on the flying lap)**, measured in the two pairs where both runs are clean (E1 with oil 1 or muffler 1, 228.53 s against 232.93 s). The acceleration term is `engine {3,4,6,6,8,8}` so tier 1 is +33 %.
* **Brake 0 -> 1 is worth about nothing (+-0.2 s, noise).** The autopilot plans its braking with fixed constants (0.95 speed/frame) and never uses the stronger brake, so this number is what the *current controller* gets, not the car's potential. Needs a controller change (or a measurement of the real brake tier effect, listed as open in doc 08) before it means anything.
* **Frame 1: no usable result.** All 16 runs with frame 1 crash at T13 (some also at T6) (the bike enters T13 already at lateral 328, off the road, then skids to a halt); the stock plan is just marginal there. The plan needs retuning for frame 1 before the frame tier can be compared.
* **Engine 1 with frame 0 crashes at T6 in 6 of 8 runs** (the two clean ones are E1 with oil 1 or muffler 1), again the marginal T5/T6 pair (see the lap 2 T6 crash investigation: T6 has no lateral margin, any change in entry speed flips it). Engine 1 combined with oil 1 or muffler 1 happens to land clean, which shows how chaotic this is and why the paired table uses a clean-only filter.

## Caveats and next steps

* Only 10 of the 32 runs are clean (<= 100 skid, <= 400 off-road frames over both laps), so the paired table is built from few pairs. Frame has none.
* Next: **retune the plan per tier combination** (a short `tools/plansearch.py` per combination, or at least the marginal curves T5/T6/T13) and re-run; add track 2 and track 3 and the other tires once their plans are tuned.
* The brake tier needs a controller that actually brakes harder, and the frame tier needs a check of what it changes in the handling (it moves the line enough to flip T13).
* Feed the clean paired gains (engine 1 about -2.2 s per lap, oil or muffler about -0.8 s per lap) into the route planner (doc 08) once re-measured with tuned plans.
