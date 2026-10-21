-- Print game mode ($FFC704) every 200 frames. Env: SHO_RIVAL, SHO_INPUT, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if f % 200 == 0 then print(string.format("M f=%d mode=%04X rival=%d", f, L.u16(0xFFC704), L.u16(0xFFC85A))) end
end }
