#!/usr/bin/env python3
"""Offline chain planner (track 3, tire/engine given): searches entry speed, entry lateral offset and the lock-switch leads of a chain of contiguous curves
to maximise the exit speed of the last curve without leaving the road. Usage: chainplan.py TIRE OFFLIM [chain ...]  (chain names below)"""
import math, sys, itertools, json
T, OFFLIM = int(sys.argv[1]), float(sys.argv[2])
INE = 240.0
ADJ = [32, 20, 8, -4, -16]; G = 8.0*160/(128+ADJ[T]); DPF = 0.001335; MULT = 3; VMAX = 241; BRAKE = 0.95
S = [(116,385,2,115),(385,670,3,115),(670,743,3,44),(743,851,3,92),(979,1082,2,44),(1232,1335,2,46),(1411,1478,2,46),(1478,1549,3,47),(1549,1659,2,46),(1659,1810,3,115),(1810,1933,3,46)]
CH = {"T1-T3": [0,1,2], "T1-T4": [0,1,2,3], "T7-T9": [6,7,8], "T10-T11": [9,10], "T7-T11": [6,7,8,9,10]}
def push(v, r):
    Dc = math.floor(410/r+0.5); return 2/3*(math.floor(Dc*v/110)+1)
def Gof(v): return G if v > 127 else G*max(v, 20)/128
def sim(chain, v0, a, leads, brakes=None):
    segs = [S[i] for i in chain]; j = 0; v = v0; x = segs[0][0]
    ps = 1 if segs[0][2] == 2 else -1; lat = -ps*INE*a; h = ps*69.4*a; maxo = 0
    for fr in range(12000):
        while x >= segs[j][1]:
            j += 1
            if j >= len(segs): return True, v, fr
        sg = segs[j]; ps = 1 if sg[2] == 2 else -1; cdir = ps
        nxt_opp = j+1 < len(segs) and segs[j+1][2] != sg[2]
        if nxt_opp and (sg[1]-x) < DPF*max(v,60)*leads[j]: cdir = -ps
        pm = push(v, sg[3]); Gv = Gof(v)
        hc = max(-69.4, min(69.4, ps*pm*127/Gv/1.83)) if cdir*lat < -(INE-15) else cdir*69.4
        dh = hc-h; rate = 2.0 if h*dh < 0 else 1.0
        h = hc if abs(dh) <= rate else h + (rate if dh > 0 else -rate)
        so = 0 if abs(h) <= 20 else max(-127, min(127, 1.83*h))
        lat += ps*pm - Gv*so/127
        if abs(lat) > OFFLIM: return False, v, fr
        if fr % 3 == 0: v = min(VMAX, v + MULT*(279-v)/1024)
        x += DPF*v
    return True, v, 12000
def plan(name, ch):
    n = len(ch)
    best = None
    lead_opts = [0, 30, 60, 90, 120, 160, 220, 300]
    for v0 in range(241, 59, -6):
        for a in (1.0, 0.7, 0.4, 0.0):
            for leads in itertools.product(lead_opts, repeat=n-1):
                L = list(leads) + [0]
                ok, ve, fr = sim(ch, v0, a, L)
                if ok and (best is None or ve > best[0] + 0.5 or (abs(ve-best[0]) <= 0.5 and fr < best[4])):
                    best = (ve, v0, a, L, fr)
    return best
if __name__ == "__main__":
    names = sys.argv[3:] or list(CH)
    for nm in names:
        b = plan(nm, CH[nm])
        print(nm, "exit %.0f raw (%.0f km/h) entry %d a=%.1f leads=%s frames=%d" % (b[0], b[0]*1.1625, b[1], b[2], b[3], b[4]) if b else "infeasible")
