#!/usr/bin/env python3 -I
"""Decode the game's tile-word text: each char is a VDP name-table word whose low byte is the tile
(digits 0-9 = $14..$1D, letters A-Z = $1E..$37, $34A = '$', $34D/$34E/$361-363 = ! ? . , '; palette/priority bits in the high byte are ignored; $00 / $A000 = space).
  tools/text.py ROM ADDR [NWORDS]     decode NWORDS words from ADDR and print the string
Importable: decode(words) -> str"""
import sys
PUNCT = {0x4D: '!', 0x4E: '?', 0x61: '.', 0x62: ',', 0x63: "'", 0x50: '..', 0x5F9: '!'}
def ch(w):
    t = w & 0xFF
    if 0x14 <= t <= 0x1D and (w & 0x3FF) != 0x34A: return str(t - 0x14)
    if (w & 0x3FF) == 0x34A: return '$'
    if (w & 0x1FF) in PUNCT and (w >> 8) & 1 == 1 and t in (0x4D, 0x4E, 0x50, 0x61, 0x62, 0x63): return PUNCT[t]
    if (w & 0xFFF) == 0x5F9: return '!'
    if t in (0x4D, 0x4E, 0x50, 0x61, 0x62, 0x63) and (w >> 8) in (0xE3, 0xE0, 0xE1, 0xE2): return PUNCT[t]
    if 0x1E <= t <= 0x37: return chr(ord('A') + t - 0x1E)
    if w == 0 or t == 0 and (w >> 8) in (0xA0,0xC0,0xE0,0x80,0x00): return ' '
    if 0x00 <= t < 0x1E and t != 0: return str(t % 10) if False else '[%02X]' % t
    return '[%04X]' % w
def decode(words):
    return "".join(ch(w) for w in words)
if __name__ == "__main__":
    rom = open(sys.argv[1], "rb").read(); a = int(sys.argv[2], 16); n = int(sys.argv[3]) if len(sys.argv) > 3 else 16
    print(decode([rom[a+2*i] << 8 | rom[a+2*i+1] for i in range(n)]))
