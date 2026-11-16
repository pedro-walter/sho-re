-- Super Hang-On (Genesis) bot-slot visualiser for BizHawk (Genesis Plus GX or PicoDrive core).
-- Tools > Lua Console > Open Script. Works in Original mode (the tables shown are Original mode's).
--
-- What it shows (all from docs/02-original-mode.md section 7):
--   * the 5 bot slots at $FFCC40 + n*$40, each owning one lane (-180,-90,0,+90,+180), with its
--     "overtaken at depth $1FC" progress bar
--   * the spawn machinery: countdown $FFC812, request flag $FFC810, slow-speed delay $FFC80E,
--     lap bot limit (2,3,3,3,3,4,4,4,5), speed/slide gate
--   * the PREDICTED next slot (lowest free index) and, when a spawn really happens, whether it
--     went to that slot (OK / MISMATCH)
--   * an event log: SPAWN, PASSED (overtake counter moved, slot freed), GONE (fell behind)


-- ---- text backend ------------------------------------------------------------------------------
-- BizHawk's font text (pixelText/drawString/text) shows blank boxes on some Linux setups, so the
-- default "bitmap" mode draws its own 3x5 pixel font with gui.drawLine (no font files needed).
-- TEXT_MODE can still be "pixel", "string" or "text" if you prefer the native ones.
local TEXT_MODE = "bitmap"
local PIXEL_FONT = "gens"
local FONT = {
  ["0"]={7,5,5,5,7}, ["1"]={2,6,2,2,7}, ["2"]={7,1,7,4,7}, ["3"]={7,1,7,1,7}, ["4"]={5,5,7,1,1},
  ["5"]={7,4,7,1,7}, ["6"]={7,4,7,5,7}, ["7"]={7,1,1,1,1}, ["8"]={7,5,7,5,7}, ["9"]={7,5,7,1,7},
  A={2,5,7,5,5}, B={6,5,6,5,6}, C={3,4,4,4,3}, D={6,5,5,5,6}, E={7,4,6,4,7}, F={7,4,6,4,4},
  G={7,4,5,5,7}, H={5,5,7,5,5}, I={7,2,2,2,7}, J={1,1,1,5,2}, K={5,5,6,5,5}, L={4,4,4,4,7},
  M={5,7,7,5,5}, N={7,5,5,5,5}, O={2,5,5,5,2}, P={7,5,7,4,4}, Q={7,5,5,7,1}, R={6,5,6,5,5},
  S={3,4,2,1,6}, T={7,2,2,2,2}, U={5,5,5,5,7}, V={5,5,5,5,2}, W={5,5,7,7,5}, X={5,5,2,5,5},
  Y={5,5,2,2,2}, Z={7,1,2,4,7},
  ["-"]={0,0,7,0,0}, ["+"]={0,2,7,2,0}, ["/"]={1,1,2,4,4}, ["%"]={5,1,2,4,5}, [":"]={0,2,0,2,0},
  ["."]={0,0,0,0,2}, [","]={0,0,0,2,4}, ["("]={1,2,2,2,1}, [")"]={4,2,2,2,4}, [">"]={4,2,1,2,4},
  ["<"]={1,2,4,2,1}, ["="]={0,7,0,7,0}, ["|"]={2,2,2,2,2}, ["$"]={2,3,6,3,2}, ["!"]={2,2,2,0,2},
  ["_"]={0,0,0,0,7}, ["*"]={0,5,2,5,0}, ["?"]={7,1,2,0,2}, [" "]={0,0,0,0,0},
}
local function bitmapText(x, y, msg, fg, bg)
  msg = msg:upper()
  if bg then gui.drawBox(x - 1, y - 1, x + #msg * 4, y + 5, 0x00000000, bg) end
  for i = 1, #msg do
    local g = FONT[msg:sub(i, i)] or FONT["?"]
    local cx = x + (i - 1) * 4
    for r = 1, 5 do
      local row = g[r]
      local c = 0
      while c < 3 do
        if (row >> (2 - c)) & 1 == 1 then          -- start of a run of set pixels
          local e = c
          while e < 2 and (row >> (2 - (e + 1))) & 1 == 1 do e = e + 1 end
          gui.drawLine(cx + c, y + r - 1, cx + e, y + r - 1, fg or "white")
          c = e + 1
        else c = c + 1 end
      end
    end
  end
end
local function T(x, y, msg, fg, bg, mode)
  mode = mode or TEXT_MODE
  if mode == "bitmap" then
    bitmapText(x, y, msg, fg, bg)
  elseif mode == "pixel" then
    gui.pixelText(x, y, msg, fg or "white", bg or 0x00000000, PIXEL_FONT)
  elseif mode == "string" then
    if bg then gui.drawBox(x - 1, y, x + #msg * 6, y + 10, 0x00000000, bg) end
    gui.drawString(x, y, msg, fg or "white", 0x00000000, 9)
  else
    local sx = client.screenwidth() / client.bufferwidth()
    local sy = client.screenheight() / client.bufferheight()
    gui.text(math.floor(x * sx), math.floor(y * sy), msg, fg or "white")
  end
end

local LIM    = {2, 3, 3, 3, 3, 4, 4, 4, 5}      -- table $4930 row 0 (Original mode), laps 1..9
local LANES  = {-180, -90, 0, 90, 180}
local BASE   = 0xFFCC40
local STRIDE = 0x40
local PASS_DEPTH = 0x1FC

-- ---- memory access (pick whichever domain this core exposes) -----------------------------------
local dom, mask
do
  local have = {}
  for _, d in ipairs(memory.getmemorydomainlist()) do have[d] = true end
  if have["M68K BUS"] then dom, mask = "M68K BUS", 0xFFFFFF
  else dom, mask = "68K RAM", 0xFFFF end
end
local function u16(a) return memory.read_u16_be(a & mask, dom) end
local function s16(a) return memory.read_s16_be(a & mask, dom) end
local function u8(a)  return memory.read_u8(a & mask, dom) end

local function snapshot()
  local s = {}
  s.mode     = u16(0xFFC704)
  s.orig     = u16(0xFFC82C)
  s.lap      = u16(0xFF060A)
  s.speed    = u16(0xFF064A)
  s.slip     = s16(0xFF0614)
  s.pass     = u16(0xFF064E)      -- overtake counter
  s.cnt      = u16(0xFF0690)      -- bots counted last frame (what the limit check uses)
  s.cd       = s16(0xFFC812)      -- spawn countdown (reloads 100/160/220/280)
  s.req      = u16(0xFFC810)      -- spawn request pending
  s.dly      = s16(0xFFC80E)      -- slow-speed extra delay (4..32)
  s.rs       = u16(0xFF067E)      -- road state at the rider: 1 straight, 2/3 curve
  s.rn       = u16(0xFF0676)      -- announced next road state (0 = none)
  s.slot = {}
  for n = 0, 4 do
    local a = BASE + n * STRIDE
    s.slot[n] = {
      occ   = (u16(a) & 1) == 1,
      type  = u16(a),
      depth = s16(a + 0x26) >> 4,   -- asr #4: compared with $1FC
      vel   = s16(a + 0x0A),
      lane  = s16(a + 0x2A),        -- the lane this bot is steered back to
      lat   = s16(a + 0x08),        -- where it actually is sideways (drifts in curves)
      x     = s16(a + 0x10) - 0x120, -- screen x offset from the centre
      z     = u16(a + 0x0C),        -- 0 = horizon .. $BF = alongside you
      f3a   = u8(a + 0x3A),         -- block flags (bit0: no move right, bit1: no move left, bit2: speed up)
      f3d   = u8(a + 0x3D),         -- hit veer flag
    }
  end
  return s
end

local log = {}
local function note(frame, msg)
  table.insert(log, string.format("f%d %s", frame, msg))
  if #log > 9 then table.remove(log, 1) end
  console.log(string.format("f%d %s", frame, msg))
end

local function lowestFree(s)
  for n = 0, 4 do if not s.slot[n].occ then return n end end
  return nil
end

-- Why the bot moved (or did not) on the last game tick.  Port of predict() in tools/botanalyze.py,
-- which matched 86,413 of 86,413 real bot updates.  pb = the bot's state BEFORE the tick, st/nx = road state/next.
local function reason(pb, st, nx)
  if pb.f3d ~= 0 then return "VEERING", "red" end
  if pb.z >= 0xAF then return "NEAR YOU", "gray" end
  local b0, b1 = (pb.f3a & 1) ~= 0, (pb.f3a & 2) ~= 0
  if pb.z > 0x70 and math.abs(pb.x) < 0x38 then
    if pb.x < 0 then b0 = true else b1 = true end
  end
  local function curve(d0, name)
    local blocked = (d0 > 0 and b0) or (d0 < 0 and b1)
    if blocked then return "BLOCKED", "salmon" end
    if math.abs(pb.lat + d0) >= 0xFA then return "AT LIMIT", "gray" end
    return name .. (d0 > 0 and " >" or " <"), (name == "SWING") and "cyan" or "orange"
  end
  local swing = (nx ~= st and nx ~= 0)
  if swing then
    if nx == 2 then return curve(-4, "SWING")
    elseif nx == 3 then return curve(4, "SWING")
    elseif st == 2 then return curve(-4, "SWING")
    elseif st == 3 then return curve(4, "SWING") end
  end
  if st == 1 then
    if pb.lane == pb.lat then return "ON LANE", "lightgreen" end
    local d = (pb.lane > pb.lat) and 6 or -6
    if (d > 0 and b0) or (d < 0 and b1) then return "BLOCKED", "salmon" end
    return "RETURN" .. (d > 0 and " >" or " <"), "lightgreen"
  end
  return curve(st == 2 and 4 or -4, "DRIFT")
end

local reasons = {}     -- slot -> {text, colour}, refreshed on every game tick
local prev
local predicted        -- lowest free slot as of the previous frame
local W = 8

while true do
  local s = snapshot()
  local inRace = (s.mode & 0x7FFC) == 0x18
  gui.clearGraphics()

  if inRace and prev then
    -- a game tick = a frame where some bot's depth counter moved (bots update every ~3rd frame)
    local tick = false
    for n = 0, 4 do
      if prev.slot[n].occ and s.slot[n].occ and prev.slot[n].depth ~= s.slot[n].depth then tick = true end
    end
    if tick then
      for n = 0, 4 do
        if prev.slot[n].occ and s.slot[n].occ then
          local t, c = reason(prev.slot[n], s.rs, s.rn)
          reasons[n] = {t, c}
        end
      end
    end
    for n = 0, 4 do if not s.slot[n].occ then reasons[n] = nil end end
    -- ---- events -------------------------------------------------------------------------------
    for n = 0, 4 do
      local a, b = prev.slot[n], s.slot[n]
      if a.occ and not b.occ then
        if s.pass > prev.pass then
          note(emu.framecount(), string.format("PASSED  slot %d (lane %+d) freed", n, LANES[n + 1]))
        else
          note(emu.framecount(), string.format("GONE    slot %d (lane %+d) fell behind", n, LANES[n + 1]))
        end
      elseif (not a.occ) and b.occ then
        local ok = (predicted == n) and "OK = lowest free" or ("MISMATCH, predicted " .. tostring(predicted))
        note(emu.framecount(), string.format("SPAWN   slot %d lane %+d lat %+d (prev %+d) %s", n, LANES[n + 1], b.lat, a.lat, ok))
      end
    end
  end

  if inRace then
    local lap = math.min(s.lap + 1, 9)
    local limit = LIM[lap]
    local free = lowestFree(s)
    predicted = free

    local x, y = 4, 4
    local function line(txt, col) T(x, y, txt, col or "white", 0xB0000000); y = y + W end

    line(string.format("lap %d  speed %d  your lat %d  passed %d%s", lap, s.speed, s.slip, s.pass,
         s.orig ~= 0 and "" or "  (ARCADE: tables differ)"), s.orig ~= 0 and "white" or "orange")
    line(string.format("bots %d / limit %d  -> %s", s.cnt, limit,
         s.cnt < limit and "spawn allowed" or "FULL, no spawn"), s.cnt < limit and "lightgreen" or "salmon")

    -- slot boxes, in the sky right under the status block (leftmost box = slot 0)
    local bw = 56
    local bx0 = (client.bufferwidth() - 5 * bw) // 2
    local by = 24
    for n = 0, 4 do
      local sl = s.slot[n]
      local bx = bx0 + n * bw
      gui.drawRectangle(bx, by, bw - 4, 42, n == free and "cyan" or "white", sl.occ and 0x80208020 or 0x80303030)
      T(bx + 3, by + 2,  "slot " .. n, "white")
      T(bx + 3, by + 10, string.format("lane %+d", LANES[n + 1]), "gray")
      if sl.occ then
        T(bx + 3, by + 18, string.format("lat %+d", sl.lat), math.abs(sl.lat - LANES[n + 1]) > 8 and "orange" or "lightgreen")
        local rz = reasons[n]
        T(bx + 3, by + 26, rz and rz[1] or "...", rz and rz[2] or "gray")
        local frac = math.max(0, math.min(1, sl.depth / PASS_DEPTH))
        gui.drawRectangle(bx + 3, by + 35, bw - 10, 4, "gray", "black")
        gui.drawRectangle(bx + 3, by + 35, math.floor((bw - 10) * frac), 4, "lightgreen", "lightgreen")
      else
        T(bx + 3, by + 18, n == free and "NEXT" or "free", n == free and "cyan" or "gray")
      end
    end

    -- one road-position track: a little box per slot (number on top) at where that bot is NOW
    -- across the road (-250 .. +250).  Green = on its own lane (its spot when close to you),
    -- yellow = off it, with a gray line to the lane it is heading back to.
    -- Free slots are drawn hollow at the sideways value the next bot will start from.
    local sx0, sw = bx0 + 6, 5 * bw - 18
    local function px(lat) return sx0 + math.floor((math.max(-250, math.min(250, lat)) + 250) / 500 * sw) end
    local ty = by + 66
    gui.drawLine(sx0 - 4, ty + 5, sx0 + sw + 4, ty + 5, 0x60FFFFFF)
    for n = 0, 4 do
      local sl = s.slot[n]
      local target = LANES[n + 1]
      local off = math.abs(sl.lat - target) > 8
      local cx = px(sl.lat)
      if off then
        local tx = px(target)
        gui.drawLine(cx, ty + 5, tx, ty + 5, "gray")
        gui.drawLine(tx, ty + 2, tx, ty + 8, "gray")
      end
      T(cx - 1, ty - 8, tostring(n), n == free and "cyan" or "white")
      if sl.occ then
        local col = off and "yellow" or "lightgreen"
        gui.drawRectangle(cx - 3, ty + 2, 6, 6, col, col)
      else
        gui.drawRectangle(cx - 3, ty + 2, 6, 6, "gray", 0x00000000)
      end
    end

    -- event log
    local ly = client.bufferheight() - 34
    for i = math.max(1, #log - 3), #log do
      T(4, ly, log[i], "white", 0xB0000000); ly = ly + 8
    end
  else
    T(4, client.bufferheight() - 10, "waiting for the race to start", "white", 0xB0000000)
  end

  prev = s
  emu.frameadvance()
end
