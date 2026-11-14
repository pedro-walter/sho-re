# Original mode – upgrade order for a speedrun (win every race, no crashes)

Tools: `scripts/accel.lua` (launch / turbo-ramp measurements), `tools/runplan.py` (race-time model and purchase search; `python3 -I tools/runplan.py table|plan`).

## Speed model (`speed_model` $9B40, emulator-verified)
* Runs every 3rd frame (20/s at 60 Hz; measured 0.267 distance units/frame at speed 200 = 0.325 x 269*200/65536).
* `s += mult*(279-s)/1024`, `mult = engine {3,4,6,6,8,8} + (oil tier + muffler tier)/4`. Five launch readings matched within 1 km/h (`accel.lua`).
* Top speed: **241 for engine tiers 0-2** (`$9DF6` pulls anything above $F0 back to $F1). **Tiers 3-5 + C held: 279** (`$9DD6`: +1/+3/+5 per call above $F0, cap $117). Measured ramp 241 -> 279: tier 3 about 90 frames, tier 4 36, tier 5 24.
* Speed only drops for skid (`$FF066A`), braking (`$FF065A`/`$FF0642`) and crash/bump flags in the code read; steering itself has no term. So without skids/crashes the car sits at its top speed and acceleration only matters for the start.
* Lap = 2048 units, distance/call = 269*s/65536: 103.5 s per lap at 241, 89.4 s at 279 (inside-line gain ignored; it scales every config alike).

## Value of each step (seconds per race, 2-lap / 6-lap race)
| change | 2 laps | 6 laps |
|---|---|---|
| all stock (engine 0) -> engine 2 | -6 | -6 |
| engine 2 -> engine 3 (turbo) | **-26** | **-83** |
| engine 3 -> 4 (faster start and ramp) | -2 | -2 |
| oil 0 -> 1 | -1 | -1 |
| oil 3 + muffler 3 (on engine 3) | -1.4 | -1.5 |
| engine 4 -> 5 | -0.1 | -0.1 |

## Search result (35 races, 125 laps, winnings at the table payouts, engine/oil health >= 3 at race start)
| plan | race time |
|---|---|
| no upgrades (only keep engine/oil alive) | 222.5 min |
| acceleration only (engine <= 2, oil) | 219.2 min |
| engine 3 as soon as affordable (+ upkeep only) | 197.6 min |
| searched plan: also engine 1 early, oil 1/2, engine 4 from the Distributor sponsor | 196.4 min |

Engine 3 ($32,000) is first affordable before race 13 (after the 2nd Appliance win: 6k + 11k + 2 x 10k = 37k). The slack above $32k pays for engine 1 and oil 1 earlier. A mechanic never pays off in the model. The engine is replaced about every 7 races (wear 2/race, mechanic 0 = coin-flip repair), oil about every 5.

## Tires and brakes (tools/runplan.py plan3)
Model: tires wear 4/race, brakes 1/race (engine 2, oil 3); a part is rebought (same tier) only when its health would drop below 3.
Tire tier is a *requirement* here (not a time bonus, no measured per-tier lap-time loss yet): tier >= 3 (or 4) from a given race on.
Curve physics (curvedrift.lua): the road adds a fixed outward push (~4.8 lateral units/frame at 200, any radius); tire tier only sets the
counter-steer authority (net recovery ~+2/frame at tier 0, ~+5.6 at tier 4). Skid threshold |lat| > 300, then speed collapses to ~92.

| constraint | race time | notes |
|---|---|---|
| tires >= 3 from race 11 (rival 2), brakes any | 197.3 min | first T3 ($6k) before race 11 |
| tires >= 3 from race 11, brakes >= 2 | 197.5 min | B2 ($6k) before race 11, rebuy ~ race 24 |
| tires >= 4 from race 16 (rival 3) | 196.7 min | T4 ($24k) first affordable before race 16 |
| tires >= 4 from race 21 | 196.7 min | |
| tires >= 4 from race 16, engine 5 and oil 3 allowed | 196.5 min | E5 ($8.2M) only before race 35: useless |

Tier-4 tires cannot be required from race 11 (cumulative winnings ~ $17k vs $24k). Tires >= 3 cost ~$6k every 3 races (about $60k over the run);
upkeep delays engine 3 ($32k) to before race 14 instead of 13. The totals differ by < 1 minute: the whole game is ~197 min of racing whatever you buy after engine 3.

