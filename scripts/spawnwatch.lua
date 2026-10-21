-- Logs every write to the type word (+0) of the object slots $FFC900..$FFD3FF: frame, writing PC, slot, new type, A0-A6
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local from = tonumber(os.getenv("SHO_FROM") or 0)
L.watch_write(0xFFC900, 0xFFD3FF, function(off, data, mask, pc)
  if (off & 0x3E) ~= 0 or L.u16(0xFFC704) & 0x7FFC ~= 0x18 or L.frame < from then return end
  local r = {}
  for i = 0, 6 do r[#r+1] = string.format("A%d=%06X", i, L.reg("A"..i) & 0xFFFFFF) end
  local o = L.u16(off & ~1); if (o & 0xFFFE) ~= 0 or (data & 0xFFFE) == 0 then return end
  print(string.format("SPAWN f=%d pc=%06X slot=%06X new=%04X old=%04X %s", L.frame, pc, off & ~1, data & 0xFFFF, L.u16(off & ~1), table.concat(r, " ")))
end)
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5600), input = input, on_frame = function(f) if f==1250 then L.mem:write_u32(0xFFB638, 0x00999999) end end }
