#!/usr/bin/env python3 -I
"""Decode the game's on-screen message blocks (see sub_005622 / sub_00840E).
Block layout at address A:  long vdp_cmd, word width-1, word height-1, then (w)*(h) tile words (row-major).
  tools/msgs.py ROM ADDR            decode one block
Importable: block(rom, a) -> list of text rows"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import text
def u16(r, a): return r[a] << 8 | r[a+1]
def u32(r, a): return (u16(r, a) << 16) | u16(r, a+2)
def block(r, a):
    if not (0 <= a < len(r) - 8): return None
    vdp = u32(r, a); w = u16(r, a+4) + 1; h = u16(r, a+6) + 1
    if w > 40 or h > 12: return None
    rows = []
    for y in range(h):
        rows.append(text.decode([u16(r, a + 8 + 2*(y*w + x)) for x in range(w)]).rstrip())
    return rows
if __name__ == "__main__":
    r = open(sys.argv[1], "rb").read(); a = int(sys.argv[2], 16)
    print("\n".join(block(r, a) or ["?"]))
