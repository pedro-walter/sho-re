-- Headless test: holding a lateral line against a constant road push (curve), policy only. Env SHO_TIRE SHO_FRAME.
local root = os.getenv("SHO_ROOT")
local out = {}
local function P(...) out[#out + 1] = string.format(...) end
for T = 0, 4, 2 do for F = 0, 5, 5 do
  for _, dcv in ipairs({ 3, 4, 5, 6 }) do for _, vv in ipairs({ 120, 200 }) do
    local M = dofile(root .. "/scripts/model6.lua").new{
      tire = T, frame = F, mult = 3, pred = os.getenv('SHO_PRED') ~= nil, hold_h = tonumber(os.getenv('SHO_H') or 6), vmax = 241, profile = function(d) if d < 100 then return 0 elseif d < 101 then return -1 elseif d < 103 then return -(dcv * 3 // 4) else return -dcv end end, road = function(d) if d < 100 then return 1, 0 end; return 3, 100 end,
      speed_cmd = function() return false, true end, brk = function() return 0.95 end }
    M.VLATMAX = 22
    M.LOOK = tonumber(os.getenv('SHO_LOOK') or 6)
    local S = { hb = 128, so = 0, lean = 0, lat = tonumber(os.getenv('SHO_L0') or 240), v = vv, dist = 92, skid = false, acc = 0 }
    local tr, mx, mn = {}, -1e9, 1e9
    for t = 1, 140 do
      M.step(S, M.hold(S, 240))
      mx = math.max(mx, S.lat); mn = math.min(mn, S.lat)
      if t % 10 == 0 then tr[#tr + 1] = string.format("%d", S.lat) end
    end
    P("tire %d frame %d Dc=%d v=%d push=%d: lat range after 40 ticks [%d,%d]  trace: %s", T, F, dcv, vv, M.push_of(-dcv, vv), mn, mx, table.concat(tr, " "))
  end end
end end
local f = io.open(root .. "/out/model6hold.txt", "w"); f:write(table.concat(out, "\n") .. "\n"); f:close()
manager.machine:exit()
