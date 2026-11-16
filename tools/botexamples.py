#!/usr/bin/env python3 -I
"""Print example windows of bot lateral movement from tools/botsim.sh logs (used for docs/11-bot-movement.md)."""
import sys, collections
sys.argv = ['x']
exec(open('tools/botanalyze.py').read().split("def main")[0])

def ticks(path):
    fr = load(path); out = []
    for i in range(1, len(fr)):
        a, b = fr[i-1], fr[i]
        if any(a['bots'].get(n) and a['bots'][n]['depth'] != bb['depth'] for n, bb in b['bots'].items()):
            out.append((a, b))
    return out

def seq(tk, slot, i0, n):
    rows = []
    for a, b in tk[i0:i0+n]:
        bb, pb = b['bots'].get(slot), a['bots'].get(slot)
        if not bb or not pb: break
        pred, rule = predict(pb, b['st'], b['nx'])
        rows.append((b['f'], b['st'], b['nx'], b['plat'], pb['lat'], bb['lat'], pb['lane'], bb['z'], bb['x'], rule, pb['f3a']))
    return rows

def show(title, rows):
    print('##', title)
    print('  frame st nx  you  lat_before->after lane   z    x   rule            flags')
    for r in rows:
        print('  %5d  %d  %d %4d  %5d -> %5d  %5d %4d %4d  %-16s %d' % (r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10]))

path = 'out/botsim/t1_auto.txt'; tk = ticks(path)
def find(pred_fn, span, slot=None, start=0):
    for i in range(start, len(tk) - span):
        for n in ([slot] if slot is not None else range(5)):
            rows = seq(tk, n, i, span)
            if len(rows) == span and pred_fn(rows): return n, i, rows
    return None

# 1 staying in lane
r = find(lambda rs: all(x[9] == 'at-lane' and x[1] == 1 for x in rs) and rs[0][7] < 0xAF and rs[0][7] > 40, 8)
if r: show('E1 bot sitting on its lane (straight, slot %d)' % r[0], r[2])
# wobble around the lane
r = find(lambda rs: all(x[9] == 'return' and x[1] == 1 for x in rs) and len({x[5] for x in rs}) == 2, 8)
if r: show('E1b wobble around lane (slot %d)' % r[0], r[2])

def run_of(rows, pred):
    return all(pred(x) for x in rows)

# 2 outward drift in a steady curve, ending in the clamp
r = find(lambda rs: sum(x[9] == 'drift(st3)' for x in rs[:6]) == 6 and rs[0][7] > 30 and rs[-1][9] == 'drift(st3) clamp', 16)
if r: show('E2 outward drift in a state-3 curve, stopping at the +-250 limit (slot %d)' % r[0], r[2])
r = find(lambda rs: sum(x[9] == 'drift(st2)' for x in rs[:6]) == 6 and rs[0][7] > 30 and rs[-1][9] == 'drift(st2) clamp', 16)
if r: show('E2b same in a state-2 curve (slot %d)' % r[0], r[2])

# 4 straight -> announce -> curve : bot clearly moving in each phase
def e4(rs):
    ph = [x[9] for x in rs]
    return ('at-lane' in ph[:3] or ph[0] == 'at-lane') and ph.count('announce(next3)') >= 6 and ph.count('drift(st3)') >= 4 and rs[0][7] > 20
r = find(e4, 90)
if r:
    rows = r[2]
    keep = [x for k, x in enumerate(rows) if k == 0 or x[9] != rows[k-1][9] or k % 6 == 0 or (k+1 < len(rows) and rows[k+1][9] != x[9])]
    show('E4 straight -> announced curve -> curve (slot %d)' % r[0], keep)

# 5 blocked by a neighbour bot (flags set by the spacing code, rider far away)
for path2 in ['out/botsim/t1_auto.txt', 'out/botsim/t3_auto.txt', 'out/botsim/t2_auto.txt']:
    tk = ticks(path2)
    found = False
    for i in range(1, len(tk) - 2):
        a, b = tk[i]
        for n, pb in a['bots'].items():
            if pb['f3a'] & 3 and pb['z'] > 30 and pb['z'] < 0xAF and not (pb['z'] > 0x70 and abs(pb['x']) < 0x38):
                pred, rule = predict(pb, b['st'], b['nx'])
                if rule.endswith('blocked'):
                    # show the neighbour too
                    print('## E5 blocked by a neighbouring bot (%s, frame %d)' % (path2.split('/')[-1], b['f']))
                    print('  road st=%d nx=%d; slot %d flags=%d lat %d -> %d (would have moved to %d), z=%d x=%d' % (b['st'], b['nx'], n, pb['f3a'], pb['lat'], b['bots'][n]['lat'], predict({**pb, 'f3a': 0}, b['st'], b['nx'])[0], pb['z'], pb['x']))
                    for m, q in a['bots'].items():
                        if m != n: print('    other bot slot %d: lat=%d z=%d (lat gap %d, z gap %d, limit z gap %d)' % (m, q['lat'], q['z'], q['lat']-pb['lat'], q['z']-pb['z'], q['z']*32//191))
                    found = True; break
        if found: break
    if found: break

# 6 blocked by the rider
for path2 in ['out/botsim/t1_auto.txt', 'out/botsim/t3_auto.txt', 'out/botsim/t2_auto.txt']:
    tk = ticks(path2); found = False
    for i in range(1, len(tk) - 2):
        a, b = tk[i]
        for n, pb in a['bots'].items():
            if pb['z'] > 0x70 and pb['z'] < 0xAF and abs(pb['x']) < 0x38:
                pred, rule = predict(pb, b['st'], b['nx'])
                free = predict({**pb, 'x': 999}, b['st'], b['nx'])[0]
                if rule.endswith('blocked') and free != pb['lat']:
                    print('## E6 blocked by the rider (%s, frame %d)' % (path2.split('/')[-1], b['f']))
                    print('  road st=%d nx=%d; you at lat %d; slot %d lat=%d lane=%d x=%d z=%d: would move to %d, stays at %d' % (b['st'], b['nx'], b['plat'], n, pb['lat'], pb['lane'], pb['x'], pb['z'], free, b['bots'][n]['lat']))
                    found = True; break
        if found: break
    if found: break

# 9 inheritance
print('## E9 respawn inherits the old lateral value')
for path2 in ['out/botsim/t1_auto.txt']:
    fr = load(path2); last = {}; k = 0
    for i in range(1, len(fr)):
        a, b = fr[i-1], fr[i]
        for n, bb in b['bots'].items():
            if n not in a['bots'] and n in last and abs(bb['lat']-bb['lane']) > 30 and k < 4:
                print('  frame %5d slot %d: previous bot left at lat %d, new bot appears at lat %d (its lane is %d)' % (b['f'], n, last[n], bb['lat'], bb['lane'])); k += 1
        for n, bb in a['bots'].items():
            if n not in b['bots']: last[n] = bb['lat']
