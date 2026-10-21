# Original mode – structure and rules (verified from the code and by experiments)

Confidence tags: **[code]** read in the disassembly, **[exp]** confirmed by a headless experiment (script named), **[?]** inferred.

## 1. Program structure

`game_mode` ($FFC704, value = 4 × index) selects the routine run by the main loop (table of `bra.w` at $6CF2).
Each routine is a state machine entered every pass; its first instruction is `bset #0,$FFC705` – the first call (bit was clear)
does the screen set-up, later calls run the logic. A mode changes by clearing `vblank_mode` and writing a new `game_mode`.

| value | idx | routine | what | seen by forcing the mode (`scripts/forcemode.lua`) |
|---|---|---|---|---|
| $00 | 0 | $7242 | boot logo -> title (loads Mode data, plays jingle) | title |
| $04 | 1 | $7492 | title menu: NEW GAME/PASSWORD, ARCADE/ORIGINAL | yes |
| $08 | 2 | $7B16 | class select (world map: Beginner 6 / Junior 10 / Senior 14 / Expert 18 stages) – arcade | yes |
| $0C | 3 | $7DAC | music select (SPRINTER / WINNING RUN / HARD ROAD) | yes |
| $10 | 4 | $86C6 | race set-up / countdown (both modes), then sets $18 | yes (arcade HUD) |
| $14 | 5 | $8968 | arcade race result / "PUSH START BUTTON" continue | needs state |
| $18 | 6 | $8AE4 | **the race loop** (both modes). `$FFC720` = next mode requested by the race code | needs state |
| $1C | 7 | $B8A2 | race finished scene; Original mode copies the times, sets `$FFB655` bit 1, goes to $24 (or to $34 when the game is won/over) | needs state |
| $20 | 8 | $D968 | ? (reached from $8968: arcade end/ranking?) | – |
| $24 | 9 | $52A4 | **Original mode shop menu**: COMMAND = PARTS / MECHANIC / RACE / END, rival + sponsor + money + win/loss panel | yes |
| $28 | 10 | $614E | **parts shop** | yes |
| $2C | 11 | $4954 | password entry | yes |
| $30 | 12 | $6818 | options (difficulty, time adjust, message language, sound test) | yes |
| $34 | 13 | $E1D0 | ending / game over screens (reached from $1C) [?] | – |

VBlank (`$6D2A`) dispatches on `vblank_mode` ($FFC722) and increments `vblank_ticks`; HBlank is a RAM stub at $FF05D2 (the road is drawn per scanline).
`$FFC82C` is the **Original-mode flag** (0 = arcade): the same race code branches on it everywhere.
Joypad: `$FFC706` held / `$FFC707` newly pressed, bits 0 up, 1 down, 2 left, 3 right, 4 B, 5 C, 6 A, 7 Start [code].

### Original mode flow
```
title (mode 1) --ORIGINAL--> $24 shop (new game clears $FFB600..$FFBFF, defaults at $7FD8: all parts health 15)
  shop: PARTS -> $28 | MECHANIC -> sub-screen (Left/Right choose, C hire, B leave) | RACE -> $0C music -> $10 -> $18 race -> $1C -> $24 | END -> password
```
After a race: `$1C` stores your time ($FFC832 -> $FFB63C) and the rival's ($FFC83A -> $FFB640), sets `$FFB655` bit 1 and returns to $24;
the shop entry code ($5AD6...$5FCE) then (a) pays the sponsor, (b) updates win/loss counts, (c) wears/repairs the parts, (d) picks the mechanic phrase.

## 2. Original-mode save structure ($FFB600-$FFB67F)  – this is also what the password stores

