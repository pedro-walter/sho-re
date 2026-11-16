# Research agenda – Original mode (from the user)

Status legend: [ ] open, [~] partial, [x] answered (answers go in the numbered docs).

- [x] How parts wear; does it depend on the mechanic? -> doc 02 §4 (base wear per race + mechanic's random +1/-1 round)
- [x] Mechanics: how they influence wear and/or repair after each race -> doc 02 §4 (hire price, roll odds 1/2..127/128)
- [x] Damage: bots (type $48) = frame -1 AND muffler -1 (confirmed); static roadside objects (signs, trees, poles, billboards, rocks; type $34) = fall -> frame -3, engine -1, brake -2, muffler -2 (confirmed). Per-track map: out/hazards/index.html (tools/hazard_report.py)
- [x] Part health 0..15 (doc 02 §4.5: 0 = about to fail, <0 = failed; failed oil kills the engine); 0 = broken/needs replacement. Memory: brakes/muffler/oil can be 0 and you still ride; frame/engine/tires at 0 = DNF (confirm)
- [x] Mechanic phrases per part health – map them out -> doc 02 §5 + doc 03
- [x] Part effects (doc 02 §6; oil and muffler = extra acceleration; tire: higher tier = more lateral response per lean, measured): frame (turning), engine (acceleration, turbo on higher tiers), tires (skid), brakes (braking), **oil (?)**, **muffler (?)**
- [x] Tables (doc 03; lap *times* format still to verify with a finished race): payout per sponsor, mechanic prices and names, part prices, rival names, laps per race per sponsor, rival lap times
- [x] How are the maps (tracks) stored? -> doc 05: 24 sections (3/5/7/9 per arcade course), each = palettes + road shape + curve events + roadside objects, plus per-stage tile DMA lists; Original mode picks one per rival with 3 words at $8E58 (verified by patching: any section can be given to any rival)
- [x] Known bug: lap-time hundredths carry into the next section in Arcade mode -> doc 06 (sub-second tick counter $FF0557 is not cleared at a checkpoint; tested 14-byte fix)
- [x] Why is driving close to the inside of a corner faster? -> doc 02 §8 (distance gain scaled by (radius + side/40)/radius)
- [x] Bot behaviour: random or fixed? -> doc 02 §7 (5 fixed lanes filled left to right, random timing, per-lap speed/count)
- [x] Where do bots go sideways and why (swerving, cutting in front, spawn position)? -> doc 11 (lat `+$08` rules: return 6 / outward drift 4 / inward swing 4 before a curve, rider + neighbour blocks, lat survives respawn; 86,413 updates verified). Open: why the announce window reverses sign, screen-x formula, lone-bot self-block mechanism
- [x] How the random number generator works and how the mechanic roll (+1/-1 on parts) is decided -> doc 07 (LCG at $FF0502, no entropy source, state advanced by bot events)

## Later (added by the user)

- [ ] **Slow inside line vs fast wide line.** Is it better to hug the inside edge (lateral 280-300, the full inside gain) and be slower, or to take a wider line and keep more speed? Why it is open:
  - The inside gain is a lap-distance multiplier of (radius + side/40)/radius (doc 02 §8), +13.8 % at the clamp in radius 85, up to ~16-18 % in radius 38-45 curves.
  - Staying at the inside edge means steering against the outward push the whole curve (doc 02 §8, `scripts/edgeshot2.lua`), and the game adds 12-22 lateral units per frame at full lean, so the limit sits near lateral 278 pre-update at full lean.
  - Unknown: does steering/lean (`$38(a0)`) cost speed or acceleration in the game? Does a wider line allow less lean, a higher top speed or earlier turbo (turbo needs speed > $F0 and no skid, and gives 241 -> 279)? Turbo alone is worth ~+15 % speed, comparable to the whole inside gain.
  - Suggested method: a driven-lap harness (`scripts/latprobe.lua` / `edgeshot2.lua` as a base) that holds a chosen lateral line through a full lap on one rival, with turbo on and off, and compares lap time (`$FF0616` reaching 2048); sweep line (e.g. 150, 220, 280) per curve radius.
  - Caveat to settle first: the drawn bend and the physical curve are separate data (doc 05), and doc 04's left/right labelling of states 2/3 may be reversed.
