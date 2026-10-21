-- Edge screenshots in a sharp curve with the bike steered fully into it.
-- Waits for the first curve with radius <= SHO_MAXR (default 50), forces lateral position SHO_LAT toward the inside every frame of the curve,
-- holds SHO_STEER (left|right; default: the inside of the curve) and saves out/edge/sharp_<rival>_lat<LAT>_<k>.png at SHO_K frames (comma list) into the curve.
-- Env: SHO_RIVAL, SHO_LAT, SHO_MAXR, SHO_K, SHO_STEER, SHO_V0 (speed poked when the curve starts), SHO_INPUT, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local lat = tonumber(os.getenv("SHO_LAT") or 0)
local maxr = tonumber(os.getenv("SHO_MAXR") or 50)
local v0 = tonumber(os.getenv("SHO_V0") or 100)
local ks = {}
for k in (os.getenv("SHO_K") or "30"):gmatch("%d+") do ks[tonumber(k)] = true end
local n, active = 0, false
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 9000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  for i = 0, 4 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  local st, r = L.u16(0xFF067E), L.u16(0xFF0682)
  local pd = { b = true }
  local inCurve = (st == 2 or st == 3) and r > 0 and r <= maxr
  if inCurve and not active then active = true; n = 0; L.mem:write_u16(0xFF064A, v0); print(string.format("CURVE start f=%d dist=%d state=%d radius=%d", f, L.u16(0xFF0616), st, r)) end
  if active and not inCurve then active = false end
  if active then
    n = n + 1
    local cur = L.s16(0xFF0614)   -- value the game computed for the frame being displayed (before we overwrite it)
    local sgn = (st == 3) and 1 or -1
    L.mem:write_u16(0xFF0614, (sgn * lat) & 0xFFFF)
    local steer = os.getenv("SHO_STEER") or ((st == 3) and "left" or "right")
    pd[steer] = true
    if ks[n] then L.snapshot(string.format("edge/sharp_r%d_lat%d_k%d.png", rival, lat, n)); print(string.format("SNAP k=%d lat=%d speed=%d lean=%d state=%d radius=%d skid=%d lat_shown=%d", n, lat, L.u16(0xFF064A), L.s16(0xFFC900 + 0x40 + 0x38), st, r, L.u16(0xFF066A), cur)) end
  end
  L.pad(pd)
end }
