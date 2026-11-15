# Curve physics: push, steering, tires (Original mode, emulator-measured)

Scripts: `scripts/pushprobe.lua`, `curvebuf.lua`, `steerprobe.lua`, `braketest.lua`, `autolap.lua` (autopilot, work in progress); model: `tools/lapmodel.py`.

## Outward push in curves (`sub_00EA24`, called every frame in the race)
* `D = word[$FF0BA6] - word[$FF0CB8]` (turbo flag `$FF0510` set: `word[$FF0B8C]`), `Dc = D/64` truncated. `Dc` is about **410 / radius** (r 102 -> 4, 66 -> 6, 45 -> 9, 38 -> 11); the sign gives the direction (state 2 pushes toward +lat, state 3 toward -lat).
* Every 3rd frame: `lateral += 2 * (trunc(Dc*speed/110) + sign)`, skipped on about 10 % of the calls (buffer reads 0). Average per frame: `(2/3)*(floor(Dc*v/110)+1)`: 3.2 (r 102, v 120), 5.0 (r 102, v 200), 7.8 (r 66, v 200), 13.3 (r 38, v 200). Independent of the lateral position and of the tire tier.
## Steering
* Handlebar `$C73C` (`controls_model` `$9788`), centre `$80`, range `$3A..$C6`; table `$A038` (8 bytes per **frame** tier: return-to-centre rate, turn rate, reversal rate; frame tier >= 2 adds speed>>7): frame 0 = 2/3/6, 1 = 2/4/8, 2 = 2/4/9, 3 = 3/5/11, 4 = 4/7/16, 5 = 5/8/18. So the **frame tier sets how fast the handlebar ramps and reverses** (the "quick change of direction").
* `steer_out` `$FF063A` = -(hb-$80)*256/$8C, clamped +-127, **0 inside a dead zone hb in [$6C,$94]**: from centre the lock needs about 24 frames before anything happens and about 50 more to reach full lock (frame 0); releasing unwinds at about 1.2/frame.
* Lean `$38(a0)` follows `steer_out` at +-12 per call; `lateral += -2*lean*16/divisor` per call, calls every 3rd frame. Divisor = 128 + {32,20,8,-4,-16}[tire]. Measured full lock at speed 200: tier 0 about 8 lateral units/frame, tier 4 about 12. Speed <= 127 scales it by speed/128.
* Skid (|lat| > 300) removes steering control until the speed has collapsed to about 92.
## Speed
* Brake (A held): about -0.95 speed/frame (floor near 78); throttle released: about -0.26/frame; distance per frame = 0.001335 * speed.
* **Engine 0 stays at 241** with turbo (C) held in Original mode (measured 240 after 180 frames from 235; `$9D8E` requires engine tier >= 3); arcade mode gives turbo to every engine.
## Consequence for tires (`tools/lapmodel.py`, rival 0 track, 2 laps, engine 0)
Counter-steer authority G against the push sets a speed limit per curve (a drift budget of entry offset + outer margin before the skid line). Estimated race time: tire 0 247 s, tire 1 239 s (-8), tire 2 233 s (-14), tire 3 228 s (-19), tire 4 226 s (-21); oil 0 -> 1 saves 0.9-1.7 s. The tire gain is very sensitive to the drift-budget assumption (tire 0 -> 1 between -4.8 and -8.6 s) and has **not** been confirmed by an emulator run: the autopilot still skids too much to measure it.

## HUD speed conversion (km/h shown vs `$FF064A`)
* `sub_00BC38` ($BC38): `displayed = speed * $117 / $F0` (`mulu.w #$117` then `divu.w #$F0`), then `sub_00C144` converts it for the display (BCD) and the result is stored at `$FF055A` (`section_time+2`).
* So the raw speed ceiling `$F1` (241, the no-turbo cap) shows as **280 km/h**, and the turbo ceiling `$117` (279) as about 324 km/h. Ratio 279/240 = 1.1625.
* Measured (`scripts/topspeed.lua`, engine 0, lateral pinned to 0, speed unpinned, 3000 frames after the start): raw speed 241 and `$FF055A` = `$280` with and without turbo. The user's observation "engine 0 reaches 280" is correct; the earlier docs/notes quoting "241 km/h" are raw units (km/h on screen = raw * 1.1625, e.g. raw 206 -> 240 km/h).
* Engine 0 reaches the 241 cap slowly: raw 222 at k=1551 and 241 at k=1965 (about 33 s after the race start, oil 0).

