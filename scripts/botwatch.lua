-- Bot slots ($FFCC40..$FFCD7F): log every write to the type word (+0): frame, PC, slot, old->new, A0-A6, dist counter
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
L.watch_write(0xFFCC40, 0xFFCD7F, function(off, data, mask, pc)
  if (off & 0x3E) ~= 0 then return end
  local r = {}
  for i = 0, 6 do r[#r+1] = string.format("A%d=%06X", i, L.reg("A"..i) & 0xFFFFFF) end
  print(string.format("BOT f=%d dist=%04X lap=%d pc=%06X slot=%06X old=%04X new=%04X %s", L.frame, L.u16(0xFF0616), L.u16(0xFF060A), pc, off & ~1, L.u16(off & ~1), data & 0xFFFF, table.concat(r, " ")))
end)
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5600), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 3600 then L.mem:write_u16(0xFFB606, tonumber(os.getenv("SHO_RIVAL") or 0)) end
end }
