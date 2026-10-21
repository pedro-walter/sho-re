-- Generic driver. Env: SHO_INPUT="frame:btn+btn:dur,..."  SHO_SHOT="every N" or "f1,f2,.."  SHO_FRAMES=N
--   SHO_DUMP="f1,f2" (RAM dumps out/ram_<f>.bin)  SHO_TAG=name (file prefix)
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local tag = os.getenv("SHO_TAG") or "play"
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):([%a+]+):?(%d*)") do
  input[#input+1] = {tonumber(fr), b, tonumber(d) or 6}
  if d == "" then input[#input][3] = 6 end
end
local function set(s) local t = {} for n in (s or ""):gmatch("%d+") do t[tonumber(n)] = true end return t end
local every = tonumber((os.getenv("SHO_SHOT") or ""):match("^every (%d+)$"))
local shots, dumps = set(os.getenv("SHO_SHOT")), set(os.getenv("SHO_DUMP"))
if os.getenv("SHO_COV") then  -- coverage: stream every executed PC into a FIFO (tools/cov.sh reads it)
  manager.machine.debugger:command('trace '..os.getenv("SHO_COV")..',maincpu,noloop,{tracelog "%06X\\n",curpc}')
end
-- SHO_POKE="frame:addr:value[:size],..." (hex addr/value, size b/w/l default w) writes RAM at that frame
local pokes = {}
for fr, ad, v, sz in (os.getenv("SHO_POKE") or ""):gmatch("(%d+):(%x+):(%x+):?(%a?)") do
  pokes[#pokes+1] = {tonumber(fr), tonumber(ad,16), tonumber(v,16), sz ~= "" and sz or "w"}
end
-- SHO_LOG="FFB602,FFB604" SHO_LOGEVERY=100: print those words periodically
local logs = {}
for a in (os.getenv("SHO_LOG") or ""):gmatch("%x+") do logs[#logs+1] = tonumber(a,16) end
local logevery = tonumber(os.getenv("SHO_LOGEVERY") or 100)
L.run{ frames=tonumber(os.getenv("SHO_FRAMES") or 1500), input=input,
  on_frame=function(f)
    for _, p in ipairs(pokes) do
      if p[1] == f then
        if p[4] == "b" then L.mem:write_u8(p[2], p[3]) elseif p[4] == "l" then L.mem:write_u32(p[2], p[3]) else L.mem:write_u16(p[2], p[3]) end
      end
    end
    if #logs > 0 and f % logevery == 0 then
      local t = {}
      for _, a in ipairs(logs) do t[#t+1] = string.format("%06X=%04X", a, L.u16(a)) end
      print(string.format("f%05d %s", f, table.concat(t, " ")))
    end
    if shots[f] or (every and f % every == 0) then L.snapshot(string.format("%s_%05d.png", tag, f)) end
    if dumps[f] then L.dump_ram(string.format("%s_ram_%05d.bin", tag, f)) end
  end }
