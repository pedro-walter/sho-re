-- Bot-collision experiment: autopilot keeps the road centre, but steers INTO the nearest backmarker bike (type $48/$49 objects at
-- $FFCC40..$FFCD7F) once it is within SHO_NEAR depth.  Logs every part-health write with PC and the bot fields.
-- Env: SHO_RIVAL, SHO_SPEED (poke speed word $FF064A, default 224), SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local rival = tonumber(os.getenv("SHO_RIVAL") or 4)
local SPEED = tonumber(os.getenv("SHO_SPEED") or 224)
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local function hp() local t = {} for i = 0, 5 do t[#t+1] = L.s16(0xFFB648 + 2*i) end return table.concat(t, ",") end
local ingame = false
L.watch_write(0xFFB648, 0xFFB653, function(off, data, mask, pc)
  if not ingame then return end
  print(string.format("HPW f=%d pc=%06X addr=%06X new=%d dist=%04X", L.frame, pc, off, (data & 0x8000) ~= 0 and (data & 0xFFFF) - 65536 or (data & 0xFFFF), L.u16(0xFF0616)))
end)
L.watch_write(0xFF0656, 0xFF0657, function(off, data, mask, pc)
  local a0 = L.reg("A0") & 0xFFFFFF
  print(string.format("CRASHREQ f=%d pc=%06X a0=%06X type=%04X sub=%d attr=%04X lat=%d x=%d z=%02X dist=%04X", L.frame, pc, a0, L.u16(a0), L.u8(a0+0x2D), L.u16(a0+2), L.s16(a0+0x2A), L.u16(a0+0x10)-0x120, L.u16(a0+0xC), L.u16(0xFF0616)))
end)
local last_hp = ""
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 20000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  if L.u16(0xFF0616) > 0 and not ingame then
    ingame = true
    for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  end
  if L.u16(0xFF0616) > 0 and L.u16(0xFF064A) < SPEED then L.mem:write_u16(0xFF064A, SPEED) end
  -- target: nearest bot ahead
  local best, bz
  for s = 0xFFCC40, 0xFFCD40, 0x40 do
    if L.u16(s) == 0x49 then
      local z, x = L.u16(s + 0xC), L.u16(s + 0x10)
      if z >= 0x30 and z <= 0xA8 and x > 0x40 and x < 0x1E0 and (not bz or z > bz) then best, bz = s, z end
    end
  end
  local c
  if best then c = L.u16(best + 0x10) - 0x120 else c = L.s16(0xFF0D00 + 2 * 0xBF) // 64 end
  L.pad({ c = true, right = c > 8, left = c < -8 })
  if best and f % 10 == 0 then print(string.format("TARGET f=%d bot=%06X z=%02X x=%d 3c=%d hp=%s", f, best, bz, L.u16(best+0x10) - 0x120, L.u8(best+0x3c), hp())) end
end }
