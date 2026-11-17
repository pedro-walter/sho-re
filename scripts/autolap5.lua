-- Autopilot v5: follows an offline backward chain plan (tools/chainplan2.py -> scripts/plan_track3_t<tire>.lua, env SHO_PLAN=path). Based on v4 (chains: entry speed from a simulation of a whole run of contiguous curves incl. handlebar reversal lead). Based on v3 ( full-lock outside exit). In a curve the handlebar is held at FULL counter-lock; the entry speed is chosen by a forward
-- simulation so that the outward drift ends at SHO_OUT (<300) at the curve end. Based on v2: Full throttle on straights; steers the handlebar ($FF063A) so that the lateral position follows a
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
local OUT = tonumber(os.getenv("SHO_OUT") or 255)      -- allowed outward offset at the curve end
local INL = tonumber(os.getenv("SHO_INL") or 290)      -- inside limit (hold instead of full lock beyond)
local MINDELTA = tonumber(os.getenv("SHO_MIND") or 120)
local MARG = tonumber(os.getenv("SHO_MARG") or 0)
local OFF = tonumber(os.getenv("SHO_OFF") or 270)       -- |lateral| beyond which the bike is off the road (wheel on the edge line; the skid flag is at 300)
local REL = tonumber(os.getenv("SHO_REL") or 0)        -- frames before a sharp curve ends at which the lock is eased
local BR = tonumber(os.getenv("SHO_BR") or 0.35)
local NOCHAIN = os.getenv("SHO_NOCHAIN") ~= nil          -- per-curve entry limits (v3 behaviour) instead of chain simulation
local PLANF = os.getenv("SHO_PLAN")
local GENT = tonumber(os.getenv("SHO_GENT") or 0)
local GFADE = tonumber(os.getenv("SHO_GFADE") or 70)
local MEAS = os.getenv("SHO_MEAS") ~= nil
local hist, pe = {}, nil
local NOBOTS = os.getenv("SHO_NOBOTS") ~= nil
local plan = PLANF and dofile(PLANF) or nil
local LEAD = tonumber(os.getenv("SHO_LEAD") or 40)      -- frames before a curve ends at which the lock switches to the next (opposite) curve
local PL = tonumber(os.getenv("SHO_PL") or 20)
local INE = tonumber(os.getenv("SHO_INE") or 240)      -- inside-edge target (offset from the centre) before and in curves
local U0 = tonumber(os.getenv("SHO_U0") or 200)        -- assumed inside offset at curve start
local MULT = ({3,4,6,6,8,8})[E+1] + (O + tonumber(os.getenv("SHO_MUF") or 0)) / 4
local LOADSTATE, SAVESTATE = os.getenv("SHO_LOADSTATE"), os.getenv("SHO_SAVESTATE")   -- savestate in out/.sta/genesis/: skip the menus
if LOADSTATE then input = {} end
local TAG = os.getenv("SHO_TAG") or "AL"
local STOPK = tonumber(os.getenv("SHO_STOPK") or 0)
local LOG = tonumber(os.getenv("SHO_LOG") or 0)
local VMAX = tonumber(os.getenv("SHO_VMAX") or ((E >= 3 and os.getenv("SHO_TURBO")) and 279 or 241))
local TIREADJ = { 32, 20, 8, -4, -16 }
local G = 8.0 * 160 / (128 + TIREADJ[T + 1])
local DPF = 0.001335            -- distance units per frame per unit of speed
local BRK, BRKW = 0.95, 20       -- braking deceleration (speed units per frame with A held): starts here, then learned from every real braking run (BRKW = weight of the estimate, in frames)
local TRANS = tonumber(os.getenv("SHO_TRANS") or 5)   -- distance units before a curve boundary at which the real (drawn-road) push already follows the next curve
local BRKLEARN = os.getenv("SHO_BRKLEARN") ~= "0"   -- learn the brake deceleration online (0: keep the fixed initial value)
local BMARG = tonumber(os.getenv("SHO_BMARG") or 1.25)   -- safety factor on the braking distance
local swseg, swlatch = nil, false   -- auto lock-switch state: curve segment and whether the switch to the next (opposite) curve has started
local brk_on, brk_v0, brk_n = false, 0, 0