## Purchase order, FIRST VERSION (superseded by the safe-margin plan below; label fix: `M` in the planner is the *mechanic*, not the muffler; tires >= 4 from race 16 variant; race = 5 per rival, 35 total)
Before race: 2 oil1 | 5 tire0 | 6 engine1 | 7 oil1 | 9 tire0 | 10 mechanic1 | 12 oil1 | 13 engine3 + tire0 | 14 oil2 | 16 tire4 |
17 oil3 | 20 engine3 + tire4 | 23 oil3 | 24 tire4 | 25 engine4 | 28 tire4 | 29 oil3 | 32 engine4 + tire4 | 35 engine5 + oil3.
(Same-tier entries are rebuys because health fell below 3. This run bought no brakes: with mechanic 1 the expected brake health stays above 3, and in practice you would rebuy tier-0 brakes ($400) whenever they reach 3.)
Open: measured time loss per tire tier in curves, brake tier effect, frame tier, mechanic 'race' interpretation (stage vs rival).

## Safe margins, shop visits, frame, mechanics (tools/plan4.py, tools/reliab.py)

### Part life, exact (tools/reliab.py)
Health h after a buy = 15. After every race: h = max(0, h - wear); then one shared roll: +1 with probability p (mechanic 0..3 = 1/2, 3/4, 7/8, 15/16), else -1 (if h > 0).
A part at health 0 is "about to fail" (engine/oil/tire fail under stress, see doc 02 §4). Races you can use a part after a buy with P(health >= 1 every race) >= 99%:

| part (wear) | mechanic 0 | mechanic 1 | mechanic 2 | mechanic 3 |
|---|---|---|---|---|
| tire (4) | 3 | 3 | 4 | 4 |
| oil (3) | 4 | 5 | 6 | 6 |
| engine (2) | 5 | 7 | 9 | 11 |
| brake / muffler (1) | 9 | 16 | 32 | 40 |

The earlier plans (expected health >= 3 at race start) let a tire run 4 races, which has a 12.5% chance of a 0-health tire on the 4th race with mechanic 0 (1.6% with mechanic 1). plan4 uses margins (expected health at race start) engine 6, oil 5, tire 5, brake 6, muffler 4, which reproduces the 99% lives above.

### plan4 model
Same speed model; muffler optional (+ (oil+muffler)/4 multiplier, verified by accel.lua); mechanic 0..3; frame tier 2 ($8,000) required from rival 2 (race 11) on (frame never wears without crashes); tires >= 3 from rival 2; a shop visit costs 5 s. Two visit modes: *always* (you visit before every race from race 5 on, constant 31 x 5 s, extra visits only cost in races 1-4) and *buy-only* (every race with a purchase costs 5 s; needs the schedule memorised). Search = dominance-pruned DP (checked identical to the exact Pareto DP on the baseline).

### Results (35 races won, minutes of race time incl. the 5 s visits listed above)
| scenario | min | notes |
|---|---|---|
| baseline: safe margins, tires>=3 + frame 2 from rival 2, mechanics 0-3, engines 0,1,3,4 | 198.40 | engine 3 before race 16 |
| same, **without** the tire and frame requirements | 196.73 | engine 3 before race 13 (the earliest possible: races 11/12 infeasible) |
| no frame requirement (tires >= 3 kept) | 197.26 | frame 2 costs 1.14 min |
| no tire requirement (frame 2 kept) | 197.28 | tires >= 3 cost 1.12 min |
| tires >= 3 from rival 2, then tier 4 from rival 3 | 199.84 | tier 4 costs 1.44 min more |
| tires 4 from rival 3, no tier-3 stage | 199.45 | |
| old margins (health >= 3 for all) | 198.08 | the safe margins cost 0.32 min |
| muffler never | 198.46 | muffler 1 before race 16: -0.06 min; muffler 2: -0.12 min |
| oil only tier 0 / 0-1 / 0-2 / 0-3 | 198.61 / 198.40 / 198.34 / 198.30 | oil 1 is worth 0.21 min over the whole run |
| engine 5 allowed | 198.40 | never bought |

Break-even of your requirements: the tire >= 3 requirement costs ~66 s and the frame 2 requirement ~68 s over the 25 races from rival 2 on, i.e. each must save **more than ~2.7 s per race** in the curves to pay for itself (tier 4 over tier 3: > ~3.5 s per race over the 20 races from rival 3).

