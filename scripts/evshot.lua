-- Force a $FF061E event id (the $FF0602-stream scenery/curve-shape event) at a chosen race frame and screenshot its progress.
-- Env: SHO_RIVAL, SHO_EVID, SHO_INPUT, SHO_FRAMES. Writes out/ev/id<N>_<k>.png and prints state lines.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local id = tonumber(os.getenv("SHO_EVID") or 1)
local t0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5600), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  if f > 4300 and not t0 and L.u16(0xFF0616) > 0x10 and L.u8(0xFF0734) == 0 then
    t0 = f; L.mem:write_u16(0xFF061E, id); L.snapshot(string.format("ev/id%d_0.png", id))
  end
  if t0 and (f - t0) % 60 == 0 and f > t0 then
    L.snapshot(string.format("ev/id%d_%d.png", id, (f - t0) // 60))
    print(string.format("EVS f=%d id=%d sm4=%02X off8=%08X 0606=%04X dist=%04X", f, id, L.u8(0xFF0734), L.u32(0xFF0738), L.u16(0xFF0606), L.u16(0xFF0616)))
  end
end }
