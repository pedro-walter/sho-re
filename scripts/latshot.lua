-- Snapshot the screen with the lateral position pinned to SHO_LAT (on the first straight, from savestate SHO_LOADSTATE) to see where the road edge is.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local lat = tonumber(os.getenv("SHO_LAT") or 0)
local t0
L.run{ frames = 700, input = {}, on_frame = function(f)
  if f == 2 then manager.machine:load(os.getenv("SHO_LOADSTATE")) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  t0 = t0 or f
  L.mem:write_u16(0xFF0614, lat & 0xFFFF)
  L.pad({ b = true })
  if f - t0 == 300 then L.snapshot(string.format("rec/lat_%d.png", lat)); print("SNAP", lat, L.u16(0xFF0616), L.u16(0xFF064A)) end
end }
