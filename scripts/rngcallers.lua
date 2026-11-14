-- Logs every call of rng ($84C2): frame marker lines "F n" and "RNG ret=.. a0=.. a5=.." (return address = caller + 2/4).
-- A debugger breakpoint on $84C2 whose action does `logerror`; needs the -oslog flag: tools/mame.sh scripts/rngcallers.lua -oslog
-- (printf in a bp action prints nowhere headless; logerror + -oslog does; a7 in expressions is the hex number $A7, use sp).
-- Env: SHO_INPUT as play.lua, SHO_FRAMES. Money is poked at frame 1250 (as orig_race needs). Post-process with tools/rngsummary.py.
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):([%a+]+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
L.cpu.debug:bpset(0x84C2, "1", 'logerror "RNG ret=%06X a0=%06X a5=%06X mode=%04X\\n",d@(sp),a0,a5,w@ffc704; g')
local frames = tonumber(os.getenv("SHO_FRAMES") or 9000)
L.run{ frames = frames, input = input,
  on_frame = function(f)
    print("F "..f)
    if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  end }
