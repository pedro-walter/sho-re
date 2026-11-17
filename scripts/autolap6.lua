-- Autopilot v6: model-predictive steering from the EXACT lateral model of the game (tools/steermodel.py, docs/12-steering-model.md).
-- The plan only has two numbers per curve:  vt = entry speed (raw units), a = entry position (fraction of 240 toward the inside edge at the curve start).
-- Everything else is computed:
--   * every game tick (3 frames) the handlebar / lean / lateral state is read and the next pad command is chosen by `policy`: a feedback law that
--     tracks a target lateral line with a braking-distance-limited lateral speed (constant BRL calibrated at start-up by simulating the real model);
--   * the target line is the curve's entry position; the switch from the current line to the next curve's entry position is made at the LATEST tick for
--     which a forward simulation of the same policy still arrives on the entry position when the curve starts (this is the "when to start counter-steering");
--   * speed: brake so as to arrive at vt on the curve start (braking-distance envelope, learned deceleration), full throttle otherwise.
-- Env: SHO_PLAN (plan file: [curve start] = {vt=, a=}), SHO_TRACK, SHO_TIRE/FRAME/ENGINE/OIL/MUFFLER/BRAKET, SHO_LOADSTATE, SHO_LOG, SHO_SNAP, SHO_ONELAP,
--      SHO_STOPTURN, SHO_STARTAFTER, SHO_STARTV, SHO_MLOG (per-frame model log), SHO_NOBOTS, SHO_TAG, SHO_FRAMES
local L = dofile(os.getenv("SHO_ROOT") .. "/scripts/lib.lua")
local function envn(k, d) return tonumber(os.getenv(k) or d) end
local rival = envn("SHO_RIVAL", 0)
local E, O, T, F = envn("SHO_ENGINE", 0), envn("SHO_OIL", 0), envn("SHO_TIRE", 0), envn("SHO_FRAME", 0)
local MUFF = envn("SHO_MUFFLER", 0)
local TRACK = envn("SHO_TRACK", rival + 1)
local TAG = os.getenv("SHO_TAG") or "A6"
local LOG = envn("SHO_LOG", 0)
local INE = envn("SHO_INE", 240)               -- inside edge distance for a = 1
local KP = envn("SHO_KP", 0.25)                -- lateral speed per unit of position error (per tick)
local EPS = envn("SHO_EPS", 3)                 -- allowed error on the entry position (units)
local SWIN = envn("SHO_SWIN", 6)               -- ticks after the curve start over which the entry error is judged
local BMARG = envn("SHO_BMARG", 1.25)
local NOBOTS = os.getenv("SHO_NOBOTS") ~= nil
local MLOG = os.getenv("SHO_MLOG") ~= nil
local LOADSTATE = os.getenv("SHO_LOADSTATE")
local STARTAFTER, STOPTURN = envn("SHO_STARTAFTER", nil), envn("SHO_STOPTURN", nil)
local plan = os.getenv("SHO_PLAN") and dofile(os.getenv("SHO_PLAN")) or {}
local okp, prof = pcall(dofile, os.getenv("SHO_ROOT") .. "/data/roadprofile_track" .. TRACK .. ".lua")
if not okp then prof = nil end
local VMAX = 241
local ABORT = envn("SHO_ABORT", 0)             -- end the run when the skid frames exceed this (searches: hopeless laps)
local MULT = ({ 3, 4, 6, 6, 8, 8 })[E + 1] + (O + MUFF) / 4
local TIREADJ = { 32, 20, 8, -4, -16 }
local DIV = 128 + TIREADJ[T + 1]
local FRT = { { 2, 3, 6 }, { 2, 4, 8 }, { 2, 4, 9 }, { 3, 5, 11 }, { 4, 7, 16 }, { 5, 8, 18 } }
local FR = FRT[F + 1]
local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
local BRK, BRKW = 0.95, 20                      -- brake deceleration per frame (learned online)
local DPFX = 269 / 65536 / 3                    -- distance units per frame per unit of speed on a straight (exact: 269*v/65536 per tick)

