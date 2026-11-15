#!/usr/bin/env python3
"""Offline version of sim_chain (autolap3.lua): max entry speed for a chain of contiguous curves. Usage: chainsim.py TIRE LEAD OUT INE"""
import math, sys
T, LEAD, OUT, INE = int(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
ADJ = [32, 20, 8, -4, -16]; G = 8.0*160/(128+ADJ[T]); DPF = 0.001335; MULT = 3; VMAX = 241
# track 3: (start, end, state, r)
S = [(116,385,2,115),(385,670,3,115),(670,743,3,44),(743,851,3,92),(979,1082,2,44),(1232,1335,2,46),(1411,1478,2,46),(1478,1549,3,47),(1549,1659,2,46),(1659,1810,3,115),(1810,1933,3,46)]
def push(v, r):
    Dc = math.floor(410/r+0.5); return 2/3*(math.floor(Dc*v/110)+1)
def Gof(v): return G if v > 127 else G*max(v,20)/128
def sim(chain, v0, verbose=False):
    segs = [S[i] for i in chain]; j = 0; v = v0; x = segs[0][0]
    ps = 1 if segs[0][2] == 2 else -1; lat = -ps*INE; h = ps*69.4
    for fr in range(9000):
        while x >= segs[j][1]:
            j += 1
            if j >= len(segs): return True, v
        sg = segs[j]; ps = 1 if sg[2] == 2 else -1; cdir = ps
        if j+1 < len(segs) and segs[j+1][2] != sg[2] and (sg[1]-x) < DPF*v*LEAD: cdir = -ps
        pm = push(v, sg[3]); Gv = Gof(v)
        hc = max(-69.4, min(69.4, ps*pm*127/Gv/1.83)) if cdir*lat < -(INE-15) else cdir*69.4
        dh = hc-h; rate = 2.0 if h*dh < 0 else 1.0
        h = hc if abs(dh) <= rate else h + (rate if dh > 0 else -rate)
        so = 0 if abs(h) <= 20 else max(-127, min(127, 1.83*h))
        lat += ps*pm - Gv*so/127
        u = ps*lat
        if u > OUT or u < -(INE+25):
            if verbose: print(f"  fail seg {j} x={x:.0f} u={u:.0f} v={v:.0f} fr={fr}")
            return False, v
        if fr % 3 == 0: v = min(VMAX, v + MULT*(279-v)/1024)
        x += DPF*v
    return True, v
chains = {"T3-T4": [2,3], "T5": [4], "T6": [5], "T7-T9": [6,7,8], "T7-T11": [6,7,8,9,10], "T9": [8], "T10-T11": [9,10], "T1-T4": [0,1,2,3]}
for name, ch in chains.items():
    best = None
    for v0 in range(241, 59, -1):
        ok, ve = sim(ch, v0)
        if ok: best = (v0, ve); break
    print(name, "entry", best[0] if best else None, "exit", round(best[1]) if best else None)
    if not best: sim(ch, 100, True)
