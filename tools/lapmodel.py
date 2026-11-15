"""Speed-profile lap model for rival 0's track (Original mode), built from the measured physics (see docs/09).
Curve speed limit per tire tier: the outward push of a curve (about (2/3)*(floor(Dc*v/110)+1)*0.92 per frame, Dc = round(410/r)) must be
countered by the tire's counter-steer authority G = 8*160/(128+adj[tire]); any excess may drift the bike over the curve from the entry
offset (ENT) to the outer limit (TOUT) before it skids (|lat| > 300). Braking: 0.95 speed/frame; accel: s += mult*(279-s)/1024 every 3rd frame,
mult = {3,4,6,6,8,8}[engine] + (oil+muffler)/4, cap 241 for engines 0-2.
Usage: python3 -I tools/lapmodel.py"""
import math, sys
SEGS = [(0,104,1,0),(104,199,3,102),(199,251,1,0),(251,281,3,38),(281,378,1,0),(378,480,2,66),(480,532,1,0),(532,600,3,73),(600,639,2,62),
        (639,701,2,45),(701,861,1,0),(861,961,2,106),(961,1020,3,92),(1020,1074,2,54),(1074,1128,1,0),(1128,1250,3,125),(1250,1320,2,61),
        (1320,1374,2,108),(1374,1581,1,0),(1581,1625,3,45),(1625,1720,3,105),(1720,1836,1,0),(1836,2000,3,82),(2000,2048,1,0)]
ADJ = [32, 20, 8, -4, -16]
DPF = 269 / 65536 / 3          # distance units per frame per unit of speed (calls every 3rd frame)
BRAKE = 0.95
def G(t): return 8.0 * 160 / (128 + ADJ[t])
def push(v, r):
    Dc = round(410 / r)
    return (2 / 3) * (math.floor(Dc * v / 110) + 1) * 0.92
def vlim(t, r, length, ent, tout, cap):
    for v in range(int(cap), 59, -1):
        ex = push(v, r) - G(t)
        if ex <= 0 or ex * length / (DPF * v) <= ent + tout: return v
    return 60
def lap(tire, oil, engine=0, ent=60, tout=230, safe=0.95, laps=2, muf=0):
    cap = 241 if engine < 3 else 279
    mult = [3,4,6,6,8,8][engine] + (oil + muf) / 4
    lim = []
    for (a, b, st, r) in SEGS:
        lim.append(cap if st == 1 else min(cap, safe * vlim(tire, r, b - a, ent, tout, cap)))
    # backward pass over a fine grid: allowed speed at each position given braking
    N = 2048 * laps
    allow = [cap] * (N + 1)
    for x in range(N + 1):
        d = x % 2048
        for i, (a, b, st, r) in enumerate(SEGS):
            if a <= d < b: allow[x] = lim[i]; break
    # braking: v(x) <= sqrt(v(x+dx)^2 + 2*BRAKE*dx/DPF) approx per unit step: dv*v*DPF... use frame stepping
    # simple: iterate backwards per 1 unit: v_allowed[x] = min(v[x], v_allowed[x+1] + BRAKE * (1/(DPF*vavg)))
    for x in range(N - 1, -1, -1):
        v1 = allow[x + 1]
        frames = 1.0 / (DPF * max(v1, 1))
        allow[x] = min(allow[x], v1 + BRAKE * frames)
    # forward pass: accelerate with engine model (calls every 3rd frame)
    s, x, t, frames_total = 0.0, 0.0, 0, 0
    while x < N:
        i = min(int(x), N)
        target = allow[i]
        if s < target:
            for _ in range(3): pass
            s = min(s + mult * (279 - s) / 1024, target)   # one call = 3 frames
        else:
            s = target
        x += DPF * s * 3
        frames_total += 3
    return frames_total / 60.0
if __name__ == "__main__":
    print("Rival 0 track, 2 laps, engine 0 (seconds, race only; ent=60 tout=230 safe=0.95)")
    print("tire  G     oil0     oil1    oil1 gain")
    base = None
    for t in range(5):
        a, b = lap(t, 0), lap(t, 1)
        base = base or a
        print(f"{t}   {G(t):5.2f}  {a:7.2f}  {b:7.2f}  {a-b:5.2f}   vs tire0/oil0: {a-base:+.2f} / {b-base:+.2f}")
    print("\nSensitivity of tire 0 -> 1 / 2 / 4 gain to the drift budget and safety margin:")
    for ent, tout, safe in [(0,200,0.95),(60,230,0.95),(120,260,0.97),(60,230,1.0)]:
        r = [lap(t, 0, ent=ent, tout=tout, safe=safe) for t in (0, 1, 2, 4)]
        print(f"ent={ent:3d} tout={tout} safe={safe}: tire0 {r[0]:.1f}s  tire1 {r[1]-r[0]:+.2f}  tire2 {r[2]-r[0]:+.2f}  tire4 {r[3]-r[0]:+.2f}")