## Autopilot sweep, track 3 (rival 2), engine 0, oil 0, frame 0 (`scripts/autolap.lua`, ENT=20 TOUT=180 SAFE=0.93)
| tire | lap 1 (s) | lap 2 (s) | 2 laps (s) | skid frames | brake frames |
|---|---|---|---|---|---|
| 0 | 161.3 | 142.2 | 303.4 | 774 | 417 |
| 1 | 154.3 | 147.8 | 302.1 | 1176 | 399 |
| 2 | 147.2 | 140.2 | 287.4 | 999 | 228 |
| 3 | 140.8 | 132.4 | 273.2 | 963 | 177 |
| 4 | 137.3 | 131.5 | 268.8 | 939 | 30 |
The autopilot still skids on 4-6 % of the frames, so single differences (tire 0 vs 1) are noise; the trend (tire 3-4 about 30 s faster than 0 over 2 laps, mostly less braking) is clear. Track 3 curves: r 44-47 (vlim about 147-159 raw at tire 0) and r 115 (never limiting).

## Outside-exit line attempt (`SHO_OUTX`, autolap.lua) - negative result
Target slides from +TIN (inside) to -OUTX (outside) over each curve; speed limit budget ENT+TOUT. Track 3, 18300 frames, lap-1 time / skid frames:
* tire 2, SAFE 0.93: OUTX 0 (inside line, TIN=ENT=200) 160.1 s / 2100; OUTX 80: 200.2 s / 2770; 150: 200.6 s / 2916; 220: 190.4 s / 3036. The earlier tuning (ENT=20, TOUT=180, SAFE 0.93) gave 147.2 s / 999 for tire 2.
* tires 0-4 with OUTX 250 (SAFE 0.95): lap 1 = 197.5, 205.7, 204.4, 218.2, 168.0 s with 2800-3600 skid frames; no run finished 2 laps.
With this controller the slide to the outside made things worse: the bike overshoots the 300 skid line on the way out and loses speed. This does not disprove the technique; it shows the tracking controller and speed-limit budget do not realise it. Needs a feed-forward design (steer-out timing) rather than position tracking.

## v3 autopilot: planned full-lock outside exit (`scripts/autolap2.lua`)
Per sharp curve the entry speed comes from a forward simulation (full counter-lock held, drift from `-U0` to at most `OUT`), throttle stays on through the curve, brakes only if the drift nears `OUT-10`; gentle curves (r 115, push < G) use the old position tracking. Calibration: the real push is about 8 % higher than the 0.92 duty I had (use `SHO_DUTY=1.0`), and the bike enters the curve near the centre (`SHO_U0=0`), not 200 inside. Settings `SHO_DUTY=1.0 SHO_OUT=285 SHO_U0=0`, track 3, engine 0, oil 0:
| tire | lap 1 (s) | lap 2 (s) | 2 laps (s) | skid frames | brake frames |
|---|---|---|---|---|---|
| 0 | 170.0 | - (not finished) | - | 339 | 4224 |
| 1 | 152.3 | 142.0 | 294.2 | 687 | 1607 |
| 2 | 146.2 | 135.6 | 281.7 | 678 | 1268 |
| 3 | 140.7 | 140.4 | 281.1 | 942 | 976 |
| 4 | 135.4 | 125.4 | 260.8 | 714 | 722 |
Versus the v2 inside-line autopilot (2 laps: tire 1 302.1, tire 2 287.4, tire 3 273.2, tire 4 268.8): v3 is 6-8 s faster at tires 1, 2 and 4 (skids 4-5 % to 3.7 %), slower at tire 3 (noise/skid), and tire 0 crawls (the entry-speed limit makes it brake constantly). Tuning is still rough; skids around the sharp curves (d about 1050, 1300-1650) remain.

