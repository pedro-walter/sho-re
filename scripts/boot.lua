-- Smoke test: boot, press Start a few times, snapshot every 300 frames.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
L.run{ frames=1500,
  input={{300,"start",5},{600,"start",5},{900,"start",5}},
  on_frame=function(f) if f%300==0 then L.snapshot(string.format("boot_%04d.png",f)); print(f, string.format("PC=%06X",L.pc())) end end,
  on_end=function() L.dump_ram("ram_boot.bin") end }
