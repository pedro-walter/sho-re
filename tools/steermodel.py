#!/usr/bin/env python3
"""Exact cycle-level model of the steering / lateral chain, validated against a SHO_MLOG log (scripts/autolap5.lua).
Per 3-frame cycle (frames 3c..3c+2): [lateral_model $A44C at ~3c+1: lean += clamp(so-lean, +-12); lat += steer delta]
then [controls_model $9788 at 3c+2: handlebar from the sampled pad, steer_out]; the road push ($EA7A) lands in the same cycle (observed delta used here).
Usage: tools/steermodel.py LOG TIRE FRAME [LAG]"""
import re, sys
TIREADJ = [32, 20, 8, -4, -16]
FR = [(2,3,6),(2,4,8),(2,4,9),(3,5,11),(4,7,16),(5,8,18)]
def sdiv(a, b):  # 68k divs: truncate toward zero
    q = abs(a) // abs(b); return q if (a >= 0) == (b >= 0) else -q
def ctrl(hb, pad, v, ft):
    d1, d2, d3 = FR[ft]
    if ft >= 2: s = v >> 7; d1 += s; d2 += s; d3 += s
    if pad == 'L':
        if hb < 0x80: hb += d3
        else:
            hb += d2
            if hb >= 0xC7: hb = 0xC6
    elif pad == 'R':
        if hb >= 0x80: hb -= d3
        else:
            hb -= d2
            if hb < 0x3A: hb = 0x3A
    else:
        if hb < 0x80: hb += d1
        elif hb > 0x80: hb -= d1
    return hb
def steer_out(hb):
    d = min(0xC6, max(0x3A, hb))
    if 0x6C <= d <= 0x94: d = 0x80
    d -= 0x80
    q = sdiv(d << 8, 0x8C)
    q = min(0x7F, max(-127, q))
    return -q
def lateral(lean, v, skid, tire):
    d = lean
    if not skid and v <= 0x7F: d = (d * v) >> 7
    d = d << 4
    div = 128 + TIREADJ[tire]
    return 2 * -sdiv(d, div)
def lean_step(lean, so):
    return lean + max(-12, min(12, so - lean))
def parse(path):
    rows = []
    for ln in open(path):
        m = re.search(r' K (\d+) in=(\w) hb=(\d+) so=(-?\d+) lean=(-?\d+) lat=(-?\d+) v=(\d+) d=(\d+) skid=(\d+) D=(-?\d+),(-?\d+) sk=(\d+) wr=(.*)', ln)
        if m: rows.append(dict(k=int(m[1]), i=m[2], hb=int(m[3]), so=int(m[4]), lean=int(m[5]), lat=int(m[6]), v=int(m[7]), d=int(m[8]), skid=int(m[9]), D1=int(m[10]), D2=int(m[11]), wr=[(w.split(':')[0], int(w.split(':')[1])) for w in m[13].split(',') if w]))
    return rows
if __name__ == '__main__':
    rows = parse(sys.argv[1]); tire = int(sys.argv[2]); ft = int(sys.argv[3]); lag = int(sys.argv[4]) if len(sys.argv) > 4 else 3
    byk = {r['k']: r for r in rows}
    ks = sorted(byk)
    bad = {'hb': 0, 'so': 0, 'lean': 0, 'lat': 0}; n = 0; first = []
    # cycles: tick frame = 3c+2 (phase 2)
    prev = None
    for k in ks:
        if k % 3 != 2 or k - 3 not in byk or k - 2 not in byk: continue
        p = byk[k - 3]; r = byk[k]
        # pad sampled for this tick = command set at callback frame k-lag
        pad = byk.get(k - lag, {}).get('i', 'N')
        # lateral_model at k-2 (phase 0) or k-1 (phase 1): sum of A4B4 deltas in frames k-2..k-1... use writes between
        lw = [d for kk in (k - 2, k - 1, k) for (pc, d) in byk[kk]['wr'] if pc == 'A4B4'] if all(x in byk for x in (k - 2, k - 1)) else []
        lean = lean_step(p['lean'], p['so'])
        v = byk[k - 1]['v']
        dl = lateral(lean, v, p['skid'] != 0, tire)
        hb = ctrl(p['hb'], pad, byk[k]['v'], ft)
        so = steer_out(hb)
        pred = dict(hb=hb, so=so, lean=lean)
        n += 1
        for key in ('hb', 'so'):
            if pred[key] != r[key]: bad[key] += 1; first.append((k, key, pred[key], r[key], pad, p['hb']))
        if lw and sum(lw) != dl: bad['lat'] += 1; first.append((k, 'lat', dl, sum(lw), lean, v))
        if r['lean'] != lean: bad['lean'] += 1; first.append((k, 'lean', lean, r['lean']))
    print('cycles', n, 'mismatches', bad)
    for f in first[:15]: print(f)
