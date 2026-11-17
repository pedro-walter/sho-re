# 12 - Exact steering / speed model and the v6 autopilot (`scripts/autolap6.lua`)

Goal of this round: stop tuning "when to start counter-steering" per turn by hand. The lateral chain of the game is deterministic, so it can be simulated
exactly and the start time of every move can be *computed*. The new autopilot (`autolap6`) takes only two numbers per curve: the entry speed `vt` and the entry
position `a`; the steering and braking timing is calculated.

Files: `scripts/model6.lua` (exact model + planner, no emulator access), `scripts/autolap6.lua` (controller), `tools/steermodel.py` (model validation against a
`SHO_MLOG` log), `tools/roadprofile.py` + `data/roadprofile_track{1,2,3}.lua` (road push per lap distance), `tools/plansearch6.py` (search over `vt`/`a`),
`tools/mktune6.py`, `tune/v6/`. Headless tests: `scripts/model6test.lua` (moves from rest, all tire/frame tiers), `model6hold.lua`, `model6corr.lua`,
`vtcheck.lua`, `vtcheck2.lua`, `dbgplan.lua`.

## 1. Time structure

* The game logic runs once per **tick = 3 frames**. Inside a tick the order is: lateral model (`$A44C`, usually 1 frame after the previous tick), then the handlebar /
  throttle / brake model (`$9788`, frame phase 2 mod 3 in the logs), then the road push (`$EA24`) in the same frame. The phase relative to the frame counter can jitter by
  one frame (about 10 % of the lateral calls land one frame earlier); the model works per tick, not per frame.
* **Pad lag**: the pad state used by a tick is the one set at least 3 frames earlier. In practice: read the state right after the handlebar write of tick n-1 and set the
  pad then; it is used by tick n. (Fit: lag 3 gives 0 mismatches, lag 2 and 4 do not, on `scripts/steerlog.lua` runs with presses starting at every frame phase.)
* The controller detects the tick with a memory tap on the handlebar word `$FFC73C` (written once per tick).

## 2. Lateral chain (validated: 0 mismatches over 2300 ticks of a real lap, 3665 ticks of a v6 lap, and all tier combinations tested)

1. **Handlebar** `hb` (`$FFC73C`, centre `$80`, range `$3A..$C6`). Rates from table `$A038` for frame tier F: `(d1, d2, d3) = (return, turn, reversal)` =
   F0 2/3/6, F1 2/4/8, F2 2/4/9, F3 3/5/11, F4 4/7/16, F5 5/8/18; for F >= 2 add `speed >> 7` to all three.
   Left pad (bit 2, wins over right): `hb < $80: hb += d3` else `hb += d2` (cap `$C6`). Right pad: `hb >= $80: hb -= d3` else `hb -= d2` (floor `$3A`).
   No pad: move towards `$80` by `d1` (no clamp, can overshoot by one). *The reversal rate is also used at exactly `$80` for the right pad.*
2. **steer_out** `so` (`$FF063A`): `d = clamp(hb, $3A, $C6)`; `d = $80` if `$6C <= d <= $94` (dead zone); `so = -clamp(trunc((d-$80)*256/$8C), +-127)`.
   Leaving the dead zone makes `|so|` jump from 0 to 38 (`hb` 107 / 149).
3. **Lean** (`$FFC978`, i.e. `$38(a0)` of the player object `$FFC940`): `lean += clamp(so - lean, -12, +12)` once per tick. (After a crash that word holds garbage: the
   controller replaces out-of-range values by `so`.)
4. **Lateral** (`lateral_pos $FF0614`): `d = lean; if not skid and speed <= 127: d = (d*speed) >> 7` (arithmetic shift!); `lat += 2 * -trunc(16*d / (128 + adj[tire]))`,
   `adj = {32, 20, 8, -4, -16}`; clamp at +-500; skid flag (`$FF066A`) = `|lat| > 300` set right after.