## v3.1: inside-edge entry + early cross-over (autolap2.lua), lap 1 only, track 3, engine 0
Changes: every curve targets the inside edge (`SHO_INE` 265), repositioning starts `SHO_TPRE` frames before the curve with no push preload until the last `SHO_PL` frames, entry speed from the simulation with the *predicted* offset at the curve start, full lock only while clear of the inside edge, and early cross-over to the next curve's inside edge when the next curve turns the other way.
| tire | TPRE | lap 1 (s) | skid frames (to k=10300) |
|---|---|---|---|
| 0 | 60 | 149.8 | 495 |
| 0 | 120 | 148.4 | 563 |
| 2 | 60 | 143.1 | 1164 |
| 2 | 120 | 168.8 | 1380 |
(v3 without these changes: tire 0 170.0 s, tire 2 146.2 s; v2 inside-line: tire 0 161.3 s, tire 2 147.2 s.) Rough numbers; skids remain on the inside edge in sharp curves at low speed.

## Road edge, off-road vs skid, and v3.2 (autolap2.lua)
* `scripts/latshot.lua` (lateral pinned, screenshot): the bike's wheel reaches the road edge line at |lat| about 270-290 (skid flag only at 300). The video overlay shows OFF-ROAD above 270 and SKID separately; the autopilot counts `off_frames` (|lat| > `SHO_OFF`=270) separately from `skid_frames`.
* Handlebar address: `$FFC73C` (not `$FFC73E`, which is the throttle target).
* Timed press: pressing inward starts `frames_needed(...)` frames before the curve (model: dead zone 20 frames, then steer +1.83/frame, lateral speed G*steer/127), `SHO_MARG` shifts it (-8 best of -26..+30 tried).
* Braking-distance limit on the lateral speed: the handlebar unwinds only about 1.2/frame, so |vd| <= `SHO_BR`*sqrt(|err|) (0.35 best of 0.25/0.35/0.5). This removed almost all skids (36 frames vs 400-1100).
* Limits `SHO_INE`=240 (inside) / `SHO_OUT`=255 (outer drift), lock eased `SHO_REL`=20 frames before a sharp curve ends.
Track 3, tire 0, engine 0, lap 1: 150.6 s, skid 36 frames, off-road 526 frames (turn windows: only T7 36; the rest between turns). Per turn (`tools/turnstats.py`): T5/T6 still enter at lateral -10/-50 at 120-124 km/h (press starts too late because the bike brakes hard from 244), T7-T10 crawl at 100-130 km/h.

## v4 (`scripts/autolap3.lua`): braking-envelope press timing, opposite-curve lead; chain planner (offline) 
* Press timing: time to the curve integrated along the braking envelope (`time_to`), so a hard-braking approach (T4 exit -> T5) starts pressing earlier. `SHO_NOCHAIN=1 SHO_LEAD=40 SHO_REL=20 SHO_MARG=10 SHO_BR=0.35`, track 3, tire 0: lap 1 147.0 s, 36 skid frames, 1127 off-road frames (T8: 552, it enters at 160 km/h and drifts to 322). T5/T6 now enter at lateral -142/-180 at 142 km/h (was -10/-50 at 120), T9 exit 188 km/h (was 99). Tire 2: 139.1 s.
* `tools/chainsim.py`/`sim_chain`: chain planner (a run of contiguous curves, full lock, lock switched `LEAD` frames before an opposite curve). With edges 255/240 it finds no feasible policy through T7-T9 at any entry speed (even with 290/290 limits), i.e. the model is too strict for S-bends (lock switch timing / reversal model need work) - not used for control yet (`SHO_NOCHAIN` default path).

