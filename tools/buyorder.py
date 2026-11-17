#!/usr/bin/env python3
"""Buy-order search for track 1 (rival 0, MIA FERRARU, sponsor PHARMACY) from the two-lap part sweep.
Usage: tools/buyorder.py docs/data/partsweep6_track1_2lap.csv [RIVAL_S=221.0]
Model: start with $0 and all tier 0 parts; each race is the 2-lap total of the current part combination (sweep table); you win if it is below the rival's time (default 221.0 s =
2 x (110 + ~0.5)), win pays $1,200, a loss within 10 s $800, otherwise $400; after each race the next affordable items of the order are bought (in order, an item is bought as soon as
its price is covered). Wear/repairs and mechanic costs are ignored. Goal: fewest races to 5 wins (5 wins advance to the next rival), ties: most money left."""
import csv, itertools, sys
K = ('tire', 'frame', 'engine', 'brake', 'muffler', 'oil')
T = {tuple(int(x[k]) for k in K): float(x['total_s']) for x in csv.DictReader(open(sys.argv[1]))}
RIV = float(sys.argv[2]) if len(sys.argv) > 2 else 221.0
# items: name -> (slot index, tier, price)
ITEMS = {'oil1': (5, 1, 200), 'tire1': (0, 1, 400), 'tire2': (0, 2, 1500), 'engine1': (2, 1, 2000), 'muffler1': (4, 1, 1500), 'brake1': (3, 1, 1500), 'frame1': (1, 1, 2000)}
def sim(order, rival=RIV, maxraces=200):
    st = [0] * 6; money = 0; wins = races = 0; todo = list(order); bought = []
    while wins < 5 and races < maxraces:
        t = T[tuple(st)]; races += 1
        if t < rival: wins += 1; money += 1200
        elif t < rival + 10: money += 800
        else: money += 400
        while todo:                       # buy in order as soon as affordable
            n = todo[0]; s, tier, p = ITEMS[n]
            if st[s] >= tier: todo.pop(0); continue
            if money < p: break
            money -= p; st[s] = tier; todo.pop(0); bought.append((races, n))
    return races, money, tuple(st), bought
if __name__ == '__main__':
    names = list(ITEMS); res = []
    for o in itertools.permutations(names):
        r = sim(o); res.append((r[0], -r[1], o, r))
    res.sort(key=lambda x: (x[0], x[1]))
    print(f'rival {RIV} s; stock lap total {T[(0,)*6]:.2f} s\nbest orders (races to 5 wins, money left):')
    seen = set()
    for r, m, o, full in res:
        key = tuple(b[1] for b in full[3])
        if key in seen: continue
        seen.add(key); print(f'  {r:3d} races, ${-m:>6}  buys: ' + ', '.join(f'{n}@{k}' for k, n in full[3]) + f'  final F{full[2][1]} E{full[2][2]} B{full[2][3]} M{full[2][4]} O{full[2][5]} T{full[2][0]}')
        if len(seen) >= 8: break
    print('worst:', res[-1][0], 'races')
    for name, o in (('engine first', ['engine1', 'oil1', 'tire1', 'tire2', 'muffler1', 'brake1', 'frame1']), ('tires first', ['tire1', 'tire2', 'oil1', 'engine1', 'muffler1', 'brake1', 'frame1']),
                    ('cheapest first', ['oil1', 'tire1', 'brake1', 'muffler1', 'engine1', 'frame1', 'tire2']), ('tire2 asap', ['tire2', 'oil1', 'engine1', 'muffler1', 'brake1', 'frame1'])):
        full = sim(o); print(f'{name:15s} {full[0]} races, ${full[1]}  ' + ', '.join(f'{n}@{k}' for k, n in full[3]))