5. **Road push** (`$EA24`, every tick): `Dc = trunc(D/64)`, `D = word[$FF0BA6] - word[$FF0CB8]` (turbo: `$FF0B8C`); if `Dc != 0`:
   `q = trunc(Dc*speed/110)`; `lat += 2*(q + (q >= 0 ? 1 : -1))`, **skipped (not clamped)** if the result would exceed +-500. Note the +1 also when `q = 0`.
   Maximum counter-steer per tick at full lean: `2*trunc(16*127/160) = 25` for tire 0 (33 / 36 for tires 2 / 4, speed above 127; below 127 scaled by speed/128).

## 3. The push profile `Dc(d)` is a function of the lap distance - but the *logged* `D` is not usable

The buffers `$FF0BA6/$FF0CB8` are rewritten while the frame runs; read at the end of a frame `D` is 0 in about half of the ticks that actually pushed
(561 of 1207 in one lap). So the profile is rebuilt from the pushes the game really applied (`$EA7A` write deltas) and the speeds: for every lap distance the integer
`Dc` that explains most observations (no push event = 0). Checked at the T4/T5 boundary of track 1 at speeds 126 and 197: the sign flips at d = 598-599 in both, so the profile
depends on the distance and not on the speed. The drawn push does *not* coincide with the physical curve list: it ramps in over about 5 units before the curve start and
flips at the boundary of two curves 1-2 units early.
(An earlier version of the builder dropped ticks with the skid flag set and back-filled the holes with the previous value; that put a wrong -6 over d = 600-611 of track 1
and made the S-bend T4 -> T5 fail. Skid ticks are fine to use: the push does not depend on the skid flag.)

## 4. Speed model (`speed_model $9B40`) - exact enough that the simulated speed equals the real one to the digit over 40-tick moves

* Throttle position `$FFC738`: +20 per tick with B held (max 168), -15 per tick released (min 1). Target speed `= 279 * min(127, trunc((pos-1)*160/168)) / 127`.
  **After releasing the throttle the bike keeps accelerating for about 8 ticks** until the falling target gets below the speed.
* Acceleration (speed < target, or speed < 80): `mult*(279 - v)/1024` per tick; `mult = {3,4,6,6,8,8}[engine] + (oil + muffler)/4`. Speed above target: drag
  `0.775` per tick (engine 0-1), `1.55` (engine 2-3), `3.1` (engine 4-5). Speed is capped at 241 without turbo.
* **Brake**: `$FFC73A` (`brake_pos`) rises by `{2,4,7,12,16}[brake tier]` per tick while A is held (max 197), reset to 1 when released. The braking force is
  `1.55 * n` per tick on top of the drag, with `n = 0,1,2,3,4` for `f = (pos-1)*256/197` below `1 / 48 / 112 / 192`. **With brake tier 0 the force needs 18 ticks to
  reach n = 2 and 74 ticks to reach n = 4**, so a short brake is much weaker than the 0.95 speed/frame average that had been used (this is why the old autopilots
  under-braked the first time).
* Distance per tick: `trunc(269*(r + trunc(side/40))/r) * speed / 65536` in curves (`side` = lateral offset towards the inside), `269*speed/65536` on straights
  (0.0041*v per tick).

## 5. The v6 autopilot

Plan: `[curve start] = { vt = entry speed (raw; nil = automatic), a = entry position (fraction of 240 towards the inside, 1 = inside edge) }`.
Nothing else. All timing comes from `model6.lua`:

* **Planned move** (`best_plan`): to go from the current line to the next curve's entry line `T` the controller simulates "press towards `T` for `a` ticks, then drive the handlebar
  to its steady level (the level that balances the road push; neutral on a straight; the level of the *next* push once the entry is close enough that the reversal must
  start now), then hold". The landing error at the entry grows monotonically with `a` until the bike reaches the wall, so `a` is found with a coarse scan plus bisection;
  three steering caps (127 / 70 / 45) give finer resolution. Result: error at the entry and the tick when the bike is within 10 units for good (`tarr`).
  Offline (`model6test.lua`, 15 tire/frame combinations, v 120/200, moves of 60..480 units): mean |final error| 4.0, max 12, and the predicted arrival tick equals the simulated
  one within +-1 tick (e.g. 14/14, 35/35, 41/41).
