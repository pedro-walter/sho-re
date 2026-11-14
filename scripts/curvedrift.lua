-- Does a curve push the bike outward? Hold throttle (B), keep speed fixed at SHO_V (poked every frame), NO steering, tire tier SHO_TIER;
-- SHO_STEER=left|right holds the pad; log lateral position $FF0614, road state $FF067E/radius $FF0682, skid and distance every SHO_STEP frames.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local v, tier, frame = tonumber(os.getenv("SHO_V") or 200), tonumber(os.getenv("SHO_TIER") or 0), tonumber(os.getenv("SHO_FRAMETIER") or 0)
local step = tonumber(os.getenv("SHO_STEP") or 20)
local t0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5800), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  L.mem:write_u16(0xFFB622, tier); L.mem:write_u16(0xFFB618, frame)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  local k = f - t0
  local pd = { b = true }; local st = os.getenv("SHO_STEER"); if st and L.u16(0xFF067E) ~= 1 then pd[st] = true end; L.pad(pd)
  if k > 80 then L.mem:write_u16(0xFF064A, v) end
  if k > 80 and k % step == 0 then
    print(string.format("CD tier=%d v=%d k=%d dist=%d state=%d radius=%d lat=%d skid=%d lean=%d", tier, v, k, L.u16(0xFF0616), L.u16(0xFF067E), L.u16(0xFF0682), L.s16(0xFF0614), L.u16(0xFF066A), L.s16(0xFFC900+0x38)))
  end
end }
