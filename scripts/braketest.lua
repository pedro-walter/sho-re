-- Deceleration test on a straight: pin speed SHO_V at k=100, then from k=120 either release the throttle (SHO_MODE=coast)
-- or hold the brake A (SHO_MODE=brake), log the speed every 10 frames. Env: SHO_V, SHO_MODE, SHO_ENGINE, SHO_RIVAL
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local v, mode, e = tonumber(os.getenv("SHO_V") or 240), os.getenv("SHO_MODE") or "coast", tonumber(os.getenv("SHO_ENGINE") or 0)
local t0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5200), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  L.mem:write_u16(0xFFB61A, e)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  local k = f - t0
  if k < 120 then L.pad({ b = true }); if k >= 100 then L.mem:write_u16(0xFF064A, v) end return end
  local pd = {}
  if mode == "brake" then pd.a = true elseif mode == "coastB" then pd.b = true end
  L.pad(pd)
  if k % 10 == 0 and k <= 400 then print(string.format("BT mode=%s k=%d speed=%d dist=%d thr=%d tgt=%d f642=%d f65a=%d", mode, k, L.u16(0xFF064A), L.u16(0xFF0616), L.u16(0xFF063E), L.u16(0xFFC73E), L.u16(0xFF0642), L.u16(0xFF065A))) end
end }
