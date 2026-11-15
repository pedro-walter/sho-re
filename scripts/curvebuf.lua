-- Road curvature term behind the outward push (sub_00EA24): D = word[$FF0BA6] - word[$FF0CB8] (turbo flag $FF0510: word[$FF0B8C]),
-- Dc = D/64 truncated, push per frame = 2*(trunc(Dc*speed/110) + sign). Logs per curve segment (rival 0) with the speed pinned to SHO_V.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local v = tonumber(os.getenv("SHO_V") or 200)
local t0
local function s16(x) if x >= 0x8000 then return x - 0x10000 end return x end
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 8000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  L.pad({ b = true })
  if f - t0 > 80 then L.mem:write_u16(0xFF064A, v) end
  L.mem:write_u16(0xFF0614, 0)
  if (f - t0) % 6 == 0 then
    local D = s16(L.u16(0xFF0BA6)) - s16(L.u16(0xFF0CB8))
    print(string.format("CB d=%d st=%d r=%d D=%d Dc=%d", L.u16(0xFF0616), L.u16(0xFF067E), L.u16(0xFF0682), D, (D >= 0) and (D // 64) or -((-D) // 64)))
  end
end }
