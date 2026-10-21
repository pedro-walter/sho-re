#!/usr/bin/env python3 -I
"""Decode the roadside-object streams (static objects, type $34) of a course.
Stream ($FF066E) entry = 3 words: start distance, count (x16 steps), pattern index; terminated by a negative first word.
Pattern ($5771C table of longs) = word mask (1 bit per step, rotated left) + records [flag, subtype, lat.w, attr.w] (6 bytes each),
a record whose first byte is negative restarts the record list."""
import sys
ROM = open(sys.argv[0].rsplit("/tools/",1)[0] + "/Super Hang-On (World) (En,Ja) (Rev A).md", "rb").read() if "/tools/" in sys.argv[0] else open("Super Hang-On (World) (En,Ja) (Rev A).md","rb").read()
def u16(a): return int.from_bytes(ROM[a:a+2], "big")
def s16(a): v = u16(a); return v - 65536 if v >= 32768 else v
def u32(a): return int.from_bytes(ROM[a:a+4], "big")
PAT = 0x5771C
WIDTH_TBL = 0xD3F8   # crash half-width by (subtype - $0E)

def pattern(idx):
    a = u32(PAT + 4*idx)
    mask = u16(a); recs = []; p = a + 2
    while ROM[p] < 0x80:
        recs.append((ROM[p+1], s16(p+2), u16(p+4))); p += 6
    return mask, recs

def stream(addr):
    out = []
    while u16(addr) < 0x8000:
        out.append((u16(addr), u16(addr+2), u16(addr+4))); addr += 6
    return out

def expand(addr):
    """-> list of (distance, subtype, lat, attr, pattern idx)"""
    objs = []
    for pos, cnt, idx in stream(addr):
        mask, recs = pattern(idx)
        if not recs: continue
        n = 0
        for k in range(16*cnt):
            bit = (mask >> (15 - (k % 16))) & 1
            if bit:
                sub, lat, attr = recs[n % len(recs)]; n += 1
                objs.append((pos + k, sub, lat, attr, idx))
    return objs

def halfwidth(sub):
    i = sub - 0x0E
    return u16(WIDTH_TBL + 2*i) if 0 <= i < 25 else None

if __name__ == "__main__":
    a = int(sys.argv[1], 16)
    for o in expand(a): print(o, halfwidth(o[1]))
