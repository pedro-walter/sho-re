#!/usr/bin/env python3 -I
"""Cross-check tools/m68k.py against MAME's unidasm output (out/unidasm.txt, made by:
   flatpak run --filesystem=$PWD --command=unidasm org.mamedev.MAME ROM -arch m68000 -basepc 0 > out/unidasm.txt)"""
import re, sys, collections
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import m68k
rom = open(sys.argv[1], "rb").read()
rd = lambda a: (rom[a] << 8 | rom[a + 1]) if a + 1 < len(rom) else 0
ref = {}
for ln in open("out/unidasm.txt"):
    m = re.match(r"([0-9a-f]+): ([0-9a-f ]+?)\s{2,}(.*)$", ln.rstrip("\n"))
    if m:
        ref[int(m.group(1), 16)] = (len(m.group(2).split()) * 2, m.group(3).strip())
def norm(t):
    t = t.lower().replace(", ", ",").replace(" ", "").replace("$", "").replace("(a7)", "(a7)").replace("#0x", "#")
    return t
bad = collections.Counter(); ex = {}
n = 0
for pc in sorted(ref):
    if pc < 0x200: continue
    i = m68k.decode(rd, pc)
    L, t = ref[pc]
    n += 1
    if i.size != L or (i.flow == "illegal") != t.startswith("dc.w"):
        key = (t.split()[0], i.text.split()[0])
        bad[key] += 1; ex.setdefault(key, (hex(pc), t, i.text))
print(n, "compared;", sum(bad.values()), "length/legality mismatches")
for k, v in bad.most_common(30): print(v, k, ex[k])