* **When to start** (the "formula"): each tick the plan from now is computed; the move starts when `tarr + 1 >= entry tick` (waiting one more tick would arrive late) and
  the plan does not overshoot by more than 12 units (a plan that overshoots without any steering means "wait"); a plan that cannot reach the line (error < -40) starts at once.
* **Hold** (`policy_pred`): every tick the command (left / none / right, held for H = 9 ticks, H = 15 when a stronger push is coming within 22 ticks) whose *exactly predicted*
  lateral position is closest to the line. Median deviation 12-14 units from a relaxed handlebar into a typical curve push (the older proportional law: 32).
  Errors above 30 units are corrected with a planned move instead.
* **Speed**: brake at the latest tick such that the exact brake model arrives at `vt` at the curve start (`brake_dist`, with the real `brake_pos`); throttle off once within
  the braking distance + 12 units.
* **Automatic `vt`** (omit the field): largest entry speed at which the simulated bike, arriving on its line with a relaxed handlebar 25 ticks before the curve, stays
  within |lat| <= 290 through the curve. It is optimistic for the sharpest hairpins (push above the tire's counter-steer authority, e.g. radius 38): give those a number.

## 6. What the simulation reproduces in the emulator

Per move the controller can log (`SHO_PCHK=1`) real vs predicted lateral position, speed and distance tick by tick. After the speed model was exact: lateral error 0-4 units
over 40 ticks, speed identical, distance within 0.3 units.

## 7. Results (`tools/plansearch6.py`: random coordinate search over `vt` and `a` only; 8 laps per round, tire/oil as listed)

| track, tire (oil 1, other parts 0) | v6 lap 1 | skid / off-road frames | hand-tuned autolap5 plan (lap 1) |
|---|---|---|---|
| 1, tire 0 | **117.63 s** (lap 2: 108.85 s) | 48 / 195 | 118.03 s (lap 2: 108.40 s) |
| 1, tire 1 | **114.93 s** (lap 2 not tuned: 121.10 s, skids in T2/T3 at the flying start) | 39 / 93 | 115.13 s |
| 2, tire 1 | 138.58 s | 126 / 144+ (T7, the hairpin S-bend T7-T8) | - (the old plan crashed at T2/T3 with the new oil setting) |
| 2, tire 2 | 142.48 s | 504 / 573 (T7 again; not converged: 22 rounds) | - |

Tune files: `tune/v6/track1_t0.lua`, `track1_t1.lua`, `track2_t1.lua`, `track2_t2.lua` (run with `tools/lap.sh tune/v6/track1_t0.lua NAME`; `stop_turn` / `start_after_turn` work as before).
The search plateaued after about 20 rounds on track 1; the plans have only 2 numbers per curve (15 curves = 30 numbers) against 5 per curve before. With conservative entry speeds
(`vt = 130` everywhere) the whole lap of track 1 is clean and the entry positions are within +-20 units for 11 of 15 curves (errors -18 -6 2 -18 26 -16 0 -16 52 -70 2 42 -18 4 -2).

## 8. Open points / limits

* Pushes above the counter-steer authority (sharp curve at high speed) cannot be held by any steering; the plan has to lower `vt` or accept the outward drift.
* Weak pushes (|so| needed < 38) cannot be produced continuously because of the dead zone; the hold law then stays neutral and corrections are done by planned moves
  (ripple +-10..40 units on tire 4 in gentle curves).
* The brake model does not include the effect of grass / off-road (the real bike loses speed beyond |lat| ~ 270).
