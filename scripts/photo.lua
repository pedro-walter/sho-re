-- Roadside-object photographer: drives an Original-mode race for SHO_RIVAL (poked in the shop) holding the throttle and takes one
-- screenshot (out/photo/r<rival>_s<subtype>_a<attr>.png) the first time each (subtype, sprite attr) pair of a static object (type $34)
-- is close and on screen.  Prints PHOTO lines: file subtype attr x y z.   Env: SHO_RIVAL, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local seen = {}
local SPEED = tonumber(os.getenv("SHO_SPEED") or 0)   -- poke speed ($FF064A, long) to this value to cover the lap faster
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 20000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  if os.getenv("SHO_AUTO") and f > 4300 then      -- autopilot: keep the road centre ($FF0D00 table at z=$BF) under the bike
    local c = L.s16(0xFF0D00 + 2 * 0xBF) // 64
    L.pad({ c = true, right = c > 14, left = c < -14 })
    if f % 120 == 0 then print(string.format("AUTO f=%d c=%d dist=%04X spd=%04X", f, c, L.u16(0xFF0616), L.u16(0xFF064A))) end
  end
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end   -- keep the parts healthy so crashes never retire the run
  if SPEED > 0 and L.u16(0xFF0616) > 0 and L.u16(0xFF064A) < SPEED then L.mem:write_u16(0xFF064A, SPEED) end   -- optional speed boost
  for s = 0xFFCE00, 0xFFD0FF, 0x40 do
    if L.u16(s) & 0xFFFE == 0x34 then
      local z, x, y = L.u16(s + 0xC), L.u16(s + 0x10), L.u16(s + 0x14)
      local sub, attr = L.u8(s + 0x2D), L.u16(s + 2)
      local sx = x - 0x80
      local key = sub * 65536 + attr
      if z >= 0x20 and z <= 0xC0 and sx > 24 and sx < 296 and (seen[key] or 0) < z then   -- keep the closest on-screen shot of each kind
        seen[key] = z
        local name = string.format("photo2/r%d_s%d_a%04X.png", rival, sub, attr)
        L.snapshot(name)
        print(string.format("PHOTO %s sub=%d attr=%04X x=%d y=%d z=%02X f=%d dist=%04X", name, sub, attr, sx, y - 0x80, z, f, L.u16(0xFF0616)))
      end
    end
  end
end }
