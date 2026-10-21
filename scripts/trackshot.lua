-- Race rival SHO_RIVAL and screenshot the road at fixed frames (to check a patched ROM). Env: SHO_RIVAL, SHO_TAG, SHO_INPUT, SHO_FRAMES, SHO_SPEED
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival, tag = tonumber(os.getenv("SHO_RIVAL") or 0), os.getenv("SHO_TAG") or "t"
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if f % 150 == 0 and f > 4300 then
    L.snapshot(string.format("ev/%s_%05d.png", tag, f))
    print(string.format("TS f=%d course=%d stage=%d dist=%d road_ptr=%06X p0602=%06X p066E=%06X", f, L.u16(0xFF060C), L.u16(0xFF060A), L.u16(0xFF0616), L.u32(0xFF0672), L.u32(0xFF0602), L.u32(0xFF066E)))
  end
end }
