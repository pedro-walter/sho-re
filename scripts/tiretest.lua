-- Tire tier vs lateral response: poke the installed tire tier ($B622) and steer for a fixed time on the straight start.
-- Env: SHO_TIER (0..4), SHO_STEER (left|right, default right), SHO_RIVAL, SHO_INPUT (shop/start sequence), SHO_FRAMES
-- After the race has run for SHO_WAIT frames (default 250) the pad is held for SHO_HOLD frames (default 90) while $FF0614 (lateral), speed and $38(a0) are logged.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 3)
local tier = tonumber(os.getenv("SHO_TIER") or 0)
local steer = os.getenv("SHO_STEER") or "right"
local wait, hold = tonumber(os.getenv("SHO_WAIT") or 250), tonumber(os.getenv("SHO_HOLD") or 90)
local t0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5200), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  L.mem:write_u16(0xFFB622, tier)
  for i = 0, 4 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  local k = f - t0
  if k >= wait and k < wait + hold then L.pad({ c = true, [steer] = true }) elseif k >= wait + hold then L.pad({ c = true }) end
  if k >= wait and k % 10 == 0 and k < wait + hold + 60 then
    print(string.format("TT tier=%d k=%d lat=%d speed=%d lean38=%d skid=%d", tier, k - wait, L.s16(0xFF0614), L.u16(0xFF064A), L.s16(0xFFC900 + 0x40 + 0x38), L.u16(0xFF066A)))
  end
end }
