-- Prints the player object ($FFC940) fields +0,+$10,+$14,+$1C,+$1E and lateral/skid flag per frame in a window: shows the rng-driven skid wobble.
-- Env: SHO_INPUT, SHO_FROM, SHO_TO
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):([%a+]+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local from, to = tonumber(os.getenv("SHO_FROM") or 4600), tonumber(os.getenv("SHO_TO") or 4700)
L.run{ frames = to, input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= from then
    local o = 0xFFC940
    print(string.format("S f=%d type=%04X x10=%04X y14=%04X c1C=%04X c1E=%04X lat=%d skid=%04X rng=%04X", f, L.u16(o), L.u16(o+0x10), L.u16(o+0x14), L.u16(o+0x1C), L.u16(o+0x1E), L.s16(0xFF0614), L.u16(0xFF066A), L.u16(0xFF0502)))
  end
end }