## v5: backward chain planner (`tools/chainplan2.py`) + `scripts/autolap4.lua`
Plans a chain A-B-C backwards: C first (inside edge, full lock, highest feasible entry speed), then B so it ends in the state C needs (lateral offset +-45, handlebar +-30, speed), then A likewise. Per curve it outputs entry speed, entry offset fraction `a` and the lock-switch lead (frames before the curve end; the lead window forces full lock in the next curve's direction, no inside-edge hold). Written to `scripts/plan_track3_t<tire>.lua`, followed by `autolap4.lua` (`SHO_PLAN=...`).
Tire 0 plan (km/h): T5/T6 enter 145, exit 213; T7 177 -> 75 (sacrificed), T8 75 -> 131, T9 131 -> 211; T10 280 -> 121, T11 122 -> 214. In the emulator (T7-T11): all five turns off-road 0 / skid 0, T9 exit 204 km/h, T7-T11 take 2520 frames (v4: 2784).
Using the plan only for T5..T11 (the T1-T4 plan misbehaves: T2 reaches |lat| 366, T3's lead of 300 frames removes the inside-edge hold) with `SHO_NOCHAIN=1 SHO_MARG=0`: lap 1 = 145.8 s (v4 147.0 s), skid 90, off-road 734 frames (T1 27, T2 51, T10 66, the rest between turns). Video `out/video/tire0_lap1_v5.mp4`.

## v5.1: T4 sacrificed, T1-T3 chain, leads <= 140 (plans `scripts/plan_track3_t<tire>.lua`)
Tire 0, plan for T1-T3, T5, T6, T7-T9, T10-T11 (T4 unplanned): lap 1 = 145.0 s, skid 90, off-road 738 frames (video `out/video/tire0_lap1_v6.mp4`). T3 plan: enter 173 km/h, exit 214 (emulator: 166 -> 206).
Tire sweep (plans: tire 0 full, tire 1 full minus T7-T9 (infeasible), tires 2-4 only T5/T6; `SHO_NOCHAIN=1 SHO_MARG=0`), lap 1 / lap 2 (s): tire 0 145.0 / 150.2, tire 1 158.6 / 133.7, tire 2 138.0 / 156.9, tire 3 159.4 / (not finished), tire 4 126.0 / 169.0. The autopilot is tuned on tire 0; for tires >= 1 the planner finds no feasible chain (inward overshoot of the hold with the larger counter-steer authority) or nonsense entries (tire 2 T1 94 km/h), so these numbers are NOT a reliable tire comparison; lap 2 is much worse than lap 1 for most tires (second-lap start state differs, skids).

## v8: gentle curves, per-turn plan fields, no backmarkers (track 3, tire 0, lap 1 = 140.4 s)
* `SHO_NOBOTS=1` clears the 5 bot slots every frame (traffic switched off until it is mapped out).
* Plan fields `marg` (extra frames of early turn-in), `rel` (early release of the lock), per curve (`scripts/plan_track3_v8.lua`).
* Gentle curves (radius >= `SHO_GENT`=90; push 6 < authority 8) are steered proportionally instead of full lock/stop/full lock, and when the next piece is straight the feed-forward push and the inside target fade over `SHO_GFADE`=40 frames before the end. Before this the steering was still at -88 when the curve ended and the bike slid from lateral 258 to 314 (skid) on the following straight (T4); T1 and T10 off-road also disappeared and T10 exit rose 117 -> 140 km/h.
* Entry speeds: T5/T6 raised 125 -> 140 (raw), T11 105 -> 125; 146/135 or more overshoots (skid). Lap 145.0 -> 140.4 s.

## v9: automatic plan search (tools/plansearch.py, tools/mkplan.py, tools/overnight.sh)
Per tire the per-curve plan fields (entry speed `vt`, lock-switch `lead`, early press `marg`, early release `rel`) are tuned by a random coordinate search: each round runs 8 headless laps from the track savestate (race1/2/3 = rival 0/1/2, `SHO_NOBOTS=1`) and keeps the best change. Score = lap time + 0.03 s per skid frame + 0.006 s per off-road frame (laps that do not finish are scored by progress). Initial plans for tracks 1 and 2 come from `mkplan.py`: highest speed whose curve push stays within the tire's full-lock authority. 30 rounds per search, 8 h overnight run. Result (lap-1 time s, skid frames, off-road frames):

| tire | track 3 | track 1 (2 phases) | track 2 (2 phases) |
|---|---|---|---|
| 0 | 138.3 (0, 9) | 137.4 (603, 633) | 145.6 (306, 495) |
| 1 | 136.1 (0, 21) | 142.4 (729, 909) | 141.1 (240, 483) |
| 2 | 133.9 (105, 117) | 139.1 (867, 1035) | 138.8 (282, 576) |
| 3 | 127.0 (117, 156) | 132.9 (816, 960) | 128.8 (192, 276) |
| 4 | 125.6 (369, 1803) | 120.9 (615, 696) | 128.1 (219, 495) |

Caveat: only track 3 tires 0-1 are clean (no skid). All other cells still skid for hundreds of frames, so their lap times are optimistic and the tire comparison there is not trustworthy. The plan fields cannot fix that: the controller itself (aggressive pre-positioning with stronger tires, tracks 1/2 curve shapes) needs work.