| addr | meaning |
|---|---|
| $B602 | shop command being run (0 = menu, 4 parts, 8 mechanic, $C race, $10 end) |
| $B604 | menu cursor 0..3 |
| $B606 | **rival index 0..6** (MIA FERRARU ... KING ARTHUR) |
| $B608 | rival speech state: 0 before race, 1 you won, 2 you lost, 3 five wins ("beaten") |
| $B60A | **best mechanic hired 0..6** (the one that works on the bike) |
| $B60C | phrase category 0..3 (computed by $6404) |
| $B60E | mechanic currently shown on the mechanic screen |
| $B610 | **sponsor index 0..6** (moves together with $B606) |
| $B612 | sponsor speech state: 0 intro, 1 lost clearly, 2 lost narrowly, 3 won, 4 five wins |
| $B616 | part slot selected in the parts shop 0..5: FRAME, ENGINE, BRAKE, MUFFLER, OIL, TIRE |
| $B618+2s | **installed tier** of slot s (frame 0-5, engine 0-5, brake 0-4, muffler 0-3, oil 0-3, tire 0-4) |
| $B624+2s | tier currently browsed in the shop (Left/Right) |
| $B630+n | mechanic n hired flag (7 bytes) |
| $B638 | **money**, packed BCD long, unit $100 (display = digits + "00") |
| $B63C / $B640 | your / the rival's race time of the last race (BCD long `00 MM SS CC`) |
| $B644 / $B646 | races held / races won against the current rival |
| $B648+2s | **health** of slot s, 0..15, negative = failed (frame $B648, engine $B64A, brake $B64C, muffler $B64E, oil $B650, tire $B652) |
| $B655 | bit0 = shop already visited since the race (don't pay twice), bit1 = a race just finished |
| $B656 | result of the mechanic's last roll (non-zero = +1 repair round) – also shifts the phrase category |
| $B658.. | password characters (generated from the above by $4C78/$0057D0) |

## 3. Progression [code, $5700-$5A66]
* Press RACE: if wins == 5 -> "beaten" state (speech 3); else if losses (`$B644-$B646`) == 5 -> demoted one rival/sponsor (or just counters reset at rival 0);
  else the race starts against rival `$B606` with the rival's lap count / times (below).
* After a race (`$5B32`...): races++ unless already counted; **win** if `$B63C < $B640` (your time lower) -> sponsor "won" payout, wins++; otherwise the
  binary difference decides narrow (< $1000) or clear loss payout. Payout is added with `abcd` into `$B638` (capped at $99999999).
* After 5 wins against a rival the next press of RACE advances to the next rival **and** sponsor and zeroes the counters; beating KING ARTHUR 5 times
  returns to the title (end). At the "wins==5 and rival 6" state `$5736` also sets *everything* to maximum (all tiers, all health 15, money 99999999, best mechanic) [code, untested].
* Payouts, laps and rival times: see `03-original-mode-tables.md`.

## 4. Part wear and repair (answers to the first questions)
**Verified by `scripts/wear_test.lua`** (forces the shop entry with a "race finished" flag, all health 8):
1. **Base wear per race** (every part with health >= 0; floor 0): frame 0, **engine 2, brake 1, muffler 1, oil 3, tire 4** (table `$5FE6`).
2. **Mechanic round**: a random number (the game's LCG at `$FF0502`, `sub_0084C2`) is ANDed with a mask that depends on the best mechanic hired
   (`$80,$C0,$E0,$F0,$F8,$FC,$FE` for mechanic 0..6). Non-zero -> **every part (>= 0) gets +1** (max 15), zero -> **every part with health > 0 gets -1**.
   **One roll per race, shared by all six parts** (a single `rng` call at `$5F5E`, no per-part dice): either all parts get +1 or all get -1. Failed parts (<0) are untouched; +1 stops at 15, -1 stops at 0.
   So a better mechanic mostly repairs one point per race; mechanic 0 (free) is a coin flip (-1 or +1); the odds are 1/2, 3/4, 7/8, 15/16, 31/32, 63/64, 127/128.
   Measured: mechanic 0 -> health 8 became `7,5,6,6,4,3` (base wear, then -1); mechanic 6 -> `9,7,8,8,6,5` (+1).
3. Parts at health < 0 (failed) are not touched – they must be replaced in the shop (buying sets health to 15).
4. **In-race damage**:
   * **Crash** (rider thrown; `$AC3A`): **frame -3, engine -1, brake -2, muffler -2** – seen on every fall next to a tree/sign (`scripts/watch.lua`, screenshot at the write).
   * **Bumping a backmarker bike** (object type `$48`, handler `$D482`, damage at `$D53A`): frame -1, muffler -1, no fall. **Confirmed in the emulator** (twice). If the frame was 0 it goes to -1 and that crashes/retires.
   * **Crash into a static roadside object** (type `$34`, handler `$C7BE`, request `$C7F8`): fall, then the damage above when the fall animation ends. Confirmed with 5 crashes. Full per-track map: `tools/hazard_report.py` -> `out/hazards/index.html`; stream format in `tools/roadside.py`.
   * Bots: not yet located (see open items).
5. **Health 0 is "about to fail", not failed**: further stress takes it to -1 (failure) only under conditions: engine at 0 breaks above 180 km/h (`$A0BA`, speed >= $B4),
   **oil at 0 and speed >= $B4 -> engine -1 and oil -1 ("engine burned up")**, muffler at 0 falls off after a timer, brake at 0 fails when braking, tire at 0 blows out after skidding for a while.
   When frame, engine or tire (or oil, which sets the engine) are < 0 the race is retired (`$AC4E`: sets `$FFC898`, "RETIRE ACCIDENT").
   Failure messages: ENGINE TROUBLE (engine <0 but oil ok), YOUR ENGINE IS BURNED UP (oil <0), YOUR FRAME IS BROKEN, YOUR TIRE IS BLOWN OUT, YOUR MUFFLER FELL OFF, YOUR BRAKES ARE GIVING OUT.
   So the user's memory (brakes/muffler/oil can be 0 and you still ride; frame/engine/tires DNF) is right for *failed* parts, with the twist that a failed oil kills the engine.

## 5. Mechanic phrases [exp: poked health + $B656 in the parts shop, screenshots]
Category from the health `h` of the selected part and `$B656` (r = 0 / non-zero):
| h | r = 0 | r != 0 |
|---|---|---|
| < 4 (incl. failed) | 2 | 3 |
| 4-5 | 1 | 2 |
| 6-8 | 0 | 1 |
| >= 9 | 0 | 0 |
**How the roll affects the phrase** (`$6404`): r is `$B656`, the one roll made after the last race (kept until the next race; not re-rolled when you just browse). It only matters when the part is below 9. When r != 0 (the mechanic's repair round happened, probability 1/2 .. 127/128 by mechanic) the phrase is one category *worse* than for r = 0, at every health level: the mechanic is more candid after a successful round. So a good mechanic almost always uses the r != 0 column, a bad one flips between the two. Failed parts (health < 0) count as < 4. Categories 1-3 also print the part name (red overlay, `$16186`); category 0 prints none. The mechanic used is the best hired one (`$B60A`), not the one you are viewing.
Category 0 = "all fine" lines (e.g. "TOP CONDITION!"), 1 = "better change the X", 2 = "X is in trouble", 3 = "change the X!!". Phrase lists per mechanic: `03-original-mode-tables.md`.

## 6. Effect of the parts [code; frame, brake, tire and engine effects are in the physics routines]
* **Frame** ($9788): handlebar response. Steering rates per frame tier (`$A038`: 2,2,2,3,4,5 / 3,4,4,5,7,8 / 6,8,9,0xB,0x10,0x12); tiers >= 2 add speed/128 on top. Higher tier = turns in faster.
* **Brake** ($9788): how fast brake pressure builds, per tier 2,4,7,12,16 (`$A070`), capped at $C5.
* **Engine** ($9B40): acceleration multiplier on the speed gap: tiers 0..5 = x3, x4, x6, x6, x8, x8; also changes the drag above top speed. Tiers 3-5 are the turbo engines.
* **Oil and muffler** ($9B40): each adds a bonus acceleration term (tier x 1/4 of the base term, proportional to the gap to top speed), i.e. **both just add acceleration** (oil 0-3, muffler 0-3; the muffler bonus is lost once the muffler has failed). Oil's other job: at health 0 it takes the engine with it.
* **Tire** ($A44C): converts the smoothed lean (`$38(a0)`) into lateral movement: `$FF0614` += -2 x (lean x 16 [x speed/128 when speed <= 127 and not skidding]) / divisor, with **divisor = 128 + (+$20, +$14, +8, -4, -$10)[tier]** (`$A4C0`; Arcade has no tires and always uses 128). **A higher tier means a smaller divisor, so the same lean moves the bike further sideways** (tier 4 = 112, tier 0 = 160, a factor 1.43 per frame): better tires = stronger turn-in/grip, not less. Checked in the emulator (`scripts/tiretest.lua`: same speed 79, same lean profile, only `$B622` poked): after 110 frames of holding right the lateral position was -106 with tier 0 and -170 with tier 4 (x1.6 including feedback). Skid state `$FF066A` is set when |`$FF0614`| > $12C.

## 7. Bots (backmarker bikes) [code + exp: scripts/botlane.lua, botcrash.lua]
**Fixed lanes, random timing.** There are exactly 5 bot slots (`$FFCC40` + n·$40, type `$48/$49`, updated by `bot_update` `$D482`). Each slot owns one lane for the whole race: lateral target `+$2A` = -180, -90, 0, +90, +180 for slot 0..4 (set by `sub_00F956` at the start grid, never rewritten). A new bot always takes the **first free slot** (`sub_0048BE`), so traffic fills the lanes left to right; a bot is never placed in a random lane.
* **When bots appear** (`sub_00468E` -> `sub_0048BE`) [code, partly exp]: a countdown (`$C812`) runs down by 4 x `$FF052C` per frame in Original mode (capped at 12) and reloads with 100/160/220/280 (rng & 3). When it expires and the number of active bots (`$FF0690`) is below the lap limit, a spawn is requested. The limit by lap (table `$4930`, row 0 = Original mode) is **2,3,3,3,3,4,4,4,5** bots for laps 1..9. At speed > 100 the request spawns a bot immediately; at speed <= 100 it only spawns while the bike is sliding (|`$FF0614`| > $180), with a second random delay of 4..32. exp: at speed 80 the first bot only came once the bike slid out of a curve (slip -480).
* **Speed**: each lap has its own bot speed (table `$D42A`, row 0): **210,205,200,190,180,170,165,165,165** for laps 1..9; a new bot starts with the average `+$A` of the existing ones. Depth accumulator `+$26` changes by 2 x (`+$A` + 5/8 x (your speed - bot speed)) per frame; `+$26`/16 indexes the perspective table `$CFF0` (z). A bot that reaches index `$1FC` is overtaken: `$FF064E` (overtake counter) +1, whoosh sound `$AA/$AB` if it is within 128 px sideways. A bot whose depth falls below 0 disappears (exception: you are slow (<=120) and sliding > $12C: it is thrown to the front, `+$26` = `$1FC0`).
* **Lane changes**: none by choice. On a straight (`$FF067E` = 1) each bot slides back to its lane `+$2A` (6 units/frame). In a curve it drifts 4 units/frame to the **outside** (state 3 = left, state 2 = right), up to +-250. It does not drift toward the rider: while a bot is within $38 px of the rider's centre `+$3A` bits 0/1 block the drift in the rider's direction. exp: bots stayed on their 5 lanes (+-4 units) on every sampled frame, and drifted -20 per 15 frames at the curve.
* **Hit**: frame -1, muffler -1 (no fall unless the frame is already 0). After a hit the bot gets `+$3D` = $FF with probability 1/2, which makes it veer away sideways over the next frames (`+$3E` counter, speed set to `$9FD2`).
* The starting grid (5 bots just ahead of you, positions per rival from `$F9A2`) are the same 5 slots; they fall back/are overtaken in the first seconds.

## 8. Why the inside line is faster [code `$9E18`, exp: exact match in the emulator]
Distance travelled per frame is not just speed. In a curve (`$FF067E` = 2 or 3) the per-frame distance gain is

    gain = 269 x speed x (radius + side/40) / radius

where `radius` = `$FF0682` (word 2 of the road-shape stream entry), `side` = lateral position `$FF0614` counted *toward the inside* (state 3: +`$FF0614`, state 2: -`$FF0614`), `/40` truncates. On a straight the gain is simply 269 x speed. So the road-shape entry is a **curve radius** (smaller = sharper) and the formula is exactly the arc-length ratio between your line and the centre line: inside = shorter path = lap distance (`$FF0616`) grows faster at the same speed. Checked: with `$FF0614` = -500 and speed 79 the game stored `$FF0646` = 18723 = 269 x 79 x 90/102; with +82 and speed 27: 7398 = 269 x 27 x 104/102. The effect is bigger for sharper curves (radius 38: 6/38 = 16 % per 240 units of offset; radius 125: 5 %). The lap ends at distance 2048 regardless of speed, so the gain translates directly into lap time. Per-track curve lists and the possible gain: `04-track-data.md`.

## 9. Open items
* Track storage (sections, curve events, tile lists): `05-track-storage.md`. Arcade lap-time carry bug: `06-arcade-timer-bug.md`.
