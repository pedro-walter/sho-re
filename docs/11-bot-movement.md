# 11. Where the other bikes are on the road, and why they move

Backmarker bikes ("bots") look as if they weave about at random, and sometimes cut in front of you. They do not. Where a bot is sideways is decided by a handful of fixed rules that run every few frames. The only randomness is *when* a bot spawns (see doc 02 §7 and doc 07). This document explains the rules, shows real examples taken from the emulator, and lists the quirks that make the behaviour look odd.

Evidence: 12 headless runs (tracks 1-3, the lap autopilot driving, plus runs that steer into bots), logged every frame. The rules below predicted **all 86,413 bot updates exactly** (`tools/botanalyze.py`). Things I inferred but could not prove are marked **[inferred]**.

## 1. The short version

1. Each bot is steered by one number: `lat` (`+$08`), its position across the road. It goes from -250 (far left) to +250 (far right); the road edge is around ±270. Positive is **right**.
2. Every slot also has a **lane** (`+$2A`): -180, -90, 0, +90 or +180 for slot 0 to 4. The lane never changes (0 changes in 12 logs). It is only the place the bot returns to when the road is straight.
3. The bot is *not* on its lane most of the time: only **22.6 %** of bot updates had a bot within 8 units of its lane.
4. Every update, depending on the road, a bot does exactly one of these:

| Road situation | What the bot does (per update) |
|---|---|
| Straight, nothing announced | slides back toward its lane, 6 units |
| Inside a curve | drifts to the **outside** of the curve, 4 units (left curve: right; right curve: left) |
| The last ~40 distance units before the road type changes ("announce window") | moves toward the **inside**, 4 units (toward the inside of the coming curve, or of the current curve if it is about to end) |
| Close to the rider, or to another bot, on the side it wants to move toward | does not move that way that tick |
| Close to you (depth ≥ `$AF`) | does not move sideways at all |

5. A bot that is freed and respawned **keeps the sideways position of the bot that was in that slot before**. It does not go back to its lane. 435 of 508 respawns in my logs started off their lane.
6. Updates happen once per game tick, about every 3rd video frame.

So "the bike that cut in front of me" is nearly always one of: a bot swinging inward before a curve (4 units per tick, about 100 units in total), a bot sliding back to its lane after a curve (6 per tick), a bot that respawned where its predecessor was pushed to, or simply your own steering across its path.

## 2. The memory variables

All are 68000 RAM addresses. The bot slots are 5 objects at `$FFCC40 + n×$40` (n = 0..4). A slot is "in use" while bit 0 of its type word (`+$00`) is set.

| Address | Name here | What it is |
|---|---|---|
| `+$08` (word) | **lat** | The bot's real sideways position on the road, -250..+250, positive right. This is the number that moves. |
| `+$2A` (word) | **lane** | The slot's lane: -180, -90, 0, +90, +180. Written once at race start (`bot_grid_setup` `$F956`), together with `lat`. |
| `+$0A` (word) | speed | The bot's speed (doc 02 §7: per-lap table `$D42A`). |
| `+$0C` (word) | **z** | How far down the screen the bot is, 0 (horizon) to `$BF` (alongside you). |
| `+$10` (word) | **x** | Where the bot is drawn horizontally on screen, `$120` = screen centre. It is `lat` projected by depth plus the road's curve (doc: bot rendering). Not the same thing as `lat`. |
| `+$26` (word) | depth | Approach counter; `depth >> 4` is the index into the perspective table `$CFF0`, and the bot is passed at `$1FC`. |
| `+$3A` (byte) | **flags** | Block bits, set during a tick and used by the lateral rule. Bit 0: "do not move toward +lat (right)". Bit 1: "do not move toward -lat (left)". Bit 2: "speed up by 1" (pair spacing). |
| `+$3D`, `+$3E`, `+$34` | hit veer | `+$3D` = `$FF` after a collision (set with probability 1/2); `+$3E` counts ticks since; `+$34` is the screen side it is shoved to. |
| `$FF0614` (word) | **your lat** | Your own sideways position, same scale as `lat` (positive right). (My BizHawk viewer used to call this "slip".) |
| `$FF067E` (word) | **road state** | Road at your position: 1 = straight, 2 = left-hand curve, 3 = right-hand curve. |
| `$FF0676` (word) | **next state** | The road state announced ahead. 0 = nothing announced. See §3. |
| `$FF0616` (word) | distance | Distance along the lap. |
| `$FF068A` / `$FF0690` | bot counters | Bots updated this tick / the count used by the spawn limit (and by the pair code). |
| `$FF0804..` | bot list | The per-tick list of (bot, lat, z), sorted by z, used by the pair code (§4). |

