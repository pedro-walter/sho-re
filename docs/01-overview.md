# Super Hang-On (Genesis, World, Rev A) – reverse-engineering notes

ROM: `Super Hang-On (World) (En,Ja) (Rev A).md`, 512 KB, header "SEGA MEGA DRIVE (C)SEGA 1989.JUL", checksum checked at boot.
**The repo holds no game data**: bring your own ROM (copy goes in the repo root; `.gitignore` excludes it, `out/`, and the generated listing).

## Dev environment

| piece | where |
|---|---|
| Emulator | **MAME 0.289** from Flatpak (`flatpak install --user flathub org.mamedev.MAME`), run headless (`-video none -sound none -nothrottle`), ~10x realtime |
| Runner | `tools/mame.sh script.lua` – passes `SHO_*` env vars through to the Lua script; output (screenshots, dumps) goes to `out/` |
| Lua helpers | `scripts/lib.lua` (frame loop, input schedule, RAM reads, snapshots, write taps) |
| Generic driver | `scripts/play.lua` – `SHO_INPUT="frame:btn+btn:dur,..." SHO_FRAMES=N SHO_SHOT="every 200" or "f1,f2" SHO_DUMP="f1,f2" SHO_TAG=x` |
| Write watch | `scripts/watch.lua` – `SHO_WATCH="FFC704-FFC705"` prints frame, writing PC, value |
| Coverage | `tools/cov.sh TAG` – same env as play.lua, plus a trace of every executed PC -> `out/cov_TAG.txt` (slow: ~1-2 min per 1000 frames) |
| Disassembler | `tools/m68k.py` (own 68000 decoder, checked against MAME's `unidasm` by `make check-m68k`), `tools/disasm.py` -> `disasm/sho.asm` (`make disasm`) |
| Annotations | `disasm/annot/{symbols,ram,hwregs,comments,regions}.txt` (hand written; the listing is regenerated from them) |
| Misc | `tools/sheet.py` (contact sheet of screenshots), `tools/ramdiff.py` (RAM dump diff) |

Buttons for `SHO_INPUT`: `up down left right a b c start`. Menu flow (frames are not exact, the game waits on its own):
Start@300 (title) -> Start@600 (mode menu: ARCADE / ORIGINAL) -> Down@900 -> Start@1000 (Original mode) -> shop screen.
In the shop: C selects, B backs out; command list is PARTS / MECHANIC / RACE / END (END shows the password).

### Gotchas learnt
* Lua `install_write_tap` handles must be kept referenced (lib.lua does) or MAME silently drops the tap on GC.
* In the debugger, `pc` is the prefetch PC (+2 or more); use `curpc` (Lua: `cpu.state["CURPC"]`).
* Trace lines contain `(interrupted at ..)` markers; cov.sh filters on 6-hex-digit lines.
* `-debug -debugger none` is required for the `trace` command from Lua (`manager.machine.debugger`).
* `unidasm -arch m68000` actually decodes 68020+/PMMU opcodes; only length/legality mismatches in data areas remain.

## CPU / memory facts (68000, Genesis)
* Vectors: initial SP=`$FF0200`, reset=$6BAC, level-6 (VBlank)=$6D2A, level-4 (HBlank)=RAM stub `$FF05D2`.
  Everything else points at `$200` (loop) / `$202` (rte).
* RAM $FF0000-$FFFFFF. `$FF0000` holds 'init' after first boot.
* The Z80 sound driver ($1A24 bytes at ROM $7D7F4) is copied into Z80 RAM by `load_z80_driver` ($6E28); commands go through `$A01C03`.
* Main loop at $6CE0 dispatches `game_mode` ($FFC704) through a bra table at $6CF2; the VBlank handler dispatches `vblank_mode` ($FFC722) through the table at $6D42.
