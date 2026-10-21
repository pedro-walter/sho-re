local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local pk = {1250, 0xFFB638}
L.watch_write(0xFFC940, 0xFFC941, function(off, data, mask, pc)
  if true then
  print(string.format("STATE f=%d pc=%06X new=%04X old=%04X spd=%04X x=%04X", L.frame, pc, data&0xFFFF, L.u16(0xFFC940), L.u16(0xFF0614), L.u16(0xFFC950))) end
end)
L.run{ frames = 7000, input = input, on_frame = function(f) if f==1250 then L.mem:write_u32(0xFFB638, 0x00999999) end end }
