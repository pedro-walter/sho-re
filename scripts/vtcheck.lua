-- Headless check of the automatic entry speed for one curve: SHO_TRACK, SHO_CS (curve start), SHO_CE (end), SHO_CR (radius), SHO_CST (state 2/3), SHO_TIRE, SHO_FRAME
local root = os.getenv("SHO_ROOT")
local function envn(k, d) return tonumber(os.getenv(k) or d) end
local prof = dofile(root .. "/data/roadprofile_track" .. envn("SHO_TRACK", 1) .. ".lua")
local CS, CE, CR, CST = envn("SHO_CS", 251), envn("SHO_CE", 281), envn("SHO_CR", 38), envn("SHO_CST", 3)
local line = ((CST == 3) and 1 or -1) * 240
local out = {}
for _, v0 in ipairs({ 100, 140, 180, 200, 218, 241 }) do
  local M = dofile(root .. "/scripts/model6.lua").new{
    tire = envn("SHO_TIRE", 0), frame = envn("SHO_FRAME", 0), mult = 3, vmax = 241, pred = true, hold_h = 9,
    profile = function(d) return prof[math.floor(d) % 2048 + 1] or 0 end,
    road = function(d) if d >= CS and d < CE then return CST, CR else return 1, 0 end end,
    speed_cmd = function() return false, true end }
  M.VLATMAX = 22
  local p0 = M.push_of(prof[CS + 3], v0)
  local vv = (v0 > 127) and 1 or v0 / 128
  local so_t = p0 * M.DIV / (32 * vv)
  local hb0 = (math.abs(so_t) >= 38) and math.floor(128 - so_t * 140 / 256 + 0.5) or 128
  local so0 = M.steer_out(hb0)
  local S = { hb = hb0, so = so0, lean = so0, lat = line, v = v0, dist = CS, skid = false, bpos = 1 }
  local tr, mx = {}, 0
  for t = 1, 60 do
    if S.dist >= CE + 1 then break end
    M.step(S, M.hold(S, line))
    mx = math.max(mx, math.abs(S.lat))
    tr[#tr + 1] = string.format("%d", S.lat)
  end
  out[#out + 1] = string.format("v0=%d p0=%d so0=%d max|lat|=%d ticks=%d: %s", v0, p0, so0, mx, #tr, table.concat(tr, " "))
end
local f = io.open(root .. "/out/vtcheck.txt", "w"); f:write(table.concat(out, "\n") .. "\n"); f:close()
manager.machine:exit()
