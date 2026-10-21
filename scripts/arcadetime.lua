-- Arcade mode timer probe: logs every write to the lap-time word $FF0558 (seconds, hundredths in BCD) together with the
-- sub-second frame counter $FF0557, plus a periodic line. Env: SHO_INPUT, SHO_FRAMES, SHO_SPEED (poke speed to cover distance faster)
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local SPEED = tonumber(os.getenv("SHO_SPEED") or 0)
local JUMP = tonumber(os.getenv("SHO_JUMP") or 0)   -- frame at which to poke the checkpoint-gate flag $FF06B4 (sub_00E5F6 then runs the stage-end handler)
local function st() return string.format("left=%02X tick1=%02X tps=%02X frame557=%02X sec558=%02X hund559=%02X lapdist=%04X stage=%d", L.u8(0xFF0554), L.u8(0xFF0555), L.u8(0xFF0556), L.u8(0xFF0557), L.u8(0xFF0558), L.u8(0xFF0559), L.u16(0xFF0616), L.u16(0xFF060A)) end
L.watch_write(0xFF0558, 0xFF0559, function(off, data, mask, pc)
  if data == 0 or (data & 0xFFFF) == 0 then print(string.format("CLR f=%d pc=%06X before: %s", L.frame, pc, st())) end
end)
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 6000), input = input, on_frame = function(f)
  local race = L.u16(0xFFC704) & 0x7FFC == 0x18
  if race and SPEED > 0 and L.u16(0xFF0616) > 0 and L.u16(0xFF064A) < SPEED then L.mem:write_u16(0xFF064A, SPEED) end
  if race and f > 2600 then   -- autopilot: keep the road centre under the bike (same trick as photo.lua)
    local c = L.s16(0xFF0D00 + 2 * 0xBF) // 64
    L.pad({ c = true, right = c > 14, left = c < -14 })
  end
  if race and JUMP > 0 and f == JUMP then L.mem:write_u16(0xFF06B4, 0xFFFF); print("GATE " .. st()) end
  if race and JUMP > 0 and f > JUMP and f < JUMP + 400 and f % 10 == 0 then print(string.format("J f=%d %s lap_long=%08X", f, st(), L.u32(0xFFC82E))) end
  if race and f % 240 == 0 then print(string.format("T f=%d %s", f, st())) end
end }
