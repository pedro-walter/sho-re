# Arcade mode: lap-time carry bug

**Symptom:** after a checkpoint the new section's time starts with the hundredths (and the first second is short) of the previous section instead of 0'00"00, so every section time after the first is too long by the sub-second leftover (0.00-0.96 s).

## Cause

Arcade keeps its clock at `$FF0554` (see `ram.txt`):

| address | meaning |
|---|---|
| `$FF0554` | seconds left (BCD, the `TIME` display) |
| `$FF0555` | ticks until the next TIME-left second (reloaded from `$FF0556`) |
| `$FF0556` | ticks per second = `$1E` (30) |
| `$FF0557` | tick counter inside the current elapsed second |
| `$FF0558` / `$FF0559` | elapsed section time: seconds / hundredths, BCD |

Every game tick `race_timer_tick` (`$9652`, arcade branch `$9708`) increments `$FF0557`; at 30 it clears `$FF0557` and `$FF0559` and does `$FF0558 += 1` (BCD). In between, `$FF0559` is recomputed from the tick counter (`tick x 100 / 30`, two BCD digits: `$9756`).

When the bike crosses the checkpoint gate, `checkpoint_handler` (`$E5F6`) stores the section time, adds the bonus time to `$FF0554` and restarts the section timer at `$E6A6`:

```
00E6A6  clr.w   $ff0558.l            ; seconds + hundredths  -> 0
00E6AC  clr.l   $c82e                ; displayed lap-time structure -> 0
00E6B0  move.b  $ff0556,$ff0555      ; TIME-left tick counter reloaded
```

`$FF0557`, the tick counter inside the second, is **not** cleared, so the next frame recomputes the hundredths from the old tick count. Race start (`$E6D2/$E6D8`) clears both `$FF0558` and `$FF0557`, which is why the first section is correct.

Original mode is not affected: its lap time (`$C82E`) is counted by `sub_0096AE` from `$FF0555`, which the same code reloads.

## Verified in the emulator

`scripts/arcadetime.lua` (poking the gate flag `$FF06B4` at a chosen frame, `SHO_JUMP`):

| | tick counter at the gate | first display after the gate (10 frames later) |
|---|---|---|
| original ROM | `$13` (19 of 30) | tick 21: **0'00"70**; the first second ends after only 11 more ticks (0.37 s) |
| patched ROM | `$13` | tick 2: **0'00"06**, counts normally |

So the section time is inflated by the 0.63 s leftover of the previous section in this run.

## Fix (tested)

Clear the tick counter too. `$E6A6` has 6 bytes, so call a 14-byte helper in the free `$FF` area at `$161F0`:

```
tools/patchrom.py out/patched/lapfix.md 161F0:427900ff0558423900ff05574e75 E6A6:4eb9000161F0
```

* `$161F0`: `clr.w $ff0558.l` / `clr.b $ff0557.l` / `rts`
* `$E6A6`: `jsr $161F0.l` (replaces `clr.w $ff0558.l`)
* `patchrom.py` also fixes the boot checksum.
