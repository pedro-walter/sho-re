-- Experiment: poke the LCG state, force the shop "race finished" roll, print state before/after and the mechanic roll.
-- Env: SHO_MECH, SHO_STATE (hex 32-bit, default none), SHO_AT
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local mech = tonumber(os.getenv("SHO_MECH") or 0)
local at = tonumber(os.getenv("SHO_AT") or 400)
local st = os.getenv("SHO_STATE") and tonumber(os.getenv("SHO_STATE"), 16)
local function u32(a) return (L.u16(a) << 16) | L.u16(a+2) end
L.run{ frames = at + 400, on_frame = function(f)
  if f == at - 1 then print(string.format("PRE_RNG state=%08X", u32(0xFF0502))) end
  if f == at then
    for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 8) end
    L.mem:write_u16(0xFFB60A, mech)
    L.mem:write_u8(0xFFB655, 2)
    if st then L.mem:write_u16(0xFF0502, st >> 16); L.mem:write_u16(0xFF0504, st & 0xFFFF) end
    L.mem:write_u16(0xFFC704, 0x24); L.mem:write_u16(0xFFC722, 0)
  end
  if f == at + 399 then print(string.format("RESULT mech=%d poked=%s state_after=%08X b656=%04X hp=%d", mech, os.getenv("SHO_STATE") or "-", u32(0xFF0502), L.u16(0xFFB656), L.s16(0xFFB648))) end
end }
