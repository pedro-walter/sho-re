-- Exact per-tick model of the steering / lateral chain of Super Hang-On (Genesis) + the steering policy used by autolap6.lua.
-- Validated against the emulator by tools/steermodel.py (docs/12-steering-model.md). No emulator access in here, so it can be tested headless (scripts/model6test.lua).
-- cfg: tire, frame, engine, braket (tiers), mult (acceleration multiplier), vmax, profile(dist) -> Dc (road push buffer / 64), road(dist) -> state, radius,
--      speed_cmd(v, d) -> want_a (brake), want_b (throttle), brk() -> brake deceleration per frame
local M = {}
function M.new(cfg)
  local self = {}
  local floor, abs, min, max, sqrt = math.floor, math.abs, math.min, math.max, math.sqrt
  local TIREADJ = { 32, 20, 8, -4, -16 }
  local FRT = { { 2, 3, 6 }, { 2, 4, 8 }, { 2, 4, 9 }, { 3, 5, 11 }, { 4, 7, 16 }, { 5, 8, 18 } }
  local T, F = cfg.tire, cfg.frame
  local DIV = 128 + TIREADJ[T + 1]
  local FR = FRT[F + 1]
  local MULT, VMAX = cfg.mult or 3, cfg.vmax or 241
  local profile, road, speed_cmd = cfg.profile, cfg.road, cfg.speed_cmd
  local KP = cfg.kp or 0.25
  local PULSE, IDLE = cfg.pulse or 8, cfg.idle or 2
  self.DIV = DIV

  local function tdiv(a, b) local q = abs(a) // abs(b); if (a < 0) ~= (b < 0) then q = -q end; return q end
  -- handlebar after one tick. cmd: 1 = left pad (handlebar up), -1 = right pad, 0 = none
  local function ctrl(hb, cmd, vi)
    local d1, d2, d3 = FR[1], FR[2], FR[3]
    if F >= 2 then local s = vi >> 7; d1, d2, d3 = d1 + s, d2 + s, d3 + s end
    if cmd == 1 then
      if hb < 0x80 then hb = hb + d3 else hb = hb + d2; if hb >= 0xC7 then hb = 0xC6 end end
    elseif cmd == -1 then
      if hb >= 0x80 then hb = hb - d3 else hb = hb - d2; if hb < 0x3A then hb = 0x3A end end
    else
      if hb < 0x80 then hb = hb + d1 elseif hb > 0x80 then hb = hb - d1 end
    end
    return hb
  end
  local function steer_out(hb)
    local d = min(0xC6, max(0x3A, hb))
    if d >= 0x6C and d <= 0x94 then d = 0x80 end
    return -min(0x7F, max(-127, tdiv((d - 0x80) << 8, 0x8C)))
  end
  local function lean_step(lean, so) return lean + max(-12, min(12, so - lean)) end
  local function lateral(lean, vi, skid)
    local d = lean
    if not skid and vi <= 0x7F then d = (d * vi) // 128 end
    return 2 * -tdiv(d << 4, DIV)
  end
  local function push_of(dc, vi)
    if dc == 0 then return 0 end
    local q = tdiv(dc * vi, 110)
    return 2 * (q + ((q >= 0) and 1 or -1))
  end
  self.tdiv, self.ctrl, self.steer_out, self.lean_step, self.lateral, self.push_of = tdiv, ctrl, steer_out, lean_step, lateral, push_of

  -- speed model (sub_009B40): throttle accel mult*(279-v)/1024 per tick; coasting drag; brake force = 1.55 * n(brake_pos) per tick on top, brake_pos building by the tier rate per tick
  local BRATE = ({ 2, 4, 7, 12, 16 })[(cfg.braket or 0) + 1]
  local E = cfg.engine or 0
  local DRAG = 0.775 * ((E < 2) and 1 or ((E < 4) and 2 or 4))
  local function bn(pos) local f = ((pos - 1) * 256) // 197; if f < 1 then return 0 elseif f < 48 then return 1 elseif f < 112 then return 2 elseif f < 192 then return 3 else return 4 end end
  -- the pad state used for a tick's speed update is the one decided after the PREVIOUS tick (S.pa / S.pb), like the real pad lag
  local function vstep(S)
    local wa, wb = S.pa, S.pb
    if wa == nil then wa, wb = speed_cmd(S.v, S.dist, S.bpos or 1) end
    if wa then S.bpos = min(197, (S.bpos or 1) + BRATE) else S.bpos = 1 end
    -- throttle position: +20 per tick held (max 168), -15 per tick released (min 1); its target speed = 279 * min(127, (pos-1)*160/168) / 127
    local tp = S.tpos or 168
    if wb then tp = min(168, tp + 20) else tp = max(1, tp - 15) end
    S.tpos = tp
    local target = (279 * min(127, ((tp - 1) * 160) // 168)) // 127
    local vi = floor(S.v)
    local acc = MULT * (279 - S.v) / 1024
    local dv
    if vi < 80 then dv = acc
    elseif vi > target then dv = -DRAG
    elseif vi < target then dv = acc
    else dv = 0 end
    if wa then dv = dv - 1.55 * bn(S.bpos) end
    local v = max(0, S.v + dv)
    if v > VMAX then v = max(VMAX, S.v - 2) end
    S.v = v
  end
  -- distance (units) needed to slow from v0 to vt when braking from now (brake position bpos0)
  function self.brake_dist(v0, vt, bpos0)
    local v, pos, dist = v0, bpos0 or 1, 0
    for _ = 1, 400 do
      if v <= vt then break end
      pos = min(197, pos + BRATE)
      dist = dist + 269 * v / 65536
      v = v - DRAG - 1.55 * bn(pos)
    end
    return dist
  end
  -- S: {hb, so, lean, lat, v, dist, skid, acc}; one game tick with the pad command `cmd` held for it
  local function step(S, cmd)
    local vi = floor(S.v)
    S.lean = lean_step(S.lean, S.so)
    S.Wr = lateral(S.lean, vi, S.skid)
    local lat = S.lat + S.Wr
    if lat > 500 then lat = 500 elseif lat < -500 then lat = -500 end
    S.skid = abs(lat) > 300
    S.hb = ctrl(S.hb, cmd, vi)
    S.so = steer_out(S.hb)
    local p = push_of(profile(S.dist), vi)
    if p ~= 0 and abs(lat + p) <= 500 then lat = lat + p end
    S.lat = lat
    local st, r = road(S.dist)
    local g
    if st <= 1 then g = 269 * vi else
      local side = (st == 3) and lat or -lat
      g = tdiv(269 * (r + tdiv(side, 40)), r) * vi
    end
    S.dist = S.dist + g / 65536
    vstep(S)
    S.pa, S.pb = speed_cmd(S.v, S.dist, S.bpos or 1)
  end
  self.step = step
  self.vstep = vstep
  function self.copy(S) return { hb = S.hb, so = S.so, lean = S.lean, lat = S.lat, v = S.v, dist = S.dist, skid = S.skid, acc = S.acc, Wd = S.Wd, Wr = S.Wr, bpos = S.bpos, pa = S.pa, pb = S.pb, tpos = S.tpos } end

  -- policy: pad command that tracks the lateral line `target`.
  -- lateral speed wanted vd = clamp(KP*err, +-min(VLATMAX, BRL*sqrt(|err|))); the steering must supply vd - push per tick; that needs lean so_t, which needs a handlebar value hb_t
  -- (dead zone: |steer_out| jumps from 0 to 38 -> sigma-delta between them); the command is the one whose handlebar lands closest to hb_t.
  self.BRL, self.VLATMAX = 2.0, 20
  self.LOOK = cfg.look or 8
  function self.policy(S, target)
    local vi = floor(S.v)
    local err = target - S.lat
    local vmax = min(self.VLATMAX, self.BRL * sqrt(abs(err)))
    local vd = max(-vmax, min(vmax, KP * err))
    local p = push_of(profile(S.dist + self.LOOK * 269 * vi / 65536), vi)    -- feed-forward: the push a few ticks ahead (the handlebar needs that long to leave its dead zone)
    local W = vd - p
    local vv = (vi > 127 or S.skid) and 1 or max(vi, 20) / 128
    local so_t = -W * DIV / (32 * vv)                 -- steer_out needed (sign: + = right pad)
    if so_t > 127 then so_t = 127 elseif so_t < -127 then so_t = -127 end
    -- handlebar target. |so| >= 38 is outside the dead zone (continuous map); smaller needs are pulses: park at the dead-zone edge, pulse when the need is large enough
    local a = abs(so_t)
    local hbt = (a >= 38) and (128 - so_t * 140 / 256) or 128   -- below the dead zone the needed steering cannot be produced continuously: stay neutral (the planner does corrections)
    local best, bc = 1e9, 0
    for c = 0, 2 do
      local cc = (c == 2) and -1 or c
      local e = abs(ctrl(S.hb, cc, vi) - hbt)
      if e < best - 1e-9 then best = e; bc = cc end
    end
    return bc
  end

  -- predictive hold: the command (held for `h` ticks) whose exact predicted lateral position is closest to the target (ties: neutral). Feed-forward is inherent (profile in step()).
  self.H = cfg.hold_h or 9
  self.H2 = cfg.hold_h2 or 15            -- longer horizon while a stronger push is coming (the handlebar needs ~14 ticks to get out of its dead zone)
  function self.policy_pred(S, target)
    local vi = floor(S.v)
    local dpt = 269 * vi / 65536
    local H = self.H
    if abs(push_of(profile(S.dist + 22 * dpt), vi)) - abs(push_of(profile(S.dist), vi)) >= 6 then H = self.H2 end
    local best, bc = 1e18, 0
    for c = 0, 2 do
      local cc = (c == 2) and -1 or c
      local X = self.copy(S)
      local cost = 0
      for j = 1, H do step(X, cc); local e = X.lat - target; cost = cost + ((j >= H - 1) and 3 or 1) * e * e end
      if cost < best - 1e-9 then best = cost; bc = cc end
    end
    return bc
  end
  -- ------------------------------------------------------------------ planned moves (exact shooting)
  -- press(): the pad command that drives the handlebar toward steering level `cap` in direction dir (dir = +1: lateral position increasing = left pad)
  local function press(S, dir, cap)
    if cap >= 127 then return dir end
    local so = -S.so * dir                              -- steer_out > 0 = lean toward -lat; so = steering toward dir, in [-127,127]
    if so < cap then return dir else return 0 end
  end
  -- steady handlebar that balances the road push at lap distance `at` (neutral on a straight)
  local function hb_ss(S, at)
    local vi = floor(S.v)
    local p = push_of(profile(at), vi)
    local vv = (vi > 127 or S.skid) and 1 or max(vi, 20) / 128
    local so = p * DIV / (32 * vv)
    if abs(so) >= 38 then return 128 - so * 140 / 256, max(-127, min(127, so)) end
    return 128, 0
  end
  -- handlebar target while settling: the steady level for the push NOW, but once the entry (distance sd, where the push changes) is closer than the time the handlebar
  -- needs to travel to the steady level there, the level at the entry (latest start of the reversal)
  local function hb_target(S, sd)
    local vi = floor(S.v)
    local dpt = 269 * vi / 65536
    local hbn, son = hb_ss(S, S.dist + 2 * dpt)
    if sd and S.dist < sd then
      local hbf, sof = hb_ss(S, sd + 6)
      local need = abs(hbf - S.hb) / max(2, FR[2]) + 3
      if (sd - S.dist) / math.max(dpt, 0.05) <= need then return hbf, sof end
    end
    return hbn, son
  end
  -- settle(): after the press, drive the handlebar to its target level as fast as possible
  local function brake(S, dir, sd)
    local vi = floor(S.v)
    local hbt = hb_target(S, sd)
    local best, bc = 1e9, 0
    for c = 0, 2 do
      local cc = (c == 2) and -1 or c
      local e = abs(ctrl(S.hb, cc, vi) - hbt)
      if e < best - 1e-9 then best = e; bc = cc end
    end
    return bc
  end
  local function settled(S, sd)
    local hbt, sso = hb_target(S, sd)
    if sso == 0 then return abs(S.lean) <= 3 and S.hb >= 108 and S.hb <= 148 end
    return abs(S.hb - hbt) <= 4 and abs(S.lean - sso) <= 10
  end
  -- simulate: press dir for `a` ticks, brake until settled, then hold `target` for H ticks. Returns signed error dir*(lat - target) at the end, tick of last |err|>10, total ticks
  local function sim_plan(S0, T0, dir, a, cap, H, rec, sd)
    local S = self.copy(S0)
    local t, last_out, e_entry = 0, 0, nil
    local function chk(c)
      t = t + 1
      if abs(S.lat - T0) > 10 then last_out = t end
      if sd and not e_entry and S.dist >= sd then e_entry = dir * (S.lat - T0); if rec then rec.entry_t = t end end
      if rec then rec.cmds[t] = c; rec.lat[t] = S.lat; rec.hb[t] = S.hb; rec.v[t] = S.v; rec.d[t] = S.dist; rec.pa[t] = S.pa and 1 or 0; rec.pb[t] = S.pb and 1 or 0 end
    end
    for _ = 1, a do local c = press(S, dir, cap); step(S, c); chk(c) end
    local n = 0
    while n < 60 and not settled(S, sd) do local c = brake(S, dir, sd); step(S, c); chk(c); n = n + 1 end
    if rec then rec.n = t end
    local nh = H
    if sd then nh = 0; while S.dist < sd and nh < 200 do local c = brake(S, dir, sd); step(S, c); chk(c); nh = nh + 1 end; if rec then rec.n = t end end
    for _ = 1, (sd and 4 or H) do local c = self.hold(S, T0); step(S, c); chk(c) end
    local ee = e_entry or dir * (S.lat - T0)
    return ee, last_out + 1, t
  end
  self.sim_plan = sim_plan
  self.AMAX = cfg.amax or 70
  -- best plan to move to T0 from state S0: returns {cmd, err (signed, + = beyond), tarr (ticks until within 10 and staying), a, cap}
  function self.best_plan(S0, T0, sd)
    local dir = (T0 >= S0.lat) and 1 or -1
    local best
    for _, cap in ipairs({ 127, 70, 45 }) do
      if best and abs(best.err) <= 6 then break end                     -- good enough: no need for the finer steering caps
      local e, tarr, a
      local e0, t0 = sim_plan(S0, T0, dir, 0, cap, 8, nil, sd)
      if e0 >= 0 then a, e, tarr = 0, e0, t0
      else
        -- coarse scan for the first sign change (the landing error grows with `a` until the bike reaches the wall)
        local lo, hi, ehi, thi = 0, nil, nil, nil
        local elast, tlast, alast = e0, t0, 0
        for aa = 5, self.AMAX, 5 do
          local ee, tt = sim_plan(S0, T0, dir, aa, cap, 8, nil, sd)
          if ee >= 0 then hi, ehi, thi = aa, ee, tt; break end
          lo = aa; elast, tlast, alast = ee, tt, aa
        end
        if not hi then a, e, tarr = alast, elast, tlast                  -- unreachable: the strongest plan found
        else
          while hi - lo > 1 do
            local mid = (lo + hi) // 2
            if sim_plan(S0, T0, dir, mid, cap, 8, nil, sd) >= 0 then hi = mid else lo = mid end
          end
          local e1, t1 = sim_plan(S0, T0, dir, hi, cap, 8, nil, sd)
          local e2, t2 = sim_plan(S0, T0, dir, lo, cap, 8, nil, sd)
          if abs(e2) < abs(e1) then a, e, tarr = lo, e2, t2 else a, e, tarr = hi, e1, t1 end
        end
      end
      local cand = { err = e, tarr = tarr, a = a, cap = cap, dir = dir }
      if not best or abs(cand.err) < abs(best.err) - 6 then best = cand end
    end
    local rec = { cmds = {}, lat = {}, hb = {}, v = {}, d = {}, pa = {}, pb = {} }
    sim_plan(S0, T0, dir, best.a, best.cap, 0, rec, sd)
    best.rec = rec; best.T = T0; best.i = 1; best.sd = sd
    return best
  end
  -- follow the committed plan (re-plan when the real state deviates from the prediction, or when the plan has run out and the target is not reached)
  self.hb_ss = hb_ss
  -- approach plan for the entry of a curve with a strong push: first move `pre` units towards the outside of the road (reaching a waypoint W), wait there, then press towards the
  -- inside until the entry (distance sd) so that the steering is already at full lock when the curve starts and the bike lands on the entry line T0. ins = +1 when the inside
  -- of the curve is +lat. Candidates for pre are tried from small to large; the first one that reaches `LFULL` lean at the entry (else the best one) is returned, nil when none
  -- is feasible or none beats the normal plan's entry lean by 20.
  self.LFULL = cfg.lfull or 115
  function self.approach(S0, T0, sd, ins, want)
    local LT = math.min(self.LFULL, (want or 127) + 25)
    local best
    local function run(S, W, w, rec)
      -- hold W for w ticks, then press inward until the entry; returns landing error (+ = beyond), lean (inward positive), peak |lat|
      local n, peak = 0, 0
      local function rc(c) n = n + 1; if rec then rec.cmds[#rec.cmds + 1] = c end; peak = math.max(peak, abs(S.lat)); if rec then rec.lat[#rec.lat + 1] = S.lat; rec.hb[#rec.hb + 1] = S.hb; rec.v[#rec.v + 1] = S.v; rec.d[#rec.d + 1] = S.dist; rec.pa[#rec.pa + 1] = S.pa and 1 or 0; rec.pb[#rec.pb + 1] = S.pb and 1 or 0 end end
      for _ = 1, w do local c = self.hold(S, W); step(S, c); rc(c) end
      local g = 0
      while S.dist < sd and g < 250 do local c = press(S, ins, 127); step(S, c); rc(c); g = g + 1 end
      return ins * (S.lat - T0), -ins * S.lean * (127 / 127), peak, n
    end
    for _, pre in ipairs({ 40, 80, 120, 160 }) do
      local W = T0 - ins * pre
      if abs(W) <= 250 then
        local pA = self.best_plan(S0, W, nil)
        local SA = self.copy(S0)
        local cA = {}
        for i = 1, pA.rec.n do step(SA, pA.rec.cmds[i]); cA[i] = pA.rec.cmds[i] end
        if SA.dist < sd - 1 then
          local e0 = run(self.copy(SA), W, 0)
          if e0 >= 0 then
            -- longest wait that still lands beyond the line: bisection on the wait w
            local lo, hi = 0, 1
            while hi < 400 do
              local Sx = self.copy(SA); local e = run(Sx, W, hi)
              if e < 0 then break end
              lo = hi; hi = hi * 2
            end
            while hi - lo > 1 do
              local mid = (lo + hi) // 2
              local e = run(self.copy(SA), W, mid)
              if e >= 0 then lo = mid else hi = mid end
            end
            local w = lo
            local e1 = run(self.copy(SA), W, lo); local e2 = run(self.copy(SA), W, lo + 1)
            if abs(e2) < abs(e1) then w = lo + 1 end
            local rec = { cmds = {}, lat = {}, hb = {}, v = {}, d = {}, pa = {}, pb = {} }
            local Sr = self.copy(SA)
            -- stage A in the record
            local SA2 = self.copy(S0)
            for i = 1, #cA do step(SA2, cA[i]); rec.cmds[i] = cA[i]; rec.lat[i] = SA2.lat; rec.hb[i] = SA2.hb; rec.v[i] = SA2.v; rec.d[i] = SA2.dist; rec.pa[i] = SA2.pa and 1 or 0; rec.pb[i] = SA2.pb and 1 or 0 end
            local err, lean, peak = run(Sr, W, w, rec)
            rec.n = #rec.cmds
            if os.getenv("SHO_APPRDBG") then print(string.format("APPRDBG pre=%d w=%d err=%.0f lean=%.0f peak=%.0f n=%d startlat=%.0f d=%.1f sd=%.1f", pre, w, err, lean, peak, rec.n, S0.lat, S0.dist, sd)) end
            local cand = { rec = rec, T = T0, sd = sd, i = 1, lat0 = S0.lat, appr = true, ins = ins, pre = pre, lean_in = lean, err = err, peak = peak, tarr = rec.n, a = 0, cap = 127 }
            if abs(err) <= 10 and peak <= 285 and rec.n < 400 then
              if not best or lean > best.lean_in + 5 then best = cand end
              if lean >= LT then break end
            end
          end
        end
      end
    end
    if not best then return nil end
    if best.lean_in < 0.6 * (want or 127) then return nil end
    return best
  end
  self.cur = nil
  self.hold = function(S, T0) if cfg.pred then return self.policy_pred(S, T0) else return self.policy(S, T0) end end
  function self.next_cmd(S, T0, sd)
    local pl = self.cur
    if pl and pl.T == T0 and pl.sd == sd then
      local i = pl.i
      if i <= pl.rec.n then
        local exp = (i == 1) and pl.lat0 or pl.rec.lat[i - 1]
        if abs(S.lat - exp) <= (cfg.dev or 8) then pl.i = i + 1; return pl.rec.cmds[i], pl end
      end
    end
    if not sd and (cfg.sat_hold or 0) > 0 and abs(S.lat - T0) <= 90 then   -- inside a curve with the steering already saturated toward the target: keep the lock (a replan would release it to arrive after the curve)
      local dir = (T0 >= S.lat) and 1 or -1
      if -S.so * dir >= cfg.sat_hold then self.cur = nil; return self.hold(S, T0), nil end
    end
    if abs(S.lat - T0) <= (cfg.planmin or 30) then self.cur = nil; return self.hold(S, T0), nil end   -- small errors: the continuous hold law
    if pl and pl.appr and pl.T == T0 and pl.sd == sd then
      local np = self.approach(S, T0, sd, pl.ins)                 -- deviated from the prediction: plan the approach again from here
      if np then np.i = 2; self.cur = np; return np.rec.cmds[1], np end
    end
    pl = self.best_plan(S, T0, sd); pl.lat0 = S.lat; self.cur = pl
    if pl.rec.n == 0 then return self.policy(S, T0), pl end
    pl.i = 2
    return pl.rec.cmds[1], pl
  end
  return self
end
return M