### Engines per track (raw model, 5 races; no purchases, 0 s visits)
| track (laps) | engine 0 | engine 1 | engine 2 | engine 3 |
|---|---|---|---|---|
| 1 and 2 (2 laps) | 1093.5 s | 1079.0 (-14.5) | 1064.2 (-29.3) | 931.2 (-162.3) |
| 3 and 4 (3 laps) | 1611.2 s | 1596.5 (-14.7) | 1582.0 (-29.2) | 1378.5 (-232.7) |

Engine 1 and 2 save 2.9 s per 2-lap race and ~3 s per 3-lap race each; engine 3 saves 26.6 s per 2-lap race. With money (relaxed run: no tire/frame requirement, 196.73 min baseline):
* engine 1 forced before race 3: 197.12 (+0.39 min), before race 5: 197.06 (+0.33): its $2,000 delays engine 3 by about a race. **Stay at engine 0 on track 1.**
* engine 1 forced from race 6: 197.14 (+0.41), engine 2 from race 8: 197.21 (+0.48); engine 2 from race 6 is infeasible. **Engine 1/2 on track 2 lose too.**
* track 3: engine 3 first becomes affordable before race 13 (after the second rival-2 win). Engine 3 forced before race 11 or 12 is infeasible; engines 1/2 held through rival 2 (engine 3 postponed to rival 3): 198.42 (+1.69 min = 101 s). Engine 1 alone (cheap, before race 12 in the baseline) is worth about 5 s over the whole run (engine sets 0,3,4: 198.48 vs 0,1,3,4: 198.40); engine 2 is worth nothing (0,2,3,4: 198.48).
* with the tire 3 + frame 2 requirements, the money at the start of rival 2 ($8.4k after rival 1) is all spent on T3 ($6k) and the frame ($8k); any engine purchase before race 11 is infeasible, engine 3 moves to before race 16 and costs 1.67 min.

### Mechanics (always-visit mode / buy-only mode)
| allowed mechanics | min (visit every race) | min (buy-only) | visits (buy-only) | money left at the end |
|---|---|---|---|---|
| 0 only | 198.42 | 200.09 | 20 | $11.70M |
| 0,1 ($1k) | 198.42 | 199.83 | 17 | $12.21M |
| 0,2 ($2k) | 198.40 | 199.62 | 14 | $12.73M |
| 0,3 ($13k) | 198.42 | 199.76 | 16 | $12.20M |
| 0,1,2 / 0,1,2,3 | 198.40 | 199.54 | 14 | $12.25M |

A mechanic does not change race time by more than a second. Its value is fewer shop visits: with buy-only visits mechanic 1 (race 4) + mechanic 2 (race 16, $2k) saves 0.55 min (6 visits x 5 s + a little money). Mechanic 3 ($13k) is never chosen when tier 1/2 are available; tier 2 alone is almost as good as 1+2 ($2k for 14 visits). Buy mechanic 1 as soon as $1k is spare (race 4) and mechanic 2 around race 12-16.

### Purchase order, 14 shop visits (buy-only, tires >= 3 from rival 2; 199.54 min with the visit time)
Race = before that race (5 races per rival). Same-tier entries are rebuys.
| before race | buy |
|---|---|
| 4 | mechanic 1 ($1k), tires 0 |
| 5 | oil 1 |
| 7 | engine 0 (rebuy), tires 0 |
| 10 | oil 1, tires 3 |
| 11 | frame 2 |
| 13 | engine 1, tires 3 |
| 15 | engine 3 ($32k), oil 1 |
| 16 | muffler 1, mechanic 2, tires 3 |
| 20 | oil 1, tires 3 |
| 24 | engine 4 ($512k), tires 3 |
| 26 | oil 1 |
| 28 | tires 3 |
| 32 | oil 1, tires 3 |
| 34 | engine 4 (rebuy) |

### Variant: tier-4 tires from rival 3, buy-only (200.87 min incl. visits)
4 mechanic 1 + oil 1 + tires 0 | 7 engine 0 + tires 0 | 9 oil 1 + tires 3 | 11 frame 2 | 12 engine 1 + muffler 1 + tires 3 | 14 oil 1 + mechanic 2 | 16 tires 4 ($24k) | 17 engine 3 | 20 oil 1 + tires 4 | 24 tires 4 | 26 engine 4 + oil 1 | 28 tires 4 | 32 oil 1 + tires 4.
(The 'visit every race' variants are in the plan4 outputs; the totals above add 31 x 5 s = 155 s to those.)

### Still open
No measured time loss per tire/frame tier in curves (only break-even values above); brake tier effect; the engine-2 forced-from-race-6 case and a few others are infeasible, not slow.
