#!/usr/bin/env python3
"""Buy plan for track 1 when the stock bike already wins (every race pays $1,200). Minimises the total time of N won races + S seconds per shop visit (visit = buying something).
Usage: tools/buyplan.py CSV [N=5] [S=0] ; CSV = docs/data/partsweep6_track1_2lap.csv. Part wear is ignored; start $0, all tier 0."""
import csv, itertools, sys, functools
K = ('tire', 'frame', 'engine', 'brake', 'muffler', 'oil')
T = {tuple(int(x[k]) for k in K): float(x['total_s']) for x in csv.DictReader(open(sys.argv[1]))}
N = int(sys.argv[2]) if len(sys.argv) > 2 else 5; S = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
PRICE = {0: [0, 400, 1500], 1: [0, 2000], 2: [0, 2000], 3: [0, 1500], 4: [0, 1500], 5: [0, 200]}   # slot index in K -> price of tier t (tire: tier 2 bought directly costs 1,500)
WIN = 1200
def options(st, money):
    """all ways to upgrade (non-empty) within money: list of (cost, newstate)"""
    res = []
    choices = []
    for s in range(6):
        c = [(st[s], 0)]
        for t in range(st[s] + 1, len(PRICE[s])): c.append((t, PRICE[s][t]))
        choices.append(c)
    for combo in itertools.product(*choices):
        cost = sum(c[1] for c in combo)
        if 0 < cost <= money: res.append((cost, tuple(c[0] for c in combo)))
    return res
@functools.lru_cache(None)
def best(race, money, st):
    """race = races already won; returns (min total time of the remaining races incl. visits, plan list)"""
    if race == N: return 0.0, ()
    t = T[st]; m2 = money + WIN
    cont = best(race + 1, m2, st) if True else None
    out = (t + cont[0], ((race + 1, 'race', st),) + cont[1])
    if race + 1 < N:
        for cost, ns in options(st, m2):
            c2 = best(race + 1, m2 - cost, ns)
            tot = t + S + c2[0]
            if tot < out[0] - 1e-9: out = (tot, ((race + 1, 'race', st), (race + 1, 'buy', ns, cost)) + c2[1])
    return out
tot, plan = best(0, 0, (0,) * 6)
names = ['tire', 'frame', 'engine', 'brake', 'muffler', 'oil']
print(f'N={N} S={S}: total {tot:.2f} s  (stock only: {N * T[(0,)*6]:.2f} s)')
for p in plan:
    if p[1] == 'race': print(f'  race {p[0]}: {T[p[2]]:.2f} s  parts {dict(zip(names, p[2]))}')
    else: print(f'    shop after race {p[0]}: buy up to {dict(zip(names, p[2]))} for ${p[3]}')