---------------------------------------------------------------- road
local segs = nil
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
  local tn = 0
  for i = 1, #segs do
    if segs[i][3] ~= 1 then
      tn = tn + 1; segs[i].tn = tn
      local pl = plan[segs[i][1]] or {}
      segs[i].vt = pl.vt            -- nil = automatic (computed from the exact model once the model exists)
      segs[i].a = pl.a or 1.0
      segs[i].cruise = pl.cruise and pl.cruise ~= 0   -- optional: keep a constant speed through this curve (the entry speed) instead of accelerating
      segs[i].line = ((segs[i][3] == 3) and 1 or -1) * segs[i].a * INE   -- lateral entry position (inside = +lat in state 3, -lat in state 2)
      print(string.format("%s TURN %d start=%d len=%d dir=%s r=%d", TAG, tn, segs[i][1], segs[i][4] - segs[i][1], segs[i][3] == 2 and "R" or "L", segs[i][2]))
    end
  end
  print(string.format("%s SEGS n=%d profile=%s mult=%.2f div=%d", TAG, #segs, prof and "yes" or "NO", MULT, DIV))
end
local function seg_index(d)
  for i = #segs, 1, -1 do if d >= segs[i][1] then return i end end
  return 1
end
local function profile(dist)
  local d = floor(dist) % 2048
  if prof then return prof[d + 1] or 0 end
  local sg = segs[seg_index(d)]
  if sg[3] == 1 then return 0 end
  local m = floor(410 / sg[2] + 0.5)
  return (sg[3] == 2) and m or -m
end
-- next curve (index into segs) whose start lies ahead of d; returns idx, absolute start distance (may be +2048)
local function next_curve(d)
  for i = seg_index(d) + 1, #segs do if segs[i][3] ~= 1 then return i, segs[i][1] end end
  for i = 2, #segs do if segs[i][3] ~= 1 then return i, segs[i][1] + 2048 end end
end

---------------------------------------------------------------- speed policy (shared by the real controller and the simulation)
-- brake / throttle decision from the speed v at lap distance d: arrive at each upcoming curve with its vt
local SIM_THROTTLE = false
local MD    -- the model (defined below)
-- brake / throttle decision from the speed v at lap distance d with brake position bpos: arrive at each upcoming curve with its vt, braking at the latest tick (exact brake model)
local function speed_cmd(v, d, bpos)
  if SIM_THROTTLE then return false, true end
  d = d % 2048
  local want_b, want_a = true, false
  local cs = segs[seg_index(d)]
  if cs[3] ~= 1 and cs.cruise then
    local vh = cs.cruise_v or ((cs.vt and cs.vt < 900) and cs.vt or nil)   -- the speed at the curve entry (captured by the controller)
    if vh then want_b = v < vh end
  end
  local j = seg_index(d) + 1
  local dist_to = segs[seg_index(d)][4] - d
  local seen = 0
  while seen < 4 do
    local sg = segs[j] or segs[((j - 1) % #segs) + 1]
    if sg[3] ~= 1 and sg.vt and sg.vt < 900 then
      local vl = sg.vt
      if v > vl - 1 then
        local bd = MD.brake_dist(v, vl, bpos or 1) * BMARG + 2
        if dist_to <= bd + 0.0041 * v * 1.5 then want_a = true end
        if dist_to <= bd + 12 then want_b = false end
      elseif v >= vl - 4 and dist_to < 12 then want_b = false end
    end
    dist_to = dist_to + (sg[4] - sg[1]); j = j + 1; seen = seen + 1
    if dist_to > 250 then break end
  end
  return want_a, want_b
end

---------------------------------------------------------------- exact model + planner (scripts/model6.lua)
MD = dofile(os.getenv("SHO_ROOT") .. "/scripts/model6.lua").new{
  tire = T, frame = F, engine = E, braket = envn("SHO_BRAKET", 0), mult = MULT, vmax = VMAX,
  profile = function(dist) return profile(dist) end,
  road = function(dist) local sg = segs[seg_index(dist % 2048)]; return sg[3], sg[2] end,
  speed_cmd = function(v, d, bp) return speed_cmd(v, d, bp) end,
  brk = function() return BRK end, pred = true, hold_h = envn("SHO_HOLDH", 9), hold_h2 = envn("SHO_HOLDH2", 15), sat_hold = envn("SHO_SATHOLD", T >= 1 and 120 or 0) }
MD.VLATMAX = math.abs(MD.lateral(127, 200, false)) * 0.95
local function ticks_to(S0, sd)               -- ticks until the lap distance reaches sd (speed policy only)
  local S = MD.copy(S0)
  for t = 1, 700 do
    if S.dist >= sd then return t - 1 end
    local vi = math.floor(S.v)
    local sg = segs[seg_index(S.dist % 2048)]
    local g = (sg[3] <= 1) and 269 * vi or MD.tdiv(269 * (sg[2] + MD.tdiv((sg[3] == 3) and S.lat or -S.lat, 40)), sg[2]) * vi
    S.dist = S.dist + g / 65536
    MD.vstep(S)
  end
  return 700
end
-- highest entry speed at which the bike, entering on its line and holding it with the predictive law at full throttle, never leaves the road (|lat| <= VTLIM) in this curve
local VTLIM = envn("SHO_VTLIM", 290)
local function sim_curve_ok(sg, v0)
  SIM_THROTTLE = true
  -- the real situation: arriving on the line with a relaxed handlebar 25 ticks before the curve (the steering has to be built up by the controller itself)
  local S = { hb = 128, so = 0, lean = 0, lat = sg.line, v = v0, dist = sg[1] - 25 * 269 * v0 / 65536, skid = false, bpos = 1, tpos = 168 }
  local ok = true
  for t = 1, 500 do
    if S.dist >= sg[4] + 1 then break end
    MD.step(S, MD.hold(S, sg.line))
    if abs(S.lat) > VTLIM then ok = false; break end
  end
  SIM_THROTTLE = false
  return ok
end
local function auto_vt(sg)
  if sim_curve_ok(sg, 241) then return 999 end
  local lo, hi = 40, 241                      -- lo ok (assumed), hi not ok
  while hi - lo > 2 do
    local mid = (lo + hi) // 2
    if sim_curve_ok(sg, mid) then lo = mid else hi = mid end
  end
  return lo
end

---------------------------------------------------------------- main loop
local ticks, lastticks = 0, 0
L.watch_write(0xFFC73C, 0xFFC73D, function() ticks = ticks + 1 end)
local wr = {}
if MLOG then L.watch_write(0xFF0614, 0xFF0615, function(off, data, mask, pc) local dl = data - L.s16(0xFF0614); if dl > 32767 then dl = dl - 65536 elseif dl < -32768 then dl = dl + 65536 end; wr[#wr + 1] = string.format("%X:%d", pc, dl) end) end
local HOLDEND = tonumber(os.getenv("SHO_HOLDEND") or 10)
local APPR = tonumber(os.getenv("SHO_APPR") or 50)   -- approach planning only for curves whose steady steering need at the entry is at least this (of 127); 999 = off
local appr_seg = nil
local APPRONLY = nil
if os.getenv("SHO_APPRONLY") then APPRONLY = {}; for n in os.getenv("SHO_APPRONLY"):gmatch("%d+") do APPRONLY[tonumber(n)] = true end end
local cmd, tgt_line = 0, 0
local want_a, want_b = false, true
local started, rendering = false, (STARTAFTER == nil)
local t0, lastlap, skidf, offf, lapstart = nil, 0, 0, 0, 0
local maxv, sumv, nv, brakef = 0, 0, 0, 0
local brk_on, brk_v0, brk_n = false, 0, 0
local startd, stopd
local entered_seg = nil
local chk = nil
local EPS_OV = envn("SHO_EPSOV", 12)           -- a plan that still overshoots the entry line by more than this means: wait
local EXF = envn("SHO_EXF", 1.5)             -- extra allowed overshoot per unit of entry position beyond the road edge
local EXMAX = envn("SHO_EXMAX", 60)            -- cap of that extra overshoot
local SWTMAX = envn("SHO_SWTMAX", 90)          -- plan the move to the next curve's entry line only when it is at most this many ticks away (longer horizons make bad plans)
local ARRM = envn("SHO_ARRM", 1)                -- start the move so that it is predicted to arrive this many ticks before the curve starts

L.run{ frames = envn("SHO_FRAMES", 26000), input = {}, on_frame = function(f)
  if LOADSTATE and f == 2 then manager.machine:load(LOADSTATE) end
  if NOBOTS then for a = 0xFFCC40, 0xFFCD40, 0x40 do L.mem:write_u16(a, 0) end; L.mem:write_u16(0xFF0690, 0) end
  local mode_ = L.u16(0xFFC704) & 0x7FFC
  if mode_ ~= 0x18 then
    if started then print(string.format("%s END frame=%d race_frames=%d skid_frames=%d brake_frames=%d maxv=%d avgv=%d", TAG, f, f - t0, skidf, brakef, maxv, sumv // math.max(nv, 1))); manager.machine:exit() end
    return
  end
  L.mem:write_u16(0xFFB618, F); L.mem:write_u16(0xFFB61A, E); L.mem:write_u16(0xFFB620, O); L.mem:write_u16(0xFFB622, T)
  L.mem:write_u16(0xFFB61C, envn("SHO_BRAKET", 0)); L.mem:write_u16(0xFFB61E, MUFF)
  for i = 0, 5 do L.mem:write_u16(0xFFB648 + 2 * i, 15) end
  if L.u16(0xFF0616) == 0 and not started then return end
  if not started then
    started = true; load_segs()
    for i = 1, #segs do if segs[i][3] ~= 1 and segs[i].vt == nil then segs[i].vt = auto_vt(segs[i]); print(string.format("%s AUTO vt turn=%d r=%d -> %s", TAG, segs[i].tn, segs[i][2], tostring(segs[i].vt))) end end
  end
  t0 = t0 or f
  local k = f - t0
  if k <= 2 and not STARTAFTER and os.getenv("SHO_STARTV") and tonumber(os.getenv("SHO_STARTV")) > 0 then L.mem:write_u16(0xFF064A, tonumber(os.getenv("SHO_STARTV"))) end
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
  if STOPTURN and lap == 0 and not stopd then for i = 1, #segs do if segs[i].tn == STOPTURN then stopd = segs[i][4] end end; stopd = stopd or 99999 end
  if STOPTURN and lap == 0 and d >= stopd and d < stopd + 200 then print(string.format("%s STOP at end of turn %d k=%d d=%d", TAG, STOPTURN, k, d)); manager.machine:exit() end
  if lap ~= lastlap then
    print(string.format("%s LAP %d->%d at k=%d (%.2f s) lap_frames=%d", TAG, lastlap, lap, k, k / 60, k - lapstart)); lastlap = lap; lapstart = k
    lapsdone = (lapsdone or 0) + 1
    if os.getenv("SHO_ONELAP") and lapsdone >= (tonumber(os.getenv("SHO_ONELAP")) or 1) then manager.machine:exit() end
  end
  if v > maxv then maxv = v end
  sumv = sumv + v; nv = nv + 1
  if L.u16(0xFF066A) ~= 0 then skidf = skidf + 1 end
  if ABORT > 0 and skidf > ABORT then print(string.format("%s ABORT skid frames %d at k=%d d=%d", TAG, skidf, k, d)); manager.machine:exit() end
  if abs(lat) > 270 then offf = offf + 1 end

  local i = seg_index(d)
  local cur = segs[i]
  local nj, nsd = next_curve(d)
  local nxt = segs[nj]
  local dnext = nsd - d

  -- ---- steering decision, once per game tick (right after the handlebar update)
  if ticks ~= lastticks then
    lastticks = ticks
    local S = { hb = L.u16(0xFFC73C), so = s, lean = (function() local l = L.s16(0xFFC978); if l > 127 or l < -127 then l = s end; return l end)(), lat = lat, v = v + L.u16(0xFF064C) / 65536, dist = L.u16(0xFF0616) + L.u16(0xFF0618) / 65536,
                skid = L.u16(0xFF066A) ~= 0, bpos = math.max(1, L.u16(0xFFC73A)), tpos = math.max(1, L.u16(0xFFC738)), pa = want_a, pb = want_b }
    -- first tick inside a curve: its entry line is the target (normally the move there was already made)
    if cur[3] ~= 1 and entered_seg ~= i then
      entered_seg = i
      print(string.format("%s ENTER turn=%d d=%d lat=%d line=%d err=%d v=%d (vt=%s) tgt_was=%d", TAG, cur.tn, d, lat, cur.line, lat - cur.line, v, tostring(cur.vt), tgt_line))
      tgt_line = cur.line
      if cur.cruise then cur.cruise_v = v end
    end
    -- the move to the next curve's entry line starts at the latest tick for which it is still predicted to arrive in time
    -- on the straight before a curve with a strong push: prepare the entry. The approach planner (model6 `approach`) goes towards the outside first and then swings in with the
    -- steering pressed all the way, so the lock is already full when the curve starts. It is tried once per curve; when it finds nothing better the normal move below is used.
    if nxt and cur ~= nxt and appr_seg ~= nj and APPR < 900 and (cur[3] == 1 or (cur[4] - d) <= HOLDEND) then
      appr_seg = nj
      local sdn0 = nsd; if sdn0 < S.dist - 1 then sdn0 = sdn0 + 2048 end
      local _, sso = MD.hb_ss(S, sdn0 + 6)
      if math.abs(sso) >= APPR and (not APPRONLY or APPRONLY[nxt.tn]) then
        local pl = MD.approach(S, nxt.line, sdn0, nxt[3] == 3 and 1 or -1, math.abs(sso))
        if not pl then print(string.format("%s APPROACH none turn=%d d=%d lat=%d sso=%d", TAG, nxt.tn, d, lat, sso)) end
        if pl and pl.rec.n > 150 then pl = nil end
        if pl then
          MD.cur = pl; tgt_line = nxt.line; if os.getenv("SHO_PCHK") then chk = { rec = nil, n = 0 } end
          print(string.format("%s APPROACH turn=%d d=%d lat=%d line=%d pre=%d lean_entry=%d err=%d ticks=%d", TAG, nxt.tn, d, lat, nxt.line, pl.pre, pl.lean_in, pl.err, pl.rec.n))
        end
      end
    end
    if nxt and tgt_line ~= nxt.line and cur ~= nxt then
      local sd = nsd; if sd < S.dist - 1 then sd = sd + 2048 end
      local sw = false
      -- moving to a less-inside line for a same-direction next curve while the current curve's push still acts: wait until the current curve is almost over
      local hold_in = cur[3] ~= 1 and nxt[3] == cur[3] and math.abs(nxt.line) < math.abs(tgt_line) - 20 and (cur[4] - d) > HOLDEND
      if hold_in then
      elseif dnext < 1 then sw = true
      else
        local tte = ticks_to(S, sd)
        if tte < SWTMAX then
          -- an entry position beyond the road edge (a > 1) cannot be reached exactly in time (the real bike lags the model off the road): allow the plan to overshoot it, i.e. start the move earlier
          local eo = EPS_OV + math.min(EXMAX, EXF * math.max(0, math.abs(nxt.line) - INE))
          local pl = MD.best_plan(S, nxt.line, sd)
          local ent = pl.rec.entry_t or tte
          if (pl.tarr + ARRM >= ent and pl.err <= eo) or pl.err < -40 then sw = true end
          if os.getenv("SHO_SWDBG") then print(string.format("%s SWD turn=%d d=%d lat=%d tte=%d tarr=%d ent=%s err=%.0f", TAG, nxt.tn, d, lat, tte, pl.tarr, tostring(pl.rec.entry_t), pl.err)) end
          if sw then print(string.format("%s SWITCH turn=%d d=%d lat=%d v=%.0f hb=%d lean=%d line=%d->%d tte=%d tarr=%d plan_err=%.0f a=%d cap=%d rec_n=%d entry_t=%s sd=%.1f", TAG, nxt.tn, d, lat, S.v, S.hb, S.lean, tgt_line, nxt.line, tte, pl.tarr, pl.err, pl.a, pl.cap, pl.rec.n, tostring(pl.rec.entry_t), sd)) end
        end
      end
      if sw then tgt_line = nxt.line; if os.getenv("SHO_PCHK") then chk = { rec = nil, n = 0 } end end
    end
    local pl_used
    local sdn = nil
    if nxt and tgt_line == nxt.line and cur ~= nxt then sdn = nsd; if sdn < S.dist - 1 then sdn = sdn + 2048 end end
    cmd, pl_used = MD.next_cmd(S, tgt_line, sdn)
    if os.getenv("SHO_NCDBG") and d >= (tonumber(os.getenv("SHO_NCD0")) or 1540) and d < (tonumber(os.getenv("SHO_NCD1")) or 1585) then print(string.format("%s NC d=%d lat=%d hb=%d lean=%d v=%.0f cmd=%d i=%s n=%s tarr=%s err=%s predlat=%s sdn=%s", TAG, d, lat, S.hb, S.lean, S.v, cmd or 0, tostring(pl_used and pl_used.i), tostring(pl_used and pl_used.rec.n), tostring(pl_used and pl_used.tarr), tostring(pl_used and pl_used.err), tostring(pl_used and pl_used.rec.lat[(pl_used.i or 2)-2]), tostring(sdn))) end
    if chk then
      chk.n = chk.n + 1
      if pl_used and pl_used.rec and not chk.rec then chk.rec = pl_used.rec; chk.n = 1 end
      if chk.rec and chk.rec.lat[chk.n] and chk.n <= 130 then print(string.format("%s PC n=%d lat real=%d pred=%d | v real=%.1f pred=%.1f | d real=%.2f pred=%.2f | cmd=%d pad real A=%s B=%s sim A=%s B=%s", TAG, chk.n, S.lat, chk.rec.lat[chk.n - 1] or S.lat, S.v, chk.rec.v[chk.n - 1] or S.v, S.dist, chk.rec.d[chk.n - 1] or S.dist, cmd, tostring(want_a), tostring(want_b), tostring(chk.rec.pa[chk.n - 1]), tostring(chk.rec.pb[chk.n - 1]))) elseif chk.n > 130 then chk = nil end
    end
  end

  -- ---- speed
  want_a, want_b = speed_cmd(v + L.u16(0xFF064C) / 65536, L.u16(0xFF0616) + L.u16(0xFF0618) / 65536, math.max(1, L.u16(0xFFC73A)))
  local pd = { left = cmd == 1, right = cmd == -1, b = want_b, a = want_a }
  if rendering and os.getenv("SHO_SNAP") and k % tonumber(os.getenv("SHO_SNAP")) == 0 then
    L.snapshot(string.format("rec/%s_%05d.png", TAG, k))
    print(string.format("REC %d %d %d %d %d %d %d %d %d %d %d", k, d, cur.tn or 0, cur[3], cur[2], lat, v, L.u16(0xFF066A) ~= 0 and 1 or 0, nxt and nxt.tn or 0, math.floor(dnext), (function() local l = L.s16(0xFFC978); if l > 127 or l < -127 then l = 0 end; return l end)()))
  end
  if want_a then
    brakef = brakef + 1
    if not brk_on then brk_on = true; brk_v0 = v; brk_n = 0 end
    brk_n = brk_n + 1
  elseif brk_on then
    brk_on = false
    if brk_n >= 8 then
      local dec = max(0.3, min(3, (brk_v0 - v) / brk_n))
      BRK = (BRK * BRKW + dec * brk_n) / (BRKW + brk_n); BRKW = min(300, BRKW + brk_n)
    end
  end
  if MLOG then print(string.format("%s K %d in=%s hb=%d so=%d lean=%d lat=%d v=%d d=%d skid=%d D=%d,%d sk=%d wr=%s", TAG, k, cmd == 1 and "L" or (cmd == -1 and "R" or "N"), L.u16(0xFFC73C), s, L.s16(0xFFC978), lat, v, L.u16(0xFF0616), L.u16(0xFF066A), L.s16(0xFF0BA6), L.s16(0xFF0CB8), L.u16(0xFF065A), table.concat(wr, ","))); wr = {} end
  L.pad(pd)
  if rendering and LOG > 0 and k % LOG == 0 then
    print(string.format("%s T k=%d d=%d lap=%d st=%d r=%d lat=%d tgt=%d s=%d sd=%d v=%d skid=%d pm=- push=%.1f D=%d %s%s", TAG, k, d, lap, st, cur[2], lat, tgt_line, s, 0, v, L.u16(0xFF066A), (profile(d) or 0) * 1.0, L.s16(0xFF0BA6) - L.s16(0xFF0CB8), want_a and "A" or "-", want_b and "B" or "-"))
  end
end }
