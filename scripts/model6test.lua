-- Headless tests of scripts/model6.lua (no race needed): planned moves from rest for all tire / frame tiers. Prints the landing error per case.
local root = os.getenv("SHO_ROOT")
local out = {}
local function P(...) out[#out + 1] = string.format(...) end
local tires = os.getenv("SHO_TIRES") or "0,1,2,3,4"
local frames = os.getenv("SHO_FRAMES_T") or "0,2,5"
for T in tires:gmatch("%d") do for F in frames:gmatch("%d") do
  T, F = tonumber(T), tonumber(F)
  local M = dofile(root .. "/scripts/model6.lua").new{
    tire = T, frame = F, mult = 3, vmax = 241,
    profile = function() return 0 end, road = function() return 1, 0 end,
    speed_cmd = function() return false, true end, brk = function() return 0.95 end }
  M.VLATMAX = 22
  local res = {}
  for _, vv in ipairs({ 120, 200 }) do
    for _, e0 in ipairs({ 60, 240, 480, -400 }) do
      local S = { hb = 128, so = 0, lean = 0, lat = 0, v = vv, dist = 5, skid = false, acc = 0 }
      M.cur = nil
      local pl0 = M.best_plan(S, e0)
      local first, over = nil, -1e9
      for t = 1, 100 do
        M.step(S, M.next_cmd(S, e0))
        over = math.max(over, (S.lat - e0) * (e0 >= 0 and 1 or -1))
        if math.abs(S.lat - e0) <= 6 and not first then first = t end
      end
      res[#res + 1] = string.format("v%d/%d: tarr=%d first6=%s over=%d fin=%d", vv, e0, pl0.tarr, tostring(first), over, S.lat - e0)
    end
  end
  P("tire %d frame %d: %s", T, F, table.concat(res, " | "))
end end
local f = io.open(root .. "/out/model6test.txt", "w"); f:write(table.concat(out, "\n") .. "\n"); f:close()
manager.machine:exit()