Direction conventions (confirmed against the player push in doc 09): state 2 = left-hand curve, which pushes you (and bots) toward **+lat**, the right; state 3 = right-hand curve, which pushes toward **-lat**.

## 3. When a bot moves

* **Once per tick, not per frame.** Every bot's `lat` changed only on frames with the same phase, 3 frames apart (gaps of 3: 10,338 of ~10,700 observed intervals; the rest are multiples of 3 where the bot did not move). A bot moving 4 units per tick moves about 80 units per second.
* **Only while z < `$AF`.** From `$AF` on, the bot is almost alongside you and its `lat` is frozen until you pass it. Frozen ticks were 3,261 of 86,413.
* **The announce window.** `$FF0676` is set when your distance gets within `$28` (40) distance units of the next road-state change, and cleared when you reach it. At normal speeds that is about 120-135 frames (median 135 on track 1, min 117). During it the bots use the *announced* state, with the opposite sign to the steady-state rule, which makes them cut toward the inside.
* **A cap.** A curve or announce move is ignored if it would take `lat` to ±`$FA` (250) or beyond. The return-to-lane move has no cap.

## 4. The rules in order (what the code does each tick)

For a bot with z < `$AF`, read from `bot_update` (`$D596..$D654`) and `traffic_manager` (`$4714..$4788`), and verified exactly:

1. **Which blocks apply?**
   * *Rider block.* If z > `$70` and the bot is within `$38` (56) screen pixels of your centre: bit 0 if it is left of centre, bit 1 if it is right. (It cannot step toward the middle of the screen, where you are.)
   * *Pair block.* Last tick, `traffic_manager` sorted the bots by z and compared each with the next one. If their z gap is less than `z × 32 / 191` **and** their `lat` differs by less than 60, the left one gets bit 0 and the right one gets bit 1 (neither can move toward the other), and the nearer one gets bit 2, which adds 1 to its speed each tick so it pulls ahead.
2. **Pick the move**
   * If `next ≠ state` and `next ≠ 0`:
     * `next = 2` → -4 (left), `next = 3` → +4 (right)
     * `next = 1`: state 2 → -4, state 3 → +4 (state 1 → falls through to the next case)
   * otherwise:
     * state 1 → move 6 toward the lane (stay if equal)
     * state 2 → +4
     * state 3 → -4
3. **Apply it unless blocked.** A move to the right is blocked by bit 0; a move to the left by bit 1. A curve/announce move that would reach ±250 is dropped.
4. Clear the flags.

## 5. Examples from real runs

Each table is one bot, one row per tick. Columns: video frame, road state, announced next state, your lat, the bot's `lat` before and after, its lane, its z, its screen x offset (`x - $120`), the rule that applied, and the flags it started the tick with. Track 1, lap autopilot driving, from `out/botsim/t1_auto.txt`; regenerate with `tools/botexamples.py`.

### Example 1: staying still on its lane
A straight, slot 0 on lane -180, no announced curve. It does not move at all. (z and x change only because it is getting closer.)

```
frame st nx  you   lat before->after  lane   z    x   rule
 7264  1  0   26      -180 ->  -180   -180   60  -41  at-lane
 7267  1  0   24      -180 ->  -180   -180   63  -43  at-lane
 7270  1  0   24      -180 ->  -180   -180   65  -47  at-lane
 7273  1  0   22      -180 ->  -180   -180   66  -47  at-lane
```

### Example 2: wobbling around its lane
The return rule moves 6 units. If the bot is 2 units off, the nearest it can get is a different 2 units off on the other side, so it flips every tick forever. This is a game quirk, only ±3 units, invisible in play.

```
frame st nx  you   lat before->after  lane  rule
 1489  1  0  -44      -178 ->  -184   -180   return
 1492  1  0  -38      -184 ->  -178   -180   return
 1498  1  0  -26      -184 ->  -178   -180   return
 1513  1  0  -16      -178 ->  -184   -180   return
```

### Example 3: sliding back to its lane after a curve
Slot 1 (lane -90) had been pushed out to -170 and is walking back at 6 per tick, not hurrying and not minding where you are.

