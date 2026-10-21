-- Race object / damage logger.
-- Env: SHO_FRAMES, SHO_INPUT (as play.lua), SHO_POKE (frame:addr:value[:b|w|l]), SHO_OBJEVERY=N (dump object table every N race frames)
-- Prints  HP f=<frame> pc=<pc> a0=<a0> new=<value> obj=[...]   whenever a part health word is written
-- and     OBJ f=<frame> addr type z x y f3a f3b f3c ...      for each live object slot.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local frames = tonumber(os.getenv("SHO_FRAMES") or 6000)
local every = tonumber(os.getenv("SHO_OBJEVERY") or 0)
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local pokes = {}
for fr, ad, v, sz in (os.getenv("SHO_POKE") or ""):gmatch("(%d+):(%x+):(%x+):?(%a?)") do pokes[#pokes+1] = {tonumber(fr), tonumber(ad,16), tonumber(v,16), sz} end
local shots = {}
for n in (os.getenv("SHO_SHOT") or ""):gmatch("%d+") do shots[tonumber(n)] = true end
local tag = os.getenv("SHO_TAG") or "obj"
local function obj(a)
  return string.format("%06X t=%04X z=%04X x=%04X y=%04X 3a=%02X 3b=%02X 3c=%02X 3d=%02X", a, L.u16(a), L.u16(a+0xC), L.u16(a+0x10), L.u16(a+0x14), L.u8(a+0x3a), L.u8(a+0x3b), L.u8(a+0x3c), L.u8(a+0x3d))
end
L.watch_write(0xFFB648, 0xFFB65F, function(off, data, mask, pc)
  local a0 = L.reg("A0") & 0xFFFFFF
  local o = (a0 >= 0xFFC800 and a0 < 0xFFD800) and obj(a0) or "-"
  print(string.format("HP f=%d mode=%02X pc=%06X addr=%06X new=%04X a0=%06X obj=[%s]", L.frame, L.u16(0xFFC704), pc, off, data & 0xFFFF, a0, o))
end)
L.run{ frames = frames, input = input, on_frame = function(f)
  for _, p in ipairs(pokes) do if p[1] == f then
    if p[4] == "b" then L.mem:write_u8(p[2], p[3]) elseif p[4] == "l" then L.mem:write_u32(p[2], p[3]) else L.mem:write_u16(p[2], p[3]) end end end
  if shots[f] then L.snapshot(string.format("%s_%d.png", tag, f)) end
  if every > 0 and L.u16(0xFFC704) == 0x18 and f % every == 0 then
    for a = 0xFFC940, 0xFFD7C0, 0x40 do
      if L.u16(a) ~= 0 then print("OBJ f=" .. f .. " " .. obj(a)) end
    end
  end
end }
