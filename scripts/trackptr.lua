-- Print the course/stage state and stream pointers during the race. Env: SHO_RIVAL, SHO_INPUT, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local last = ""
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC == 0x18 and f % 60 == 0 then
    local s = string.format("f=%d rival=%d C85A=%d course060C=%04X stage060A=%04X p066E=%08X p0672=%08X p0602=%08X dist0616=%04X", f, L.u16(0xFFB606), L.u16(0xFFC85A), L.u16(0xFF060C), L.u16(0xFF060A), L.u32(0xFF066E), L.u32(0xFF0672), L.u32(0xFF0602), L.u16(0xFF0616))
    print("TP " .. s)
  end
end }