```
frame st nx  you   lat before->after  lane   z    x   rule
 2080  1  0  -90      -170 ->  -164    -90   45  -49  return
 2083  1  0  -96      -164 ->  -158    -90   47  -51  return
 2086  1  0 -100      -158 ->  -152    -90   49  -54  return
 ...                 (one row per tick, +6 each)
 2110  1  0 -102      -110 ->  -104    -90   65  -60  return
 2113  1  0 -100      -104 ->   -98    -90   68  -60  return
 2116  1  3  -96       -98 ->   -94    -90   70  -60  announce(next3)
 2119  1  3  -90       -94 ->   -90    -90   72  -60  announce(next3)
```

### Example 4: drifting outward inside a curve
State 3 (right-hand curve). Slot 0 is pushed to the **left**, the outside of the curve, 4 units per tick, until it hits the ±250-limit rule and stops there.

```
frame st nx  you   lat before->after  lane   z    x   rule
 5863  3  3 -154      -188 ->  -192   -180   57 -105  drift(st3)
 5866  3  3 -172      -192 ->  -196   -180   58 -111  drift(st3)
 5869  3  3 -190      -196 ->  -200   -180   60 -119  drift(st3)
 ...
 5905  3  0 -208      -244 ->  -248   -180   76 -161  drift(st3)
 5908  3  0 -200      -248 ->  -248   -180   77 -162  drift(st3) clamp
```

### Example 5: swinging in front of you before a curve (the "cut in")
Slot 0 sits on lane -180, left of you. A right-hand curve is about to start, so the announce window opens (`nx = 3`) and the bot moves **right, toward the inside of the coming curve**, 4 per tick, for 40 ticks. It travels about 100 units across the road, passes your position, and is then released into the normal curve rule, which pushes it back to the left.

```
frame st nx  you   lat before->after  lane   z    x   rule
 2113  1  0 -100      -180 ->  -180   -180   47  -60  at-lane
 2116  1  3  -96      -180 ->  -176   -180   49  -60  announce(next3)      <- window opens
 2119  1  3  -90      -176 ->  -172   -180   51  -61  announce(next3)
 2137  1  3  -44      -152 ->  -148   -180   63  -56  announce(next3)
 2155  1  3  -24      -128 ->  -124   -180   77  -51  announce(next3)
 2173  1  3  -20      -104 ->  -100   -180   97  -51  announce(next3)      <- level with your lat (-20)
 2188  1  3  -16       -84 ->   -84   -180  117  -52  announce(next3) blocked
 2197  1  3  -10       -84 ->   -80   -180  131  -56  announce(next3)
 2221  1  3   66       -76 ->   -76   -180  177   -2  announce(next3) blocked   <- near you, blocked
 2224  1  3   58       -76 ->   -76   -180  183  -11  frozen(z>=AF)             <- alongside, frozen
 2254  3  0  -86       -76 ->   -76   -180  191 -129  frozen(z>=AF)
 2269  3  0 -140       -76 ->   -76   -180  168 -155  drift(st3) blocked
 2272  3  0 -148       -76 ->   -80   -180  162 -160  drift(st3)               <- curve: now pushed left
```

Over 251 straight-to-curve windows in my logs the bots' net sideways change during the window had a median of -64 and ranged from -220 to +316. Which way depends on whether the next curve is left (`next = 2` → left) or right (`next = 3` → right).

### Example 6: blocked by you
Slot 1 (lane -90) wants to creep right toward the middle of the screen. You are in the way: it is within 56 px of your centre and z is 117 > `$70`, so bit 0 (it is left of centre, and +4 is a move toward the centre) stops the move.

```
track 1, frame 2161: road st=1 nx=3, you at lat -22
slot 1 lat=-38 lane=-90 x=-32 z=117: would move to -34, stays at -38
```

### Example 7: blocked by another bot
Two bots close together get blocked from moving toward each other. Frame 14191, state 3 (the curve pushes everything left). Slot 1 would drift left to -220, but slot 0 is 32 units to its left and nearly level in depth (z gap 3, limit `24 × 32 / 191` = 4; lat gap 32, limit 60), so the pair code set bit 1 on slot 1 (no left move) and bit 0 + bit 2 on slot 0 (no right move, speed up). The flags are set at the end of the previous tick, which is why the flags column already shows them.

```
slot lat  lane   z  flags   lat after
  0  -248 -180   24   5      -248   (at the -250 limit anyway)
  1  -216  -90   21   2      -216   (would have moved to -220)
  2  -128    0  119   0      -132   (far away, drifts as normal)
```