local vlim, push_mag, frames_needed, chain_entry, wait_ok
local pressing = nil
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
  -- plan field ext: the drawn-road curvature (the real push, D) can outlast the physical curve list; treat the curve as lasting ext more distance units
  for i = 1, #segs - 1 do
    local pl = plan and plan[segs[i][1]]
    if pl and pl.ext and segs[i][3] ~= 1 and segs[i + 1][3] == 1 then segs[i][4] = segs[i][4] + pl.ext; segs[i + 1][1] = segs[i + 1][1] + pl.ext end
  end
  for i = 1, #segs do segs[i].head = (segs[i][3] ~= 1) and (i == 1 or segs[i - 1][3] == 1) end
  local tn = 0
  for i = 1, #segs do if segs[i][3] ~= 1 then tn = tn + 1; segs[i].tn = tn; print(string.format("%s TURN %d start=%d len=%d dir=%s r=%d", TAG, tn, segs[i][1], segs[i][4] - segs[i][1], segs[i][3] == 2 and "R" or "L", segs[i][2])) end end
  print(string.format("%s SEGS n=%d first=%d last=%d G=%.2f", TAG, #segs, segs[2] and segs[2][1] or -1, segs[#segs][1], G))
  for i = 1, #segs do if segs[i][3] ~= 1 then print(string.format("%s   seg %d start=%d len=%d st=%d r=%d chain_entry=%s push241=%.1f", TAG, i, segs[i][1], segs[i][4] - segs[i][1], segs[i][3], segs[i][2], segs[i].head and tostring(chain_entry(i)) or "-", push_mag(241, segs[i][2]))) end end
end

-- outward push per frame (sub_00EA24): every 3rd frame lat += 2*(trunc(Dc*v/110)+1), Dc = D/64 ~ 410/r, active about 90 % of the calls
function push_mag(v, r)
  local Dc = math.floor(410 / r + 0.5)
  return (2 / 3) * (math.floor(Dc * v / 110) + 1) * PUSHDUTY
end

-- speed limit for holding a curve segment with this tire: excess push may drift the bike from +TIN to about -TOUT over the curve
function vlim(sg, uin)
  uin = uin or -INE
  local key = math.floor(uin / 20 + 0.5)
  sg.vc = sg.vc or {}
  if sg.vc[key] then return sg.vc[key] end
  local r, len = sg[2], sg[4] - sg[1]
  local best = 60
  for v0 = 241, 60, -1 do
    local v, u, d, ok = v0, key * 20, 0, true
    local fr = 0
    while d < len do
      if fr % 3 == 0 then v = math.min(VMAX, v + MULT * (279 - v) / 1024) end
      fr = fr + 1
      u = u + push_mag(v, r) - G * ((v > 127) and 1 or v / 128)
      if u < -INL then u = -INL end
      if u > OUT then ok = false; break end
      d = d + DPF * v
    end
    if ok then best = v0; break end
  end
  sg.vc[key] = (best >= 241) and 999 or best
  return sg.vc[key]
end

-- frames of pressing inward needed for the bike to have moved `delta` units inward AND the handlebar to be at full lock (model: handlebar offset h
-- (inward > 0) moves 1.0/frame forward (2.0 when reversing), steer_out = 0 in the dead zone |h|<=20, else 1.83*h (max 127), inward speed = G*steer/127)
function frames_needed(delta, h0, Gv)
  local h, disp, lock = h0, 0, nil
  for n = 1, 400 do
    h = h + ((h < 0) and 2.0 or 1.0)
    local so = (math.abs(h) <= 20) and 0 or math.max(-127, math.min(127, 1.83 * h))
    disp = disp + Gv * so / 127
    if h >= 69.5 and not lock then lock = n end
    if disp >= delta and lock then return n end
  end
  return 400
end

-- speed-dependent counter-steer authority
local function Gof(v) return G * ((v > 127) and 1 or math.max(v, 20) / 128) end
-- simulate a chain of contiguous curves starting at segment i0 with entry speed v0 (bike on the inside edge, handlebar at full lock);
-- full throttle, full lock in the curve's direction (hold on the inside edge), lock switched LEAD frames before an opposite curve. Returns ok, exit speed.
local function sim_chain(i0, v0)
  local v, x, j = v0, segs[i0][1], i0
  local sg = segs[j]
  local ps = (sg[3] == 2) and 1 or -1
  local lat, h, fr = -ps * INE, ps * 69.4, 0
  while fr < 9000 do
    while x >= segs[j][4] do
      j = j + 1
      if not segs[j] or segs[j][3] == 1 then return true, v end
    end
    sg = segs[j]; ps = (sg[3] == 2) and 1 or -1
    local cdir = ps
    local nx = segs[j + 1]
    if nx and nx[3] ~= 1 and nx[3] ~= sg[3] and (sg[4] - x) < DPF * v * LEAD then cdir = -ps end
    local pm = push_mag(v, sg[2])
    local Gv = Gof(v)
    local hc
    if cdir * lat < -(INE - 15) then hc = math.max(-69.4, math.min(69.4, ps * pm * 127 / Gv / 1.83)) else hc = cdir * 69.4 end
    local dh = hc - h
    local rate = (h * dh < 0) and 2.0 or 1.0
    if math.abs(dh) <= rate then h = hc else h = h + (dh > 0 and rate or -rate) end
    local so = (math.abs(h) <= 20) and 0 or math.max(-127, math.min(127, 1.83 * h))
    lat = lat + ps * pm - Gv * so / 127
    local u = ps * lat
    if u > OUT or u < -(INE + 25) then return false, v end
    if fr % 3 == 0 then v = math.min(VMAX, v + MULT * (279 - v) / 1024) end
    x = x + DPF * v
    fr = fr + 1
  end
  return true, v
end
function chain_entry(i0)
  local sg = segs[i0]
  if sg.ce then return sg.ce end
  local best = 60
  for v0 = 241, 60, -1 do
    if sim_chain(i0, v0) then best = v0; break end
  end
  sg.ce = (best >= 241) and 999 or best
  return sg.ce
end
-- Would the bike still reach the next (opposite) curve's entry position if it keeps the current curve's lock for `delay` more frames and then reverses?
-- Simulates the handlebar (ramp 1/frame, 2/frame when reversing, dead zone |h|<=20) and the lateral position q (offset toward the next curve's OUTSIDE) until the current curve ends.
-- Success: q <= -inside*INE (entry position reached) and the handlebar is out of the dead zone (steering inward) when this curve ends.
function wait_ok(cur, nxt, pl, lat, v, remain, delay)
  local psn = (nxt[3] == 2) and 1 or -1
  local pln = plan and plan[nxt[1]]
  local an = (pln and (pln.inside and pln.inside / 100 or pln.a)) or 1
  local INEn, INEc = (pln and pln.ine) or INE, (pl and pl.ine) or INE
  local qt = -INEn * an
  local m = push_mag(v, cur[2])                 -- this curve's push, as seen from the next curve it moves the bike toward the next inside
  local mn = push_mag(v, nxt[2])
  local Gv = Gof(v)
  local q = psn * lat
  local h = (psn == 1) and (128 - L.u16(0xFFC73C)) or (L.u16(0xFFC73C) - 128)
  local x = remain
  local n = 0
  local vl = (pln and pln.vt) or 999
  while x > 0 and n < 400 do
    n = n + 1
    -- the speed policy: brake so as to arrive at the next curve with its planned entry speed (the push and the distance covered per frame follow the speed)
    if v > vl and x < DPF * (v * v - vl * vl) / (2 * BRK) * BMARG + 4 then v = math.max(vl, v - BRK) end
    m = push_mag(v, cur[2]); mn = push_mag(v, nxt[2]); Gv = Gof(v)
    local hc
    if n <= delay then
      if q >= INEc - 15 or cur[2] >= GENT and GENT > 0 then hc = -math.max(0, math.min(69.4, m * 127 / Gv / 1.83)) else hc = -69.4 end   -- at this curve's inside edge, or in a gentle curve (proportional steering): hold only what balances the push
    else hc = 69.4 end
    local dh = hc - h
    local rate = (h * dh < 0) and 2.0 or 1.0
    if math.abs(dh) <= rate then h = hc else h = h + (dh > 0 and rate or -rate) end
    local so = (math.abs(h) <= 20) and 0 or math.max(-127, math.min(127, 1.83 * h))
    q = q + ((x <= TRANS) and mn or -m) - Gv * so / 127      -- the drawn-road push flips to the next curve TRANS units before the table boundary
    x = x - DPF * math.max(v, 60)
  end
  return q <= qt and h >= 20, q, h, qt
end

-- time (frames) to cover `dist` units when we cruise at v and brake in time to arrive at vl (the braking envelope of the speed policy)
local function time_to(dist, v, vl)
  local t, x = 0, 0
  while x < dist do
    local rem = dist - x
    local venv = math.sqrt(vl * vl + math.max(0, 2 * BRK * (rem - 4) / (BMARG * DPF)))
    local vx = math.max(60, math.min(v, venv))
    t = t + 1 / (DPF * vx); x = x + 1
  end
  return t
end

local function seg_index(d)
  for i = #segs, 1, -1 do if d >= segs[i][1] then return i end end
  return 1
end

local t0, lastlap, skidf, lapstart = nil, 0, 0, 0
local offf = 0
local maxv, sumv, nv, brakef = 0, 0, 0, 0
local started = false
local MLOG = os.getenv("SHO_MLOG") ~= nil           -- per-frame model log (tools/steermodel.py validates the exact steering/lateral model against it)
local wr = {}
if MLOG then L.watch_write(0xFF0614, 0xFF0615, function(off, data, mask, pc) local dl = data - L.s16(0xFF0614); if dl > 32767 then dl = dl - 65536 elseif dl < -32768 then dl = dl + 65536 end; wr[#wr + 1] = string.format("%X:%d", pc, dl) end) end
local STARTAFTER, startd, rendering = tonumber(os.getenv("SHO_STARTAFTER") or ""), nil, true   -- SHO_STARTAFTER=N: drive turns 1..N silently, start logging/snapshots at the end of turn N at SHO_STARTV speed
rendering = (STARTAFTER == nil)
local STOPTURN, stopd = tonumber(os.getenv("SHO_STOPTURN") or ""), nil
L.run{ frames = tonumber(os.getenv("SHO_FRAMES") or 26000), input = input, on_frame = function(f)
  if LOADSTATE and f == 2 then manager.machine:load(LOADSTATE) end
  if f == 1250 and not LOADSTATE then L.mem:write_u32(0xFFB638, 0x00999999) end
  if f >= 3000 and f <= 4200 and not LOADSTATE then L.mem:write_u16(0xFFB606, rival) end
  if NOBOTS then for a = 0xFFCC40, 0xFFCD40, 0x40 do L.mem:write_u16(a, 0) end; L.mem:write_u16(0xFF0690, 0) end
  local mode = L.u16(0xFFC704) & 0x7FFC
  if mode ~= 0x18 then
    if started then print(string.format("%s END frame=%d race_frames=%d skid_frames=%d brake_frames=%d maxv=%d avgv=%d", TAG, f, f - t0, skidf, brakef, maxv, sumv // math.max(nv, 1))); manager.machine:exit() end
    return
  end
  L.mem:write_u16(0xFFB618, F); L.mem:write_u16(0xFFB61A, E); L.mem:write_u16(0xFFB620, O); L.mem:write_u16(0xFFB622, T); L.mem:write_u16(0xFFB61C, tonumber(os.getenv("SHO_BRAKET") or 0)); L.mem:write_u16(0xFFB61E, tonumber(os.getenv("SHO_MUFFLER") or 0))
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2*i, 15) end
  if L.u16(0xFF0616) == 0 and not started then return end
  if not started then started = true; load_segs(); if SAVESTATE then manager.machine:save(SAVESTATE); print("SAVED " .. SAVESTATE); end end
  if SAVESTATE and started and f > 0 and (t0 or f) ~= nil and L.frame > (t0 or 0) + 3 then manager.machine:exit() end
  t0 = t0 or f
  local k = f - t0
  if k <= 2 and not STARTAFTER and os.getenv("SHO_STARTV") and tonumber(os.getenv("SHO_STARTV")) > 0 then L.mem:write_u16(0xFF064A, tonumber(os.getenv("SHO_STARTV"))) end   -- flying start (HUD km/h / 1.1625)
  if STOPK > 0 and k >= STOPK then print(string.format("%s SUM k=%d dist=%d lap=%d skid_frames=%d off_frames=%d brake_frames=%d avgv=%d", TAG, k, L.u16(0xFF0616), L.u16(0xFF060A), skidf, offf, brakef, sumv // math.max(nv, 1))); manager.machine:exit() end
  local lat, st, v, s = L.s16(0xFF0614), L.u16(0xFF067E), L.u16(0xFF064A), L.s16(0xFF063A)
  local d = L.u16(0xFF0616) % 2048
  local lap = L.u16(0xFF060A)
  if STARTAFTER and not rendering and lap == 0 then
    if not startd then for i = 1, #segs do if segs[i].tn == STARTAFTER then startd = segs[i][4] end end; startd = startd or 99999 end
    if d >= startd and d < startd + 200 then
      rendering = true
      if os.getenv("SHO_STARTV") and tonumber(os.getenv("SHO_STARTV")) > 0 then L.mem:write_u16(0xFF064A, tonumber(os.getenv("SHO_STARTV"))) end
      print(string.format("%s RENDER START after turn %d k=%d d=%d", TAG, STARTAFTER, k, d))
    end
  end
  if STOPTURN and lap == 0 and not stopd then for i = 1, #segs do if segs[i].tn == STOPTURN then stopd = segs[i][4] end end; if not stopd then stopd = 99999 end end   -- SHO_STOPTURN=N: end the run when the first lap passes the end of turn N
  if STOPTURN and lap == 0 and d >= stopd and d < stopd + 200 then print(string.format("%s STOP at end of turn %d k=%d d=%d", TAG, STOPTURN, k, d)); manager.machine:exit() end
  if lap ~= lastlap then print(string.format("%s LAP %d->%d at k=%d (%.2f s) lap_frames=%d", TAG, lastlap, lap, k, k/60, k - lapstart)); lastlap = lap; lapstart = k; lapsdone = (lapsdone or 0) + 1; if os.getenv("SHO_ONELAP") and lapsdone >= (tonumber(os.getenv("SHO_ONELAP")) or 1) then manager.machine:exit() end end
  if v > maxv then maxv = v end
  sumv = sumv + v; nv = nv + 1
  if L.u16(0xFF066A) ~= 0 then skidf = skidf + 1 end
  if math.abs(lat) > OFF then offf = offf + 1 end

  local i = seg_index(d)
  local cur = segs[i]
  local nxt = segs[i + 1] or segs[2]          -- wraps to the first curve of the next lap
  local dnext = (segs[i + 1] and segs[i + 1][1] or 2048 + segs[2][1]) - d
  -- signed outward push of a curve segment at the current speed (state 2 pushes toward +lat, state 3 toward -lat)
  local function spush(sg) local m = push_mag(v, sg[2]); return (sg[3] == 2) and m or -m end
  local function inside_sign(sst) return sst == 3 and 1 or -1 end
  local want_slow = false
  local target, push = LS, 0
  local remain = cur[4] - d
  local tpre = DPF * math.max(v, 60) * TPRE           -- distance covered while the handlebar ramps up
  local fulllock, plcur = nil, nil
  -- measured push: lateral velocity over 6 frames plus the steering effect (lat_vel = push - s*Gv/127)
  hist[#hist + 1] = { lat, s, i, L.u16(0xFF066A) ~= 0 }
  if #hist > 7 then table.remove(hist, 1) end
  local pm = nil
  if #hist == 7 and math.abs(lat) < 480 then
    local ok, sm = true, 0
    for q = 1, 7 do if hist[q][3] ~= i or hist[q][4] then ok = false end; if q > 1 then sm = sm + hist[q][2] end end
    if ok then pm = (lat - hist[1][1]) / 6 + (sm / 6) * (G * ((v > 127) and 1 or math.max(v, 20) / 128)) / 127 end
  end
  local cdirc = nil
  if cur[3] ~= 1 then
    local ps = (cur[3] == 2) and 1 or -1          -- push sign; outward offset u = ps*lat
    local u = ps * lat
    push = spush(cur)
    if MEAS and pm and cur[2] >= GENT then
      local mag = math.max(0, math.min(math.abs(push) * 1.05, (cur[3] == 2) and pm or -pm))
      pe = pe and (0.85 * pe + 0.15 * mag) or mag
      push = ((cur[3] == 2) and 1 or -1) * pe
    elseif not pm then pe = nil end
    local cdir = ps
    local pl = plan and plan[cur[1]]
    plcur = pl
    local inwin = false
    if pl and nxt[3] ~= 1 and pl.lead == nil and nxt[3] ~= cur[3] then
      -- automatic lock switch: hold this curve's lock as long as reversing LATER still puts the bike at the next curve's entry position (and at full lock) when this curve ends
      if swseg ~= i then swseg = i; swlatch = false end
      if not swlatch then
        local okw, qe, he, qtt = wait_ok(cur, nxt, pl, lat, v, remain, 1)
        if not okw then
          swlatch = true
          local _, q0, h0 = wait_ok(cur, nxt, pl, lat, v, remain, 0)
          print(string.format("%s SWITCH turn=%s d=%d lat=%d v=%d remain=%.1f pred_q_end(now)=%.0f h=%.0f target=%.0f", TAG, tostring(cur.tn), d, lat, v, remain, q0, h0, qtt))
        end
      end
      inwin = swlatch
      if inwin then cdir = -ps end
    elseif pl and nxt[3] ~= 1 then
      inwin = remain < DPF * math.max(v, 60) * (pl.lead or LEAD)
      if inwin and nxt[3] ~= cur[3] then cdir = -ps end
    elseif nxt[3] ~= 1 and nxt[3] ~= cur[3] and remain < DPF * math.max(v, 60) * LEAD then cdir = -ps end
    cdirc = cdir
    local INEc = (pl and pl.ine) or INE
    target = -cdir * INEc
    if GENT > 0 and cur[2] >= GENT and nxt[3] == 1 then
      local f = math.max(0, math.min(1, (remain - ((pl and pl.send) or 0)) / (DPF * math.max(v, 60) * GFADE)))
      push = push * f; target = target * (0.3 + 0.7 * f)
    end
    if u > OUT - 5 and not plan then want_slow = true end
    if u > OFF - 5 and plan and os.getenv("SHO_SLOW") then want_slow = true end   -- v5: no corrective braking inside a curve (fix the entry speed instead)
    if (inwin or cdir * lat > -(INEc - 15)) and not (GENT > 0 and cur[2] >= GENT and cdir == ps) then fulllock = cdir end
  else
    if nxt[3] ~= 1 and dnext < tpre then
      local psn = (nxt[3] == 2) and 1 or -1
      local pln = plan and plan[nxt[1]]
      local an = (pln and (pln.inside and pln.inside / 100 or pln.a)) or 1
      local INEn = (pln and pln.ine) or INE
      local delta = psn * lat + INEn * an
      target = inside_sign(nxt[3]) * INEn
      if delta >= MINDELTA then
        local h0 = (psn == 1) and (128 - L.u16(0xFFC73C)) or (L.u16(0xFFC73C) - 128)
        local nn = frames_needed(delta, h0, G)
        local vln = pln and pln.vt or (NOCHAIN and vlim(nxt, -INE) or (nxt.head and chain_entry(i + 1) or 999))
        local ft = time_to(dnext, v, math.min(vln, v))
        if os.getenv("SHO_DBGP") and k % 30 == 0 then print(string.format("PR k=%d d=%d delta=%d h0=%.0f nn=%d ft=%.0f", k, d, delta, h0, nn, ft)) end
        if ft <= nn + (pln and pln.marg or MARG) then pressing = psn end
        target = LS
      elseif dnext < DPF * math.max(v, 60) * PL then push = spush(nxt) end
    end
    if pressing and not (nxt[3] ~= 1 and dnext < tpre) then pressing = nil end
    if pressing and pressing * lat < -(((plan and plan[nxt[1]] and plan[nxt[1]].ine) or INE) + 20) then pressing = nil end   -- reached the edge early: hold there instead
  end
  if cur[3] ~= 1 then pressing = nil end
  local Gv0 = G
  local Gv = G * ((v > 127) and 1 or math.max(v, 20) / 128)
  local err = target - lat
  -- the handlebar only unwinds at about 1.2 steer units/frame, so the lateral speed must be low enough to stop in the remaining distance: vd <= BR*sqrt(|err|)
  local vmax = math.min(0.8 * Gv, BR * math.sqrt(math.abs(err)))
  local vd = math.max(-vmax, math.min(vmax, KP * 8 / G * err))
  local sd = math.max(-127, math.min(127, (push - vd) * 127 / Gv))
  if fulllock then
    sd = fulllock * 127
    local relv = (plcur and plcur.rel) or REL
    if relv > 0 and remain < DPF * math.max(v, 60) * relv and nxt[3] == 1 then sd = fulllock * 127 * ((plcur and plcur.relf) or 0.3) end   -- relf: fraction of the lock kept once eased (default 0.3; 0 = fully released)
  end
  if pressing and cur[3] == 1 then sd = pressing * 127 end
  local pd = {}
  if s > sd + 3 then pd.left = true elseif s < sd - 3 then pd.right = true end

  -- speed: throttle, release, brake
  local want_b, want_a = true, false
  local function consider(sg, sgi, dist_to)
    local pl = plan and plan[sg[1]]
    if not pl and not sg.head and not NOCHAIN then return end
    local vl = pl and pl.vt or (NOCHAIN and vlim(sg, -INE) or chain_entry(sgi))
    local need = DPF * (v * v - vl * vl) / (2 * BRK) * BMARG + 4
    if v > vl and dist_to < need then want_a = true end
    if v >= vl - 4 and dist_to < need + 12 then want_b = false end
  end
  if want_slow then want_a = true; want_b = false end
  local j, dist_to = i + 1, dnext
  local seen = 0
  while seen < 4 do
    local sg = segs[j] or segs[((j - 1) % #segs) + 1]
    if sg[3] ~= 1 then consider(sg, ((j - 1) % #segs) + 1, dist_to) end
    dist_to = dist_to + (sg[4] - sg[1]); j = j + 1; seen = seen + 1
    if dist_to > 200 then break end
  end
  if os.getenv("SHO_NOBRAKE") then want_a = false end
  pd.b = want_b
  pd.a = want_a
  pd.c = os.getenv("SHO_TURBO") ~= nil
  if rendering and os.getenv("SHO_SNAP") and k % tonumber(os.getenv("SHO_SNAP")) == 0 then L.snapshot(string.format("rec/%s_%05d.png", TAG, k)); print(string.format("REC %d %d %d %d %d %d %d %d %d %d %d", k, d, cur.tn or 0, cur[3], cur[2], lat, v, L.u16(0xFF066A) ~= 0 and 1 or 0, nxt.tn or 0, dnext, (function() local l = L.s16(0xFFC978); if l > 127 or l < -127 then l = 0 end; return l end)())) end
  if want_a then
    brakef = brakef + 1
    if not brk_on then brk_on = true; brk_v0 = v; brk_n = 0 end
    brk_n = brk_n + 1
  elseif brk_on then
    brk_on = false
    if brk_n >= 8 and BRKLEARN then
      local dec = math.max(0.3, math.min(3, (brk_v0 - v) / brk_n))
      BRK = (BRK * BRKW + dec * brk_n) / (BRKW + brk_n); BRKW = math.min(300, BRKW + brk_n)
      print(string.format("%s BRK run=%d frames %d->%d dec=%.3f estimate=%.3f", TAG, brk_n, brk_v0, v, dec, BRK))
    end
  end
  if MLOG then print(string.format("%s K %d in=%s hb=%d so=%d lean=%d lat=%d v=%d d=%d skid=%d D=%d,%d sk=%d wr=%s", TAG, k, pd.left and "L" or (pd.right and "R" or "N"), L.u16(0xFFC73C), L.s16(0xFF063A), L.s16(0xFFC978), lat, v, L.u16(0xFF0616), L.u16(0xFF066A), L.s16(0xFF0BA6), L.s16(0xFF0CB8), L.u16(0xFF065A), table.concat(wr, ","))); wr = {} end
  L.pad(pd)
  if rendering and LOG > 0 and k % LOG == 0 then print(string.format("%s T k=%d d=%d lap=%d st=%d r=%d lat=%d tgt=%d s=%d sd=%d v=%d skid=%d pm=%s push=%.1f D=%d %s%s", TAG, k, d, lap, st, cur[2], lat, target, s, math.floor(sd), v, L.u16(0xFF066A), pm and string.format("%.1f", pm) or "-", push, L.s16(0xFF0BA6) - L.s16(0xFF0CB8), want_a and "A" or "-", want_b and "B" or "-")) end
end }
