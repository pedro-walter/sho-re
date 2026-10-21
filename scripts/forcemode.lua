-- Force game_mode ($FFC704) to SHO_MODE (hex) at frame SHO_AT (default 400), snapshot every 100 frames after.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local mode = tonumber(os.getenv("SHO_MODE"), 16)
local at = tonumber(os.getenv("SHO_AT") or 400)
local tag = "fm" .. string.format("%02X", mode)
L.run{ frames=at+500,
  on_frame=function(f)
    if f == at then L.mem:write_u16(0xFFC704, mode); L.mem:write_u16(0xFFC722, 0) end
    if f > at and (f - at) % 100 == 0 then L.snapshot(string.format("%s_%d.png", tag, f - at)) end
  end }