### Example 8: a new bot appears off its lane
When a bot is passed, its slot is freed but `lat` is left alone. The next bot in that slot inherits it. In 508 respawns, 508 started within one step (6) of where its predecessor left, and only 17.8 % started on their lane (median distance from the lane 66 units, mean 111).

```
frame  989 slot 0: previous bot left at lat -248, new bot appears at lat -248 (its lane is -180)
frame 1112 slot 0: previous bot left at lat -248, new bot appears at lat -248 (its lane is -180)
frame 1268 slot 0: previous bot left at lat -244, new bot appears at lat -238 (its lane is -180)
```

### Example 9: what a collision does
Hit at frame 751 (slot 1): `+$3D` = `$FF` and a counter (`+$3E`) starts. Its drawn x is shoved sideways, growing by about 20 px per tick, toward the side it was on, up to ±200 px from the centre, where it stays. Its `lat` does not change at all, and it is freed once its depth passes `$1FC`, a few dozen frames later.

```
frame  you   lat    x   3E      (x = screen offset from centre)
  751  -12   -18  -11    1
  754  -28   -18  -30    2
  757  -44   -18  -52    3
  760  -60   -18  -71    4
  ...
  778 -248   -18 -200   10      <- at the limit, still lat -18
```

## 6. Why one seems to go in front of me

Out of 2,823 updates of a visible bot (z `$40..$AE`) in the autopilot logs, there were 25 where the bot's `lat` and yours crossed (sign of `bot lat - your lat` flipped within 150 units). The causes:

* 17 curve drift (4 per tick) and 3 announce window (4 per tick). These are the "swerve toward the inside, then be pushed out".
* 2 return to lane (6 per tick).
* 3 where the bot did not move that tick (blocked or between updates): you did.

Counting the moves a bot made, 738 were toward you and 1163 away (about 39 % toward). Nothing aims at you; the road state moves them, and your own steering across their path does the rest.

Also, a collision is decided on the **screen**, not by comparing `lat` values. The test (`bot_update` at `$D4B2`) is: z ≥ `$A0` and the bot's drawn x within a pose-dependent width of the centre. Because the road bends on screen, a bot can be beside you on screen without being near you in `lat`. In one run (track 1, frame 6073, state 3), a bot at `lat` -248 was hit by you at `lat` 240.

## 7. Quirks worth knowing

1. **Direction reversal.** In the announce window the bot moves *opposite* to the steady-state rule for the same state. Seen as "swing inward, then get pushed outward". I can describe it exactly but I do not know why the code does it. **[inferred]** It looks like an intended racing-line effect.
2. **`lat` survives respawn.** The reason lanes look unreliable. Bots are on their lane only 22.6 % of the time.
3. **A lone bot sometimes blocks itself.** With exactly one live bot, flags `7` (both blocks + speed-up) appear on about 16 % of ticks (427 of ~2,680), often alternating tick by tick, which halves its sideways speed. The same flag value also showed up with two bots far apart in depth. **[inferred]** cause: `traffic_manager` only clears the bot counter `$FF068A` inside the pair code, which is skipped when the count is ≤ 1; the counter then reaches 2 next tick, and the pair code compares the bot's stale list entry with itself.
4. **Return-to-lane wobble** of ±3 around the lane (Example 2).
5. **A hit only changes where the bike is drawn**, not its `lat`, and it also hurts you (doc 02 §7).
6. **Update rate.** A bot's speed in lateral units per second is 20 ticks × 4 = 80 (curve and announce) or 20 × 6 = 120 (return). A full road crossing takes 3-5 seconds.

## 8. How this was checked

* `scripts/botsim.lua` + `tools/botsim.sh` load a race savestate, let the lap autopilot drive (or a simple driver steer into bots), and log every bot's `lat`, lane, x, z, depth, flags, plus the road state, the next state and your lat, every frame.
* `tools/botanalyze.py` predicts each bot's next `lat` from the previous frame with the rules in §4 and compares: 86,413 of 86,413 updates exact (rule mix: 33,863 curve drift, 27,689 announce window, 13,386 return, 8,214 at lane, 3,261 frozen), over 3 tracks and 12 logs.
* `tools/botexamples.py` prints the tables above.
* Reproduce: `tools/botsim.sh t1_auto 1 3 auto` (track 1, 3 laps, autopilot), `tools/botsim.sh t1_ram 1 1 ram` (steer into bots), then `python3 -I tools/botanalyze.py out/botsim/t1_auto.txt`.

Not done: the screen-x formula (how the road's curve offset combines with `lat`), what the speed-up bit does for pairs in practice, and why the announce window reverses the sign.
