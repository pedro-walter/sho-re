-- Lateral offset vs speed/gain in curves: while the road is in a curve (road_state $FF067E = 2/3) the lateral position $FF0614 is
-- forced every frame to SHO_LAT toward the inside (state 3: +, state 2: -); throttle held. Logs per 30 curve frames.
-- Env: SHO_LAT (default 0), SHO_RIVAL, SHO_INPUT, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 3)
local lat = tonumber(os.getenv("SHO_LAT") or 0)
local v0 = tonumber(os.getenv("SHO_V0") or 0)   -- poke the speed once when the first curve frame is reached
local exs, exl = (os.getenv("SHO_EXC") or "0:0"):match("(%d+):(%d+)")   -- SHO_EXC=start:len curve-frame window where the lateral position is 310 instead
exs, exl = tonumber(exs), tonumber(exl)
local n, sg, sv, sk, prev = 0, 0, 0, 0, nil
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 7000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  if L.u16(0xFFC704) & 0x7FFC ~= 0x18 then return end
  for i = 0, 4 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 then return end
  L.pad({ [os.getenv("SHO_BTN") or "c"] = true })
  local st = L.u16(0xFF067E)
  if st == 2 or st == 3 then
    if v0 > 0 and n == 0 then L.mem:write_u16(0xFF064A, v0) end
    local l2 = (n >= exs and n < exs + exl) and 310 or lat
    local v = (st == 3) and l2 or -l2
    L.mem:write_u16(0xFF0614, v & 0xFFFF)
    n = n + 1; sg = sg + L.u32(0xFF0646); sv = sv + L.u16(0xFF064A); sk = sk + (L.u16(0xFF066A) ~= 0 and 1 or 0)
    if n % 15 == 0 then
      print(string.format("LP lat=%d f=%d speed=%d avg_gain=%d skid_frac=%.2f f65a=%04X state=%d radius=%d", lat, f, sv // 15, sg // 15, sk / 15, L.u16(0xFF065A), st, L.u16(0xFF0682)))
      sg, sv, sk = 0, 0, 0
    end
  end
end }
