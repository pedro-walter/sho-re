-- Experiment: enter the Original-mode shop "as if a race just ended" and see how part health changes.
-- Env: SHO_MECH=0..6 (mechanic level $FFB60A), SHO_AT=frame to trigger, SHO_H="8,8,8,8,8,8" initial healths
-- Prints: RESULT mech at before after b656
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local mech = tonumber(os.getenv("SHO_MECH") or 0)
local at = tonumber(os.getenv("SHO_AT") or 400)
local H = {}
for n in (os.getenv("SHO_H") or "8,8,8,8,8,8"):gmatch("%-?%d+") do H[#H+1] = tonumber(n) end
local function hs() local t = {} for i = 0, 5 do t[#t+1] = L.s16(0xFFB648 + 2*i) end return table.concat(t, ",") end
L.run{ frames = at + 400, on_frame = function(f)
  if f == at then
    for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, H[i+1] & 0xFFFF) end
    L.mem:write_u16(0xFFB60A, mech)
    L.mem:write_u8(0xFFB655, 2)           -- race-completed flag (bit 1)
    L.mem:write_u16(0xFFC704, 0x24); L.mem:write_u16(0xFFC722, 0)
  end
  if f == at + 399 then print(string.format("RESULT mech=%d at=%d before=%s after=%s b656=%04X", mech, at, os.getenv("SHO_H") or "8,8,8,8,8,8", hs(), L.u16(0xFFB656))) end
end }
