-- Headless: correcting a lateral error inside a curve (steady push). Env SHO_PLANMIN. Prints settling quality per case.
local root = os.getenv("SHO_ROOT")
local out = {}
local cases = 0
local sumdev, worst = 0, 0
for T = 0, 4, 2 do for F = 0, 5, 5 do
  for _, dcv in ipairs({ 4, 6 }) do for _, vv in ipairs({ 110, 170 }) do for _, e0 in ipairs({ -100, -50, 50, 100 }) do
    local M = dofile(root .. "/scripts/model6.lua").new{
      tire = T, frame = F, mult = 3, vmax = 241, pred = true, hold_h = 9, hold_h2 = 15, planmin = tonumber(os.getenv("SHO_PLANMIN") or 40),
      profile = function(d) return -dcv end, road = function(d) return 3, 100 end,
      speed_cmd = function() return false, true end }
    M.VLATMAX = 22
    local p = M.push_of(-dcv, vv)
    local auth = math.abs(M.lateral(127, vv, false))
    if math.abs(p) <= 0.75 * auth then
      -- start in steady hold at 240+e0
      local vf = (vv > 127) and 1 or vv / 128
      local so_t = p * M.DIV / (32 * vf)
      local hb0 = (math.abs(so_t) >= 38) and math.floor(128 - so_t * 140 / 256 + 0.5) or 128
      local S = { hb = hb0, so = M.steer_out(hb0), lean = M.steer_out(hb0), lat = 240 + e0, v = vv, dist = 50, skid = false, bpos = 1 }
      M.cur = nil
      local dev, settle = 0, nil
      for t = 1, 70 do
        M.step(S, M.next_cmd(S, 240))
        if t > 35 then dev = math.max(dev, math.abs(S.lat - 240)) end
        if math.abs(S.lat - 240) <= 10 and not settle then settle = t end
      end
      cases = cases + 1; sumdev = sumdev + dev; worst = math.max(worst, dev)
      out[#out + 1] = string.format("T%d F%d Dc%d v%d e0=%d: settle=%s dev_after35=%d", T, F, dcv, vv, e0, tostring(settle), dev)
    end
  end end end
end end
out[#out + 1] = string.format("cases %d mean dev after 35 ticks %.1f worst %d", cases, sumdev / math.max(cases, 1), worst)
local f = io.open(root .. "/out/model6corr.txt", "w"); f:write(table.concat(out, "\n") .. "\n"); f:close()
manager.machine:exit()
