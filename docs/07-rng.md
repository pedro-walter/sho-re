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
| `$A554` | Small +/-1 wobble of an object's fields `$10/$14` (not traced further) |
| `$8DF0` | Picks two values (`(r&3)+3`, and a table entry by `r&7`) for a scenery/animation byte (not traced further) |

## The mechanic roll
After the base wear, `r = rng()`, `r & mask` with mask = `$80,$C0,$E0,$F0,$F8,$FC,$FE` for the best hired mechanic 0..6. Non-zero -> all parts +1 (stop at 15), zero -> all parts with health > 0 get -1. One roll for all six parts; stored in `$B656`. Only bits 7 down to 1 of r are ever tested (bit 0 never).
Odds: simulation over 300 000 draws gave 0.4985, 0.7489, 0.8739, 0.9372, 0.9684, 0.9841, 0.9919 vs. theory 1/2 ... 127/128.

## Consequences
* The roll is a deterministic function of the number of `rng` calls since boot, which in turn depends on how many bots spawned/collided during races: random in practice, repeatable from a cold boot with identical inputs.
* The first shop roll after a cold boot with no earlier `rng` call is always r=`$8010` (low byte `$10`): mechanics 0-2 (masks `$80/$C0/$E0`) get **-1**, mechanics 3-6 (masks `$F0` and up include bit 4) get **+1**. The emulator run without a poke showed -1 for mechanic 0, as predicted.
