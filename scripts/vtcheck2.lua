-- Headless: approach a curve from a relaxed handlebar (the real situation). Env as vtcheck.lua + SHO_H, SHO_L0 (start lateral), SHO_PRE (ticks before the curve to start)
local root = os.getenv("SHO_ROOT")
local function envn(k, d) return tonumber(os.getenv(k) or d) end
local prof = dofile(root .. "/data/roadprofile_track" .. envn("SHO_TRACK", 1) .. ".lua")
local CS, CE, CR, CST = envn("SHO_CS", 251), envn("SHO_CE", 281), envn("SHO_CR", 38), envn("SHO_CST", 3)
local line = ((CST == 3) and 1 or -1) * envn("SHO_LINE", 240)
local out = {}
for _, v0 in ipairs({ 120, 150, 180, 209 }) do
  local M = dofile(root .. "/scripts/model6.lua").new{
    tire = envn("SHO_TIRE", 0), frame = envn("SHO_FRAME", 0), mult = 3, vmax = 241, pred = true, hold_h = envn("SHO_H", 9), hold_h2 = envn("SHO_H2", nil),
    profile = function(d) return prof[math.floor(d) % 2048 + 1] or 0 end,
    road = function(d) if d >= CS and d < CE then return CST, CR else return 1, 0 end end,
    speed_cmd = function() return false, true end }
  M.VLATMAX = 22
  local S = { hb = 128, so = 0, lean = 0, lat = envn("SHO_L0", line), v = v0, dist = CS - envn("SHO_PRE", 25) * 269 * v0 / 65536, skid = false, bpos = 1 }
  local tr, mx, mn, ent = {}, -1e9, 1e9, nil
  for t = 1, 120 do
    if S.dist >= CE + 6 then break end
    M.step(S, M.hold(S, line))
    mx = math.max(mx, S.lat); mn = math.min(mn, S.lat)
    if S.dist >= CS and not ent then ent = t end
    if t % 3 == 0 then tr[#tr + 1] = string.format("%d", S.lat) end
  end
  out[#out + 1] = string.format("v0=%d min=%d max=%d entry_tick=%s: %s", v0, mn, mx, tostring(ent), table.concat(tr, " "))
end
local f = io.open(root .. "/out/vtcheck2.txt", "w"); f:write(table.concat(out, "\n") .. "\n"); f:close()
manager.machine:exit()
