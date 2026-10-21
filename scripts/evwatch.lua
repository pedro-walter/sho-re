-- Log writes to the $FF0602-stream event id ($FF061E) and the curve-shape state machine ($FF0730..): frame, PC, dist, value.
-- Env: SHO_RIVAL, SHO_INPUT, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
L.watch_write(0xFF061E, 0xFF061F, function(off, data, mask, pc)
  print(string.format("EV f=%d pc=%06X dist=%04X idx0606=%04X val=%04X st4=%02X", L.frame, pc, L.u16(0xFF0616), L.u16(0xFF0606), data & 0xFFFF, L.u8(0xFF0734)))
end)
L.watch_write(0xFF0734, 0xFF0735, function(off, data, mask, pc)
  if off % 2 == 0 and (data >> 8) & 0xFF == L.u8(0xFF0734) then return end
  print(string.format("SM f=%d pc=%06X dist=%04X id=%04X -> %04X road_state=%d", L.frame, pc, L.u16(0xFF0616), L.u16(0xFF061E), data & 0xFFFF, L.u16(0xFF067E)))
end)
local SPEED = tonumber(os.getenv("SHO_SPEED") or 0)
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if SPEED > 0 and L.u16(0xFF0616) > 0 and L.u16(0xFF064A) < SPEED and L.u16(0xFFC704) & 0x7FFC == 0x18 then L.mem:write_u16(0xFF064A, SPEED) end
  if L.u16(0xFFC704) & 0x7FFC == 0x18 then for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end end
  if os.getenv("SHO_SNAP") and f % tonumber(os.getenv("SHO_SNAP")) == 0 and L.u16(0xFFC704) & 0x7FFC == 0x18 and f > 4300 then L.snapshot(string.format("ev/seq_%05d.png", f)); print(string.format("SNAP f=%d dist=%d sm4=%02X off8=%d road_state=%d rad=%d", f, L.u16(0xFF0616), L.u8(0xFF0734), L.u16(0xFF0738), L.u16(0xFF067E), L.u16(0xFF0682))) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if f % 300 == 0 and L.u16(0xFFC704) & 0x7FFC == 0x18 then print(string.format("S f=%d dist=%04X 060E=%04X 0606=%04X sm4=%02X C=%08X speed=%d", f, L.u16(0xFF0616), L.u16(0xFF060E), L.u16(0xFF0606), L.u8(0xFF0734), L.u32(0xFF073C), L.u16(0xFF064A))) end
end }
