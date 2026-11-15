-- Engine top speed with the speed unpinned: lateral position forced to 0 every frame (no skid), B held, optional C (SHO_TURBO).
-- Logs speed every SHO_STEP frames after the race start, prints the peak. Env: SHO_ENGINE SHO_OIL SHO_MUF SHO_TURBO SHO_STEP SHO_RIVAL SHO_INPUT SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local e, o, m = tonumber(os.getenv("SHO_ENGINE") or 0), tonumber(os.getenv("SHO_OIL") or 0), tonumber(os.getenv("SHO_MUF") or 0)
local t0, peak, pk = nil, 0, 0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 9000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, tonumber(os.getenv("SHO_RIVAL") or 0)) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  L.mem:write_u16(0xFFB61A, e); L.mem:write_u16(0xFFB61E, m); L.mem:write_u16(0xFFB620, o)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 and not t0 then return end
  t0 = t0 or f
  local k = f - t0
  L.mem:write_u16(0xFF0614, 0)
  L.pad({ b = true, c = os.getenv("SHO_TURBO") ~= nil })
  local v = L.u16(0xFF064A)
  if v > peak then peak = v; pk = k end
  if k % tonumber(os.getenv("SHO_STEP") or 120) == 0 then print(string.format("TS e=%d k=%d speed=%d peak=%d@%d lap=%d disp=%x", e, k, v, peak, pk, L.u16(0xFF060A), L.u16(0xFF055A))) end
end }
print("TS PEAK", peak, pk)
