-- Outward push vs lateral position: pin the speed SHO_V, no steering; when the first curve frame is reached poke the lateral
-- position to SHO_X, then log the position every frame for SHO_N frames (push = change per frame). Env: SHO_V, SHO_X, SHO_N, SHO_RIVAL
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local v, X, N = tonumber(os.getenv("SHO_V") or 200), tonumber(os.getenv("SHO_X") or 0), tonumber(os.getenv("SHO_N") or 45)
local CURVE = tonumber(os.getenv("SHO_CURVE") or 1)
local t0, c0, ncurve, lastkey = nil, nil, 0, nil
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5800), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  L.pad({ b = true })
  if f - t0 > 80 then L.mem:write_u16(0xFF064A, v) end
  local st = L.u16(0xFF067E)
  local key = st * 10000 + L.u16(0xFF0682)
  if (st == 3 or st == 2) and key ~= lastkey and not c0 then ncurve = ncurve + 1 end
  lastkey = key
  if (st == 3 or st == 2) and ncurve == CURVE then
    c0 = c0 or f
    local c = f - c0
    if c == 20 then L.mem:write_u16(0xFF0614, X & 0xFFFF) end
    if c > 20 and c <= 20 + N then print(string.format("PP v=%d x=%d c=%d st=%d r=%d lat=%d skid=%d", v, X, c, st, L.u16(0xFF0682), L.s16(0xFF0614), L.u16(0xFF066A))) end
    if c > 20 + N then manager.machine:exit() end
  end
end }
