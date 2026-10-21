-- Bot lane behaviour: every SHO_EVERY frames in the race loop log road state and each active bot's fields.
-- Env: SHO_RIVAL, SHO_INPUT, SHO_FRAMES, SHO_EVERY
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local every = tonumber(os.getenv("SHO_EVERY") or 10)
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC == 0x18 and f % every == 0 then
    local s = string.format("R f=%d dist=%04X lap=%d st=%d nxt=%d slip=%d speed=%d rad=%d adv=%d", f, L.u16(0xFF0616), L.u16(0xFF060A), L.u16(0xFF067E), L.u16(0xFF0676), L.s16(0xFF0614), L.u16(0xFF064A), L.u16(0xFF0682), L.u32(0xFF0646))
    print(s)
    for a = 0xFFCC40, 0xFFCD40, 0x40 do
      if L.u16(a) & 1 == 1 then
        print(string.format("  B %04X type=%04X lat8=%d tgt2A=%d z=%X x=%d f3A=%02X f3B=%02X f3D=%02X v0A=%d w30=%d w32=%d acc26=%d m3C=%d", a, L.u16(a), L.s16(a+8), L.s16(a+0x2A), L.u16(a+0xC), L.s16(a+0x10), L.u8(a+0x3A), L.u8(a+0x3B), L.u8(a+0x3D), L.s16(a+0xA), L.s16(a+0x30), L.s16(a+0x32), L.s16(a+0x26), L.u8(a+0x3C)))
      end
    end
  end
end }
