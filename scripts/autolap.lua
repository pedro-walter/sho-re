-- Autopilot lap timing (v2). Full throttle on straights; steers the handlebar ($FF063A) so that the lateral position follows a
-- target (inside edge in curves, pre-positioned before them, 0 on straights); brakes before a curve whose outward push
-- (2.75 * v / r) exceeds what the tire tier can counter-steer. Logs lap times, skid frames, and a summary at the race end.
--
-- Physics measured with curvedrift.lua / steerprobe.lua / braketest.lua:
--   outward push per frame  p = 2.75 * v / r * (r + side/40) / r      (side = offset toward the inside)
--   max counter-steer       G = 8 * 160 / (128 + {32,20,8,-4,-16}[tire])   (lateral units per frame, speed > 127)
--   handlebar $FF063A ramps ~2.5/frame while a direction is held (~1.2/frame back to 0), lateral velocity = push - G * steer / 127
--   brake A: -0.95 speed/frame, throttle released: -0.26/frame; distance per frame = 0.001335 * v
-- Env: SHO_ENGINE SHO_OIL SHO_TIRE SHO_FRAME (tiers poked every frame; health forced to 15), SHO_RIVAL (default 0),
--      SHO_TIN (inside target in curves, default 250), SHO_PRE (pre-position distance, default 45), SHO_SAFE (speed-limit factor, default 0.97),
--      SHO_TURBO=1 (hold C), SHO_NOBRAKE=1 (never brake: just coast/lift), SHO_LOG=n (trace every n frames), SHO_TAG, SHO_FRAMES, SHO_VMAX (cap)
local L = dofile(os.getenv("SHO_ROOT").."/scripts/lib.lua")
local input = {}
for fr, b, d in (os.getenv("SHO_INPUT") or ""):gmatch("(%d+):(%a+):?(%d*)") do input[#input+1] = {tonumber(fr), b, tonumber(d) or 6} end
local rival = tonumber(os.getenv("SHO_RIVAL") or 0)
local E, O, T, F = tonumber(os.getenv("SHO_ENGINE") or 0), tonumber(os.getenv("SHO_OIL") or 0), tonumber(os.getenv("SHO_TIRE") or 0), tonumber(os.getenv("SHO_FRAME") or 0)
local TIN = tonumber(os.getenv("SHO_TIN") or 200)
local PRE = tonumber(os.getenv("SHO_PRE") or 60)
local SAFE = tonumber(os.getenv("SHO_SAFE") or 0.97)
local KP = tonumber(os.getenv("SHO_KP") or 0.05)
local TOUT = tonumber(os.getenv("SHO_TOUT") or 250)
local PUSHDUTY = tonumber(os.getenv("SHO_DUTY") or 0.92)
local LS = tonumber(os.getenv("SHO_LS") or 0)
local TPRE = tonumber(os.getenv("SHO_TPRE") or 45)
local ENT = tonumber(os.getenv("SHO_ENT") or 120)
local EXITU = tonumber(os.getenv("SHO_EXIT") or 18)
local PUSHK = tonumber(os.getenv("SHO_PUSHK") or 2.75)
local OUTX = tonumber(os.getenv("SHO_OUTX") or 0)   -- >0: outside-exit line: target slides from +TIN (inside) at the curve start to -OUTX (outside) at its end
local TAG = os.getenv("SHO_TAG") or "AL"
local STOPK = tonumber(os.getenv("SHO_STOPK") or 0)
local LOG = tonumber(os.getenv("SHO_LOG") or 0)
local VMAX = tonumber(os.getenv("SHO_VMAX") or ((E >= 3 and os.getenv("SHO_TURBO")) and 279 or 241))
local TIREADJ = { 32, 20, 8, -4, -16 }
local G = 8.0 * 160 / (128 + TIREADJ[T + 1])
local DPF = 0.001335            -- distance units per frame per unit of speed
local BRAKE = 0.95              -- speed units per frame with A held

local vlim, push_mag
local segs = nil                -- {start, r, st, stop}
local function load_segs()
  local p = L.u32(0xFF0672)
  segs = { { 0, 0, 1, 0 } }
  local a = p
  while true do
    local s, r, st = L.u16(a), L.u16(a + 2), L.u16(a + 4)
    if s == 0xFFFF or s > 2047 then break end
    segs[#segs + 1] = { s, r, st, 0 }
    a = a + 6
  end
  for i = 1, #segs do segs[i][4] = (segs[i + 1] and segs[i + 1][1]) or 2048 end
  print(string.format("%s SEGS n=%d first=%d last=%d G=%.2f", TAG, #segs, segs[2] and segs[2][1] or -1, segs[#segs][1], G))
  for i = 1, #segs do if segs[i][3] ~= 1 then print(string.format("%s   seg %d start=%d len=%d st=%d r=%d vlim=%.0f push241=%.1f", TAG, i, segs[i][1], segs[i][4] - segs[i][1], segs[i][3], segs[i][2], vlim(segs[i]), push_mag(241, segs[i][2]))) end end
end

-- outward push per frame (sub_00EA24): every 3rd frame lat += 2*(trunc(Dc*v/110)+1), Dc = D/64 ~ 410/r, active about 90 % of the calls
function push_mag(v, r)
  local Dc = math.floor(410 / r + 0.5)
  return (2 / 3) * (math.floor(Dc * v / 110) + 1) * PUSHDUTY
end

-- speed limit for holding a curve segment with this tire: excess push may drift the bike from +TIN to about -TOUT over the curve
function vlim(sg)
  if sg.vl then return sg.vl end
  local r, len = sg[2], sg[4] - sg[1]
  local best = 60
  for v = 241, 60, -1 do
    local excess = push_mag(v, r) - G
    local frames = len / (DPF * v)
    if excess <= 0 or excess * frames <= (ENT + TOUT) then best = v; break end
  end
  sg.vl = (best >= 241) and 999 or SAFE * best
  return sg.vl
end

local function seg_index(d)
  for i = #segs, 1, -1 do if d >= segs[i][1] then return i end end
  return 1
end

local t0, lastlap, skidf, lapstart = nil, 0, 0, 0
local maxv, sumv, nv, brakef = 0, 0, 0, 0
local started = false
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 26000), input = input, on_frame = function(f)
  if f == 1250 then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 then L.mem:write_u16(0xFFB606, rival) end
  local mode = L.u16(0xFFC704) & 0x7FFC
  if mode ~= 0x18 then
    if started then print(string.format("%s END frame=%d race_frames=%d skid_frames=%d brake_frames=%d maxv=%d avgv=%d", TAG, f, f - t0, skidf, brakef, maxv, sumv // math.max(nv, 1))); manager.machine:exit() end
    return
  end
  L.mem:write_u16(0xFFB618, F); L.mem:write_u16(0xFFB61A, E); L.mem:write_u16(0xFFB620, O); L.mem:write_u16(0xFFB622, T)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 and not started then return end
  if not started then started = true; load_segs() end
  t0 = t0 or f
  local k = f - t0
  if STOPK > 0 and k >= STOPK then print(string.format("%s SUM k=%d dist=%d lap=%d skid_frames=%d brake_frames=%d avgv=%d", TAG, k, L.u16(0xFF0616), L.u16(0xFF060A), skidf, brakef, sumv // math.max(nv, 1))); manager.machine:exit() end
  local lat, st, v, s = L.s16(0xFF0614), L.u16(0xFF067E), L.u16(0xFF064A), L.s16(0xFF063A)
  local d = L.u16(0xFF0616) % 2048
  local lap = L.u16(0xFF060A)
  if lap ~= lastlap then print(string.format("%s LAP %d->%d at k=%d (%.2f s) lap_frames=%d", TAG, lastlap, lap, k, k/60, k - lapstart)); lastlap = lap; lapstart = k end
  if v > maxv then maxv = v end
  sumv = sumv + v; nv = nv + 1
  if L.u16(0xFF066A) ~= 0 then skidf = skidf + 1 end

  local i = seg_index(d)
  local cur = segs[i]
  local nxt = segs[i + 1] or segs[2]          -- wraps to the first curve of the next lap
  local dnext = (segs[i + 1] and segs[i + 1][1] or 2048 + segs[2][1]) - d
  -- signed outward push of a curve segment at the current speed (state 2 pushes toward +lat, state 3 toward -lat)
  local function spush(sg) local m = push_mag(v, sg[2]); return (sg[3] == 2) and m or -m end
  local function inside_sign(sst) return sst == 3 and 1 or -1 end
  local target, push = LS, 0
  local remain = cur[4] - d
  local tpre = DPF * math.max(v, 60) * TPRE           -- distance covered while the handlebar ramps up
  if cur[3] ~= 1 then
    target = inside_sign(cur[3]) * TIN
    if OUTX > 0 then
      local pr = math.max(0, math.min(1, (d - cur[1]) / math.max(1, cur[4] - cur[1])))
      target = inside_sign(cur[3]) * (TIN * (1 - pr) - OUTX * pr)
    end
    push = spush(cur)
    if remain < EXITU then
      local w = 1 - remain / EXITU
      if nxt[3] ~= 1 then
        push = (1 - w) * push + w * spush(nxt)
        if nxt[3] ~= cur[3] then target = inside_sign(nxt[3]) * TIN end
      else
        push = push * (1 - w)
        target = (dnext < tpre) and inside_sign(nxt[3]) * TIN or LS
      end
    end
  else
    if nxt[3] ~= 1 and dnext < tpre then
      target = inside_sign(nxt[3]) * TIN
      push = spush(nxt)                               -- pre-load the handlebar as if the push had started
    end
  end
  local Gv = G * ((v > 127) and 1 or math.max(v, 20) / 128)
  local vd = math.max(-0.8 * Gv, math.min(0.8 * Gv, KP * 8 / G * (target - lat)))
  local sd = math.max(-127, math.min(127, (push - vd) * 127 / Gv))
  local pd = {}
  if s > sd + 3 then pd.left = true elseif s < sd - 3 then pd.right = true end

  -- speed: throttle, release, brake
  local want_b, want_a = true, false
  local function consider(sg, dist_to)
    local vl = vlim(sg)
    local need = DPF * (v * v - vl * vl) / (2 * BRAKE) * 1.25 + 4
    if v > vl and dist_to < need then want_a = true end
    if v >= vl - 4 and dist_to < need + 12 then want_b = false end
  end
  if cur[3] ~= 1 then
    local vl = vlim(cur)
    if v > vl + 4 then want_a = true end
    if v > vl then want_b = false end
  end
  local j, dist_to = i + 1, dnext
  local seen = 0
  while seen < 4 do
    local sg = segs[j] or segs[((j - 1) % #segs) + 1]
    if sg[3] ~= 1 then consider(sg, dist_to) end
    dist_to = dist_to + (sg[4] - sg[1]); j = j + 1; seen = seen + 1
    if dist_to > 200 then break end
  end
  if os.getenv("SHO_NOBRAKE") then want_a = false end
  pd.b = want_b
  pd.a = want_a
  pd.c = os.getenv("SHO_TURBO") ~= nil
  if want_a then brakef = brakef + 1 end
  L.pad(pd)
  if LOG > 0 and k % LOG == 0 then print(string.format("%s T k=%d d=%d lap=%d st=%d r=%d lat=%d tgt=%d s=%d sd=%d v=%d skid=%d %s%s", TAG, k, d, lap, st, cur[2], lat, target, s, math.floor(sd), v, L.u16(0xFF066A), want_a and "A" or "-", want_b and "B" or "-")) end
end }
