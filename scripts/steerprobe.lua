-- Steering response on a straight at pinned speed: hold SHO_DIR (left|right) from k=SHO_T0 for SHO_HOLD frames, then release.
-- Logs lateral position, its per-frame change, steer_out ($FF063A) and handlebar ($FFC73E) every frame in the window.
-- Env: SHO_V (speed), SHO_TIER (tire), SHO_DIR, SHO_T0 (default 100), SHO_HOLD (default 40), SHO_RIVAL
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local v, tier = tonumber(os.getenv("SHO_V") or 150), tonumber(os.getenv("SHO_TIER") or 0)
local dir, t0w, hold = os.getenv("SHO_DIR") or "left", tonumber(os.getenv("SHO_T0") or 100), tonumber(os.getenv("SHO_HOLD") or 40)
local t0, plat = nil, 0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5200), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  L.mem:write_u16(0xFFB622, tier)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  local k = f - t0
  local pd = { b = true }
  if k > 80 then L.mem:write_u16(0xFF064A, v) end
  if k >= t0w and k < t0w + hold then pd[dir] = true end
  L.pad(pd)
  local lat = L.s16(0xFF0614)
  if k >= t0w - 2 and k < t0w + hold + 40 then
    print(string.format("SP tier=%d v=%d k=%d pad=%s lat=%d dlat=%d steer_out=%d hb=%d", tier, v, k, (k >= t0w and k < t0w + hold) and dir or "-", lat, lat - plat, L.s16(0xFF063A), L.u16(0xFFC73E)))
  end
  plat = lat
end }
