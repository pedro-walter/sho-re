#!/usr/bin/env python3
"""Backward chain planner (track 3). For a chain of contiguous curves A-B-C it plans C first (full lock at its start, highest feasible entry speed),
then B so that it ENDS in the state C needs (lateral offset, handlebar, speed), then A so that it ends in the state B needs.
Per curve the plan gives: entry speed, entry lateral fraction a (1 = on the inside edge with full lock, 0 = centre), lock-switch lead (frames before the curve end).
Usage: chainplan2.py TIRE OFFLIM [OUT.lua]"""
import math, sys, itertools
T, OFFLIM = int(sys.argv[1]), float(sys.argv[2])
OUTF = sys.argv[3] if len(sys.argv) > 3 else None
INE = 240.0
ADJ = [32, 20, 8, -4, -16]; G = 8.0*160/(128+ADJ[T]); DPF = 0.001335; MULT = 3; VMAX = 241; BRAKE = 0.95
S = [(116,385,2,115),(385,670,3,115),(670,743,3,44),(743,851,3,92),(979,1082,2,44),(1232,1335,2,46),(1411,1478,2,46),(1478,1549,3,47),(1549,1659,2,46),(1659,1810,3,115),(1810,1933,3,46)]
CHAINS = [[0,1,2], [4], [5], [6,7,8], [9,10]]   # T4 (gentle) is sacrificed: it follows T3 without a plan
def push(v, r):
    Dc = math.floor(410/r+0.5); return 2/3*(math.floor(Dc*v/110)+1)
def Gof(v): return G if v > 127 else G*max(v, 20)/128
def sim_curve(k, lat, h, v, lead, nxt, vt_next):
    """one curve k (index into S); nxt = next curve index in the chain or None; returns (ok, lat, h, v, frames)"""
    st, en, state, r = S[k][0], S[k][1], S[k][2], S[k][3]
    ps = 1 if state == 2 else -1
    opp = nxt is not None and S[nxt][2] != state
    anynext = nxt is not None
    x = st; fr = 0
    while x < en:
        cdir = ps
        inwin = anynext and (en-x) < DPF*max(v, 60)*lead
        if opp and inwin: cdir = -ps
        pm = push(v, r); Gv = Gof(v)
        hc = max(-69.4, min(69.4, ps*pm*127/Gv/1.83)) if (cdir*lat < -(INE-15) and not inwin) else cdir*69.4
        dh = hc-h; rate = 2.0 if h*dh < 0 else 1.0
        h = hc if abs(dh) <= rate else h + (rate if dh > 0 else -rate)
        so = 0 if abs(h) <= 20 else max(-127, min(127, 1.83*h))
        lat += ps*pm - Gv*so/127
        if abs(lat) > OFFLIM: return False, lat, h, v, fr
        brake = False
        if vt_next is not None and v > vt_next:
            env = math.sqrt(vt_next**2 + max(0, 2*BRAKE*(en-x-2)/(1.25*DPF)))
            brake = v > env
        if brake: v = max(40, v - BRAKE)
        elif fr % 3 == 0: v = min(VMAX, v + MULT*(279-v)/1024)
        x += DPF*v; fr += 1
        if fr > 20000: return False, lat, h, v, fr
    return True, lat, h, v, fr
def plan_chain(chain):
    n = len(chain)
    vgrid = list(range(241, 59, -4)); agrid = [1.0, 0.75, 0.5, 0.25, 0.0]; leads = [0, 20, 40, 70, 100, 140]
    def req(k, a):   # start state a curve k needs
        ps = 1 if S[k][2] == 2 else -1
        return -ps*INE*a, ps*69.4*a
    res = [None]*n
    def rec(idx, need):   # plan curve idx; need = (lat, h, v) its end must reach (None for the last curve)
        k = chain[idx]
        nxt = chain[idx+1] if idx+1 < n else None
        cands = []
        for vt in vgrid:
            for a in (agrid if idx > 0 or True else [1.0]):
                if idx == n-1 and a != 1.0: continue          # the last curve: full lock at the start, on the inside edge
                lat0, h0 = req(k, a)
                for lead in (leads if nxt is not None else [0]):
                    vtn = need[2] if need else None
                    ok, lat, h, v, fr = sim_curve(k, lat0, h0, vt, lead, nxt, vtn)
                    if not ok: continue
                    if need:
                        if abs(lat-need[0]) > 45 or abs(h-need[1]) > 30 or v > need[2]+6: continue
                    cands.append((vt, a, lead, v, fr))
            # keep scanning speeds high to low; stop collecting after a decent number
        cands.sort(key=lambda c: (-c[0], -c[1], c[4]))
        for c in cands[:40]:
            res[idx] = c
            if idx == 0: return True
            ps_ = 1 if S[chain[idx]][2] == 2 else -1
            lat0, h0 = req(chain[idx], c[1])
            if rec(idx-1, (lat0, h0, c[0])): return True
        return False
    ok = rec(n-1, None) if False else None
    # plan backwards: last curve first
    def back(idx, need):
        k = chain[idx]; nxt = chain[idx+1] if idx+1 < n else None
        cands = []
        for vt in vgrid:
            for a in agrid:
                if idx == n-1 and a != 1.0 and push(241, S[k][3]) > G*1.05: continue    # a sharp last curve starts on the inside edge at full lock
                lat0, h0 = req(k, a)
                for lead in (leads if nxt is not None else [0]):
                    ok, lat, h, v, fr = sim_curve(k, lat0, h0, vt, lead, nxt, need[2] if need else None)
                    if not ok: continue
                    if need and (abs(lat-need[0]) > 45 or abs(h-need[1]) > 30 or v > need[2]+6): continue
                    cands.append((vt, a, lead, v, fr))
        cands.sort(key=lambda c: (-c[0], (c[1] if idx == n-1 else -c[1]), c[4]))
        for c in cands[:60]:
            res[idx] = c
            if idx == 0: return True
            lat0, h0 = req(k, c[1])
            if back(idx-1, (lat0, h0, c[0])): return True
        return False
    return res if back(n-1, None) else None
out = {}
for ch in CHAINS:
    p = plan_chain(ch)
    names = ["T%d" % (k+1) for k in ch]
    if not p: print(names, "infeasible"); continue
    for k, c in zip(ch, p):
        out[S[k][0]] = c
        print("T%-2d entry %3d raw (%3d km/h) a=%.2f lead=%3d  -> exit %3d raw (%3d km/h) frames=%d" % (k+1, c[0], c[0]*1.1625, c[1], c[2], c[3], c[3]*1.1625, c[4]))
if OUTF:
    with open(OUTF, "w") as f:
        f.write("-- generated by tools/chainplan2.py: [curve start] = {entry speed, entry lateral fraction, lock-switch lead (frames)}\nreturn {\n")
        for st, c in sorted(out.items()): f.write("  [%d] = { vt = %d, a = %.2f, lead = %d, vexit = %d },\n" % (st, c[0], c[1], c[2], c[3]))
        f.write("}\n")
