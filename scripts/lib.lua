-- Shared helpers for MAME Lua drivers (Super Hang-On, Genesis).
-- Usage in a script:  local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
--   L.run{ frames=N, input={{frame,"start",duration},...}, on_frame=function(f) ... end }
-- Genesis RAM is $FF0000-$FFFFFF (64 KB). All addresses are 68k bus addresses.
local L = {}
local m = manager.machine
L.root = os.getenv("SHO_ROOT")
L.out = L.root .. "/out/"
L.cpu = m.devices[":maincpu"]
L.mem = L.cpu.spaces["program"]
L.scr = m.screens[":megadriv"]
L.frame = 0

local P1 = m.ioport.ports[":ctrl1:mdpad:PAD"]
local P2 = m.ioport.ports[":ctrl2:mdpad:PAD"]
local names = { up="Up", down="Down", left="Left", right="Right", a="A", b="B", c="C", start="Start" }
local function field(port, p, btn) return port.fields["P"..p.." "..names[btn]] end

function L.u8(a)  return L.mem:read_u8(a) end
function L.u16(a) return L.mem:read_u16(a) end
function L.u32(a) return L.mem:read_u32(a) end
function L.s16(a) return L.mem:read_i16(a) end
function L.reg(n) return L.cpu.state[n].value end      -- "PC","D0".."D7","A0".."A7","SR"
function L.pc() return L.reg("CURPC") end

function L.snapshot(name) L.scr:snapshot(L.out .. name) end

function L.dump_ram(name)
  local f = assert(io.open(L.out .. name, "wb"))
  local t = {}
  for a = 0xFF0000, 0xFFFFFF, 2 do t[#t+1] = string.pack(">I2", L.mem:read_u16(a)) end
  f:write(table.concat(t)); f:close()
end

-- Press/release helper: buttons = {start=true, left=true}; player 1 (or 2)
function L.pad(buttons, p)
  p = p or 1
  local port = (p == 1) and P1 or P2
  for b in pairs(names) do field(port, p, b):set_value((buttons and buttons[b]) and 1 or 0) end
end

-- input schedule: list of {frame, "btn+btn", duration[, player]}
local function schedule_buttons(sched, f)
  local down = { {}, {} }
  for _, e in ipairs(sched or {}) do
    if f >= e[1] and f < e[1] + (e[3] or 6) then
      for b in e[2]:gmatch("%a+") do down[e[4] or 1][b] = true end
    end
  end
  return down
end

function L.run(o)
  local stop = o.frames or 600
  emu.register_frame_done(function()
    L.frame = L.frame + 1
    local down = schedule_buttons(o.input, L.frame)
    L.pad(down[1], 1); L.pad(down[2], 2)
    if o.on_frame then o.on_frame(L.frame) end
    if L.frame >= stop then
      if o.on_end then o.on_end() end
      print("finished at frame " .. L.frame)
      m:exit()
    end
  end)
end

-- tap handles must stay referenced or MAME drops the tap when Lua garbage-collects them
L.taps = {}
-- Memory write watch: cb(addr, value, pc)   range inclusive, bus addresses
function L.watch_write(lo, hi, cb)
  local t = L.mem:install_write_tap(lo, hi, "w" .. lo, function(off, data, mask)
    cb(off, data, mask, L.pc()); return data
  end)
  L.taps[#L.taps + 1] = t; return t
end
function L.watch_read(lo, hi, cb)
  local t = L.mem:install_read_tap(lo, hi, "r" .. lo, function(off, data, mask)
    cb(off, data, mask, L.pc()); return data
  end)
  L.taps[#L.taps + 1] = t; return t
end

return L
