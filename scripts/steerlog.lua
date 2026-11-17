-- Probe for the exact steering/lateral model: drives with scripted pad input (hold throttle) and logs per frame the handlebar, steer_out,
-- lean ($38(a0)), lateral, speed, distance, push buffers, and every write to the lateral position (frame, pc, a0).
-- Env: SHO_LOADSTATE (race1..3), SHO_TIRE SHO_FRAME SHO_OIL SHO_ENGINE (tiers), SHO_FRAMES, SHO_PAT (input pattern "L40,N30,R20,..."), SHO_TAG
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local LOADSTATE = os.getenv("SHO_LOADSTATE")
local T, F, E, O = tonumber(os.getenv("SHO_TIRE") or 0), tonumber(os.getenv("SHO_FRAME") or 0), tonumber(os.getenv("SHO_ENGINE") or 0), tonumber(os.getenv("SHO_OIL") or 0)
local TAG = os.getenv("SHO_TAG") or "SL"
local pat = {}
for c, n in (os.getenv("SHO_PAT") or "N60,L60,N30,R60,N30"):gmatch("(%a)(%d+)") do pat[#pat + 1] = { c, tonumber(n) } end
local a0, wr = nil, {}
L.watch_write(0xFF0614, 0xFF0615, function(off, data, mask, pc) local dl = data - L.s16(0xFF0614); if dl > 32767 then dl = dl - 65536 elseif dl < -32768 then dl = dl + 65536 end; wr[#wr + 1] = string.format("%X:%d", pc, dl) end)
local started, t0 = false, nil
local function input_at(k)
  local tot = 0; for _, p in ipairs(pat) do tot = tot + p[2] end
  local x = k % tot
  for _, p in ipairs(pat) do if x < p[2] then return p[1] end; x = x - p[2] end
  return "N"
end
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 3000), on_frame = function(f)
  if LOADSTATE and f == 2 then manager.machine:load(LOADSTATE) end
  for a = 0xFFCC40, 0xFFCD40, 0x40 do L.mem:write_u16(a, 0) end; L.mem:write_u16(0xFF0690, 0)
  local mode = L.u16(0xFFC704) & 0x7FFC
  if mode ~= 0x18 then return end
  if os.getenv('SHO_VFIX') then L.mem:write_u16(0xFF064A, tonumber(os.getenv('SHO_VFIX'))) end
  L.mem:write_u16(0xFFB618, F); L.mem:write_u16(0xFFB61A, E); L.mem:write_u16(0xFFB620, O); L.mem:write_u16(0xFFB622, T)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2 * i, 15) end
  if L.u16(0xFF0616) == 0 and not started then return end
  started = true; t0 = t0 or f
  local k = f - t0
  local c = input_at(k)
  L.pad({ b = true, left = (c == "L"), right = (c == "R") })
  -- state at the END of the previous frame's processing (read at frame_done) with the input applied during the NEXT frame
  local lean = L.s16(0xFFC978)
  print(string.format("%s K %d in=%s hb=%d so=%d lean=%d lat=%d v=%d d=%d skid=%d D=%d,%d sk=%d wr=%s", TAG, k, c, L.u16(0xFFC73C), L.s16(0xFF063A), lean, L.s16(0xFF0614), L.u16(0xFF064A), L.u16(0xFF0616), L.u16(0xFF066A), L.s16(0xFF0BA6), L.s16(0xFF0CB8), L.u16(0xFF065A), table.concat(wr, ",")))
  wr = {}
end }
