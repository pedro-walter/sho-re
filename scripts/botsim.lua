-- Bot movement simulation: load a race savestate, drive the bike at a fixed speed and a chosen sideways
-- position, and log EVERY frame the road state, the player's lateral position and every active bot's
-- sideways fields.  Analysis: tools/botanalyze.py.
-- Env: SHO_LOADSTATE (race1..race3), SHO_SPEED (poked speed, default 224), SHO_PLAT (player lateral target,
--      default 0), SHO_RAM=1 (steer into the nearest bot instead), SHO_FRAMES, SHO_RIVAL, SHO_SKIPLAP0 (frames to skip logging)
-- Log lines:
--   F f dist lap plat speed st nx orig    one per frame (plat = $FF0614, st = $FF067E, nx = $FF0676)
--   B n lat lane x z depth3A 3D 3E 34     one per active bot: n slot, lat=+8, lane=+$2A, x=+$10-$120, z=+$C, depth=+$26>>4,
--                                         f3A = +$3A flags, f3D = hit veer flag, f3E = veer counter, d34 = veer direction
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local LOADSTATE = os.getenv("SHO_LOADSTATE") or "race1"
local SPEED = tonumber(os.getenv("SHO_SPEED") or 224)
local PLAT  = tonumber(os.getenv("SHO_PLAT") or 0)
local RAM   = os.getenv("SHO_RAM") ~= nil
local started = false
local function log(fr, lat, v)
  print(string.format("F %d %d %d %d %d %d %d %d", fr, L.u16(0xFF0616), L.u16(0xFF060A), lat, v, L.u16(0xFF067E), L.u16(0xFF0676), L.u16(0xFFC82C)))
  for n = 0, 4 do
    local a = 0xFFCC40 + n * 0x40
    if L.u16(a) & 1 == 1 then
      print(string.format("B %d %d %d %d %d %d %d %d %d %d", n, L.s16(a + 8), L.s16(a + 0x2A), L.u16(a + 0x10) - 0x120, L.u16(a + 0xC),
        L.s16(a + 0x26) // 16, L.u8(a + 0x3A), L.u8(a + 0x3D), L.u8(a + 0x3E), L.s16(a + 0x34)))
    end
  end
end
if os.getenv("SHO_DRIVER") then
  -- let the lap autopilot (scripts/autolap5.lua, configured like tools/lap.sh) drive; we only log
  local fc = 0
  emu.register_frame_done(function()
    fc = fc + 1
    if L.u16(0xFFC704) & 0x7FFC == 0x18 and L.u16(0xFF0616) > 0 and fc > 3 then log(fc, L.s16(0xFF0614), L.u16(0xFF064A)) end
  end)
  dofile(os.getenv("SHO_ROOT").."/scripts/"..os.getenv("SHO_DRIVER"))
  return
end
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 9000), input = {}, on_frame = function(f)
  if f == 2 then manager.machine:load(LOADSTATE) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end      -- keep every part at full health
  if L.u16(0xFF0616) == 0 and not started then return end
  started = true
  local v, lat = L.u16(0xFF064A), L.s16(0xFF0614)
  if v < SPEED then L.mem:write_u16(0xFF064A, SPEED) end
  -- target: either a fixed lateral position, or the nearest bot ahead (to provoke hits)
  local tgt = PLAT
  if RAM then
    local bestz
    for s = 0xFFCC40, 0xFFCD40, 0x40 do
      if L.u16(s) & 1 == 1 then
        local z = L.u16(s + 0xC)
        if z >= 0x30 and z <= 0xA8 and (not bestz or z > bestz) then bestz = z; tgt = L.s16(s + 8) end
      end
    end
  end
  L.pad({ c = true, right = lat < tgt - 12, left = lat > tgt + 12 })
  log(L.frame, lat, v)
end }
