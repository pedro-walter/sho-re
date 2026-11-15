-- Launch acceleration vs engine/oil/muffler tiers: poke the tiers ($B61A engine, $B61E muffler, $B620 oil), hold the throttle (B)
-- from the start of the race and log speed ($FF064A, high word) every 30 frames after the race begins ($FF0616 != 0).
-- Env: SHO_V0 (poke speed at k=0), SHO_TURBO (hold C), SHO_STEP (log interval), SHO_ENGINE, SHO_OIL, SHO_MUF (tiers), SHO_RIVAL, SHO_INPUT, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 3)
local e, o, m = tonumber(os.getenv("SHO_ENGINE") or 0), tonumber(os.getenv("SHO_OIL") or 0), tonumber(os.getenv("SHO_MUF") or 0)
local t0
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 5600), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  L.mem:write_u16(0xFFB61A, e); L.mem:write_u16(0xFFB61E, m); L.mem:write_u16(0xFFB620, o)
  for i = 0, 4 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  t0 = t0 or f
  local k = f - t0
  if os.getenv("SHO_V0") and k == 60 then L.mem:write_u16(0xFF064A, tonumber(os.getenv("SHO_V0"))) end
  L.pad({ b = true, c = os.getenv("SHO_TURBO") ~= nil })
  if k % (tonumber(os.getenv("SHO_STEP") or 30)) == 0 and k <= tonumber(os.getenv("SHO_LOGMAX") or 900) then
    print(string.format("AC e=%d o=%d m=%d k=%d speed=%d dist=%d thr=%d tgt=%d", e, o, m, k, L.u16(0xFF064A), L.u16(0xFF0616), L.u16(0xFF063E), L.u16(0xFFC73E)))
  end
end }
