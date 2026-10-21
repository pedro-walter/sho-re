#!/usr/bin/env python3 -I
"""Write a patched copy of the ROM and fix the header checksum (the game verifies it at boot and hangs otherwise).
Usage: tools/patchrom.py OUT.md ADDR:HEXBYTES [ADDR:HEXBYTES ...]      e.g.  tools/patchrom.py out/patched/a.md 8E58:000000010008"""
import os, sys
SRC = os.path.join(os.getcwd(), "Super Hang-On (World) (En,Ja) (Rev A).md")

def checksum(rom):
    # $18E = 16-bit sum of all words from $200 to the end address in the header ($1A4)
    end = int.from_bytes(rom[0x1A4:0x1A8], "big")
    return sum(int.from_bytes(rom[a:a + 2], "big") for a in range(0x200, end + 1, 2)) & 0xFFFF

if __name__ == "__main__":
    rom = bytearray(open(SRC, "rb").read())
    assert checksum(rom) == int.from_bytes(rom[0x18E:0x190], "big"), "checksum rule does not match the original ROM"
    for p in sys.argv[2:]:
        a, h = p.split(":")
        b = bytes.fromhex(h); a = int(a, 16); rom[a:a + len(b)] = b
    rom[0x18E:0x190] = checksum(rom).to_bytes(2, "big")
    open(sys.argv[1], "wb").write(rom)
    print("wrote", sys.argv[1], "checksum %04X" % checksum(rom))
