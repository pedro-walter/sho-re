# 07 - The random number generator and what uses it

Verified with `scripts/rngtest.lua` (pokes the state, forces the shop's post-race roll) against a Python model; code reading for the rest.

## The generator (`rng`, `$0084C2`, state `$FF0502`)
```
if (state & $FFFF) == 0: state = $2A6D365B      ; reseed (RAM is 0 after boot)
t  = state * 41  (mod 2^32)                      ; add/shift sequence in the code
lo = t & $FFFF;  hi = t >> 16
r  = (lo + hi) & $FFFF
state = (r << 16) | lo
return r                                          ; D0.w = new high word
```
* First call after a cold boot returns `$8010`, then `$2A6D365B`-seeded sequence; 300 000 consecutive states were all distinct.
* **No entropy source**: nothing seeds from a timer, VDP counter or controller. Only arcade-mode race start clears the state (`$F642`, skipped when `original_mode` is set), so in Original mode it advances for the whole power-on session.
* Emulator check: poked `$12345678` -> r=`$C399` (state after `$C399D938`); `$00010001` -> r=`$0052`; `$7F7F0001` -> r=`$6B80`; all matched the model.

## Callers
| Where | Use |
|---|---|
| `$5F5E` | **Mechanic repair roll** after a race (below) |
| `$480C` | Bot-spawn countdown reload: `(r & 3)` selects 100/160/220/280 (doc 02 §7) |
| `$4896` | Bot lane/delay: `ror.w` of the state's low word (also perturbs the state), `(low & 7)+1` x 4 |
| `$D54E` | Bot collision: bit 0 of r sets a flag (`$3D(a0) = $FF`) |
| `$A554` | **Skid wobble of the player's bike sprite** (`sub_00A546`, below) |
| `$8DF0` | **Rival lap-time jitter**, 2 draws per lap entry (below) |

## The mechanic roll
After the base wear, `r = rng()`, `r & mask` with mask = `$80,$C0,$E0,$F0,$F8,$FC,$FE` for the best hired mechanic 0..6. Non-zero -> all parts +1 (stop at 15), zero -> all parts with health > 0 get -1. One roll for all six parts; stored in `$B656`. Only bits 7 down to 1 of r are ever tested (bit 0 never).
Odds: simulation over 300 000 draws gave 0.4985, 0.7489, 0.8739, 0.9372, 0.9684, 0.9841, 0.9919 vs. theory 1/2 ... 127/128.

## Consequences
* The roll is a deterministic function of the number of `rng` calls since boot, which in turn depends on how many bots spawned/collided during races: random in practice, repeatable from a cold boot with identical inputs.
* The first shop roll after a cold boot with no earlier `rng` call is always r=`$8010` (low byte `$10`): mechanics 0-2 (masks `$80/$C0/$E0`) get **-1**, mechanics 3-6 (masks `$F0` and up include bit 4) get **+1**. The emulator run without a poke showed -1 for mechanic 0, as predicted.

## Traced: `$8DF0` = rival lap-time jitter (12 draws per race start)
`$8DB0` builds the rival's 6 lap times in `$FFC860 + 8n` (BCD longs, base time from `rival_times` `$8D84`); after each long it calls `$8DF0`, which writes the hundredths byte: high nibble = `(r1 & 3) + 3`, low nibble = `$8DA0[r2 & 7]` = `{0,3,6,0,3,6,0,3}`. Result 0.30 ... 0.66 s added per lap (doc 03). Emulator trace (`scripts/rngcallers.lua`): exactly 6 + 6 calls (return addresses `$8DF4` and `$8E02`, A0 = `$FFC860, $FFC868, ... $FFC888`) all in the single frame of the pre-race setup (mode `$11`). So each race start burns 12 draws regardless of laps.

## Traced: `$A554` = skid wobble of the player's bike (`sub_00A546`, called from `$A3A0`)
* `a0` is always `$FFC940`, the player's bike object (type `$0008`). `$A4CA` sets the skid flag `$FF066A` when |lateral| > `$12C` (300) and increments `$1C(a0)`; `$A546` consumes that: one `rng` call, `$1E(a0)` += 1, then `$10(a0)` += `+-(r & 1)` (sign from bit 1 of the counter) and, on odd counts, `$14(a0)` += `+-1`. These are the sprite offsets (rest `$120`, `$15F`, set by `$8D00`); when `$1C` is 0 the code instead eases them back to rest (`$A58A`).
* Seen in `scripts/skidwobble.lua`: skid starts at frame 4606 (lateral -310), from then `$10` wanders 11F..123 and `$14` 15F..160, one draw every 3rd frame (555 of 562 gaps were exactly 3 frames; gaps of 93-636 frames = periods without skid).
* So **skidding feeds the generator**: every third skid frame advances the state. In the 9600-frame scripted run (left/right swerving) it was **562 of the 618 draws (91 %)**; bot-spawn countdown (`$480C`) 44, rival jitter 12 (all in this run; `$D54E`, bot bump, 0 times as no bump happened).

Measured call counts (`out/rngcallers.log`, orig_race scenario, 9600 frames): `$A558` 562, `$4810` 44, `$8DF4` 6, `$8E02` 6, plus the `ror.w` at `$4896` (92, separate write, not a call). The mechanic roll at `$5F62` (not in this run, shop reached via poke).
