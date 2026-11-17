-- Headless: replay the planner on a captured state. Env: SHO_ST="hb,so,lean,lat,v,dist" SHO_T0 target, track 1 profile + segments from env SHO_SEGS "start:state:r,..."
local root = os.getenv("SHO_ROOT")
local prof = dofile(root .. "/data/roadprofile_track1.lua")
local segs = { { 0, 1, 0 } }
for a, b, c in (os.getenv("SHO_SEGS") or ""):gmatch("(%d+):(%d+):(%d+)") do segs[#segs + 1] = { tonumber(a), tonumber(b), tonumber(c) } end
local function seg(d) local r = segs[1]; for i = 1, #segs do if d >= segs[i][1] then r = segs[i] end end; return r end
local M = dofile(root .. "/scripts/model6.lua").new{
  tire = 0, frame = 0, mult = 3, vmax = 241, pred = true, hold_h = 9, hold_h2 = 15,
  profile = function(d) return prof[math.floor(d) % 2048 + 1] or 0 end,
  road = function(d) local s = seg(d); return s[2], s[3] end,
  speed_cmd = function() return false, true end }
M.VLATMAX = 22
local hb, so, lean, lat, v, dist = (os.getenv("SHO_ST")):match("(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+)")
local S = { hb = tonumber(hb), so = tonumber(so), lean = tonumber(lean), lat = tonumber(lat), v = tonumber(v), dist = tonumber(dist), skid = false, bpos = 1 }
local T0 = tonumber(os.getenv("SHO_T0"))
local out = {}
local dir = (T0 >= S.lat) and 1 or -1
local es = {}
for a = 0, 40 do local e, tarr = M.sim_plan(S, T0, dir, a, 127, 10); es[#es + 1] = string.format("%d:%.0f", a, e) end
out[#out + 1] = 'e(a): ' .. table.concat(es, ' ')
local pl = M.best_plan(S, T0)
out[#out + 1] = string.format("plan: a=%d cap=%d err=%.0f tarr=%d n=%d", pl.a, pl.cap, pl.err, pl.tarr, pl.rec.n)
local tr = {}
for i = 1, pl.rec.n do tr[#tr + 1] = string.format("%d", pl.rec.lat[i]) end
out[#out + 1] = "predicted lat: " .. table.concat(tr, " ")
local cs = {}
for i = 1, pl.rec.n do cs[#cs + 1] = tostring(pl.rec.cmds[i]) end
out[#out + 1] = "cmds: " .. table.concat(cs, " ")
-- execute with next_cmd
local ex = {}
M.cur = nil
for t = 1, 60 do M.step(S, M.next_cmd(S, T0)); ex[#ex + 1] = string.format("%d", S.lat) end
out[#out + 1] = "executed lat: " .. table.concat(ex, " ")
local f = io.open(root .. "/out/dbgplan.txt", "w"); f:write(table.concat(out, "\n") .. "\n"); f:close()
manager.machine:exit()
