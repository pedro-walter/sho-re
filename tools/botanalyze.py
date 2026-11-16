#!/usr/bin/env python3 -I
"""Check the bot lateral-movement rules against logs from tools/botsim.sh.

Usage: tools/botanalyze.py out/botsim/NAME.txt [...]   [--mism N] [--stats]
Predicts each bot's next `lat` (+$08) from the previous frame with the rules read from bot_update
($D596..$D654) and reports how often the prediction is exact, and what the misses look like.
"""
import sys, collections

def load(path):
    frames = []          # list of dict(f, dist, lap, plat, spd, st, nx, bots={slot: dict})
    cur = None
    for ln in open(path):
        p = ln.split()
        if not p: continue
        if p[0] == 'F' and len(p) == 9:
            cur = dict(f=int(p[1]), dist=int(p[2]), lap=int(p[3]), plat=int(p[4]), spd=int(p[5]),
                       st=int(p[6]), nx=int(p[7]), orig=int(p[8]), bots={})
            frames.append(cur)
        elif p[0] == 'B' and cur is not None and len(p) == 11:
            n = int(p[1])
            cur['bots'][n] = dict(lat=int(p[2]), lane=int(p[3]), x=int(p[4]), z=int(p[5]), depth=int(p[6]),
                                  f3a=int(p[7]), f3d=int(p[8]), f3e=int(p[9]), d34=int(p[10]))
    return frames

def predict(b, st, nx):
    """Return (predicted new lat, rule name) for a bot whose state at the start of the update is b.
    st = road_state ($FF067E), nx = road_next_state ($FF0676)."""
    if b['z'] >= 0xAF:
        return b['lat'], 'frozen(z>=AF)'
    # rider-side block bits (set at $D55E..$D586 when close to the rider)
    bit0, bit1 = bool(b['f3a'] & 1), bool(b['f3a'] & 2)      # set by the bot-vs-bot spacing code ($4714..$4788) last tick
    if b['z'] > 0x70 and abs(b['x']) < 0x38:
        if b['x'] < 0: bit0 = True
        else: bit1 = True
    lat, lane = b['lat'], b['lane']
    def curve(d0, blocked, name):
        if blocked: return lat, name + ' blocked'
        new = lat + d0
        if abs(new) < 0xFA: return new, name
        return lat, name + ' clamp'
    if nx != st and nx != 0:                       # announce window
        if nx == 1:
            if st == 1: pass                       # falls to steady/straight below
            elif st == 2: return curve(-4, bit1, 'announce(1,st2)')
            else:         return curve(+4, bit0, 'announce(1,st3)')
        elif nx == 2: return curve(-4, bit1, 'announce(next2)')
        else:         return curve(+4, bit0, 'announce(next3)')
    if st == 1:                                    # straight: return to lane at 6/update
        if lane == lat: return lat, 'at-lane'
        if lane > lat:
            return (lat, 'return blocked') if bit0 else (lat + 6, 'return')
        return (lat, 'return blocked') if bit1 else (lat - 6, 'return')
    if st == 2: return curve(+4, bit0, 'drift(st2)')
    return curve(-4, bit1, 'drift(st3)')

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    mism = 12
    if '--mism' in sys.argv: mism = int(sys.argv[sys.argv.index('--mism') + 1]); args = [a for a in args if a != str(mism)]
    tot = collections.Counter(); ok = collections.Counter(); bad = []
    for path in args:
        fr = load(path)
        for i in range(1, len(fr)):
            a, b = fr[i - 1], fr[i]
            # a "tick" = a frame in which bot_update ran: every bot's depth counter moved
            if not any(a['bots'].get(n) and a['bots'][n]['depth'] != bb['depth'] for n, bb in b['bots'].items()): continue
            for n, bb in b['bots'].items():
                pb = a['bots'].get(n)
                if not pb: continue                 # spawn frame
                if pb['depth'] > 0x1FC: continue
                for tag, (st, nx) in (('now', (b['st'], b['nx'])), ('prev', (a['st'], a['nx']))):
                    pred, rule = predict(pb, st, nx)
                    key = (tag, rule)
                    tot[key] += 1
                    if pred == bb['lat']: ok[key] += 1
                    elif tag == 'now': bad.append((path, b['f'], n, pb, bb, pred, rule, st, nx, a['st'], a['nx']))
    print('rule                          tag    n      exact')
    for key in sorted(tot, key=lambda k: (k[0], k[1])):
        print('%-30s %-5s %6d  %6.2f%%' % (key[1], key[0], tot[key], 100.0 * ok[key] / tot[key]))
    print('first mismatches (using current-frame road state):')
    for m in bad[:mism]:
        path, f, n, pb, bb, pred, rule, st, nx, pst, pnx = m
        print(f'  {path.split("/")[-1]} f={f} slot={n} rule={rule} st={st} nx={nx} (prev st={pst} nx={pnx}) lat {pb["lat"]}->{bb["lat"]} predicted {pred}  z={pb["z"]:#x} x={pb["x"]} lane={pb["lane"]}')

main()
