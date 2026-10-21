-- Write watch. Env: SHO_WATCH="FFC704-FFC705,FFC722" (hex ranges), plus the play.lua env (SHO_INPUT, SHO_FRAMES, ...)
-- Prints "frame pc addr = value(size)" for each write whose value changes (SHO_ALL=1: every write).
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):([%a+]+):?(%d*)") do
  input[#input+1] = {tonumber(fr), b, tonumber(d) or 6}
end
local last = {}
local snapat = {}
local all = os.getenv("SHO_ALL") == "1"
for spec in (os.getenv("SHO_WATCH") or ""):gmatch("[^,]+") do
  local lo, hi = spec:match("(%x+)-?(%x*)")
  if hi == "" then hi = lo end
  lo = tonumber(lo, 16); hi = tonumber(hi, 16)
  L.watch_write(lo, hi, function(off, data, mask, pc)
    local a = off
    local v = L.u16(a & ~1)
    -- bus write taps report the offset and the data being written; read back after the write is not
    -- available yet, so print the raw data/mask
    local key = off .. ":" .. data
    if all or last[off] ~= data then
      last[off] = data
      print(string.format("f%05d pc=%06X [%06X] <- %04X mask=%04X", L.frame, pc, off, data & 0xFFFF, mask & 0xFFFF))
      -- SHO_SNAP=1: screenshots at the write and 15/40 frames later
      if os.getenv("SHO_SNAP") == "1" then snapat[L.frame] = true; snapat[L.frame + 15] = true; snapat[L.frame + 40] = true end
    end
  end)
end
L.run{ frames=tonumber(os.getenv("SHO_FRAMES") or 1500), input=input,
  on_frame=function(f) if snapat[f] then L.snapshot(string.format("w_%05d.png", f)) end end }
