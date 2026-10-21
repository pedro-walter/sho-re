#!/usr/bin/env python3 -I
"""Annotated 68000 disassembly of Super Hang-On (Genesis).

  python3 -I tools/disasm.py ROM out.asm [--cov out/cov_a.txt ...] [--annot disasm/annot]

Code discovery: recursive descent from the vector table (+ jump tables made of bra opcodes), plus
every PC in the coverage files (tools/cov.sh), plus `@AAAAAA name code` seeds in symbols.txt.
Everything else is printed as data (regions.txt can force a typed layout).

Annotation files (disasm/annot/, all hand-written, one entry per line, '#' comments):
  symbols.txt  `@AAAAAA name`  followed by `;; doc` lines  -> routine/data label + header
  ram.txt      `AAAAAA name [size] description`            -> RAM/IO variable names (size: b/w/l)
  hwregs.txt   same format, hardware registers
  comments.txt `AAAAAA text`                               -> inline comment on that address
  regions.txt  `AAAAAA-BBBBBB type [desc]`                 -> type: code|bytes|words|longs|ptrs|text|gfx
Also writes <out>.ramxref.txt: who reads/writes each RAM address.
"""
import sys, os, re, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import m68k


def parse_annot(d):
    A = dict(sym={}, doc={}, ram={}, ramdoc={}, size={}, com={}, regions=[], seeds=set(), hw={})
    def lines(name):
        p = os.path.join(d, name)
        if not os.path.exists(p): return []
        return [l.rstrip("\n") for l in open(p)]
    cur = None
    for l in lines("symbols.txt"):
        if l.startswith("@"):
            parts = l[1:].split()
            cur = int(parts[0], 16); A["sym"][cur] = parts[1]
            if "code" in parts[2:]: A["seeds"].add(cur)
        elif l.startswith(";;") and cur is not None:
            A["doc"].setdefault(cur, []).append(l[2:].strip())
    for name, key in (("ram.txt", "ram"), ("hwregs.txt", "hw")):
        for l in lines(name):
            l = l.split("#")[0].strip() if name == "ram.txt" and False else l
            if not l.strip() or l.startswith("#"): continue
            p = l.split(None, 2)
            if len(p) < 2: continue
            a = int(p[0], 16)
            A[key][a] = p[1]
            rest = p[2] if len(p) > 2 else ""
            m = re.match(r"\[(b|w|l|\d+)\]\s*(.*)", rest)
            if m:
                A["size"][a] = m.group(1); rest = m.group(2)
            if rest: A["ramdoc"][a] = rest
    for l in lines("comments.txt"):
        if not l.strip() or l.startswith("#"): continue
        a, _, t = l.partition(" ")
        A["com"].setdefault(int(a, 16), []).append(t.strip())
    for l in lines("regions.txt"):
        if not l.strip() or l.startswith("#"): continue
        p = l.split(None, 2)
        lo, _, hi = p[0].partition("-")
        A["regions"].append((int(lo, 16), int(hi or lo, 16), p[1], p[2] if len(p) > 2 else ""))
    return A


def vdp_cmd(v):
    """decode a 32-bit VDP control-port command word"""
    cd = ((v >> 30) & 3) | ((v >> 2) & 0x3C)
    addr = ((v >> 16) & 0x3FFF) | ((v & 3) << 14)
    kind = {0x00: "VRAM read", 0x01: "VRAM write", 0x03: "CRAM write", 0x04: "VSRAM read", 0x05: "VSRAM write",
            0x08: "CRAM read", 0x21: "VRAM write (DMA)", 0x23: "CRAM write (DMA)", 0x25: "VSRAM write (DMA)",
            0x30: "VRAM copy", 0x20: "DMA"}.get(cd)
    if kind is None: return None
    return "%s @ $%04X" % (kind, addr)


VDP_REGS = ["MODE1", "MODE2", "PLANE_A", "WINDOW", "PLANE_B", "SPRITES", "?6", "BGCOLOR", "?8", "?9", "HINT_CNT",
            "MODE3", "MODE4", "HSCROLL", "?14", "AUTOINC", "PLANE_SIZE", "WIN_X", "WIN_Y", "DMA_LEN_L", "DMA_LEN_H",
            "DMA_SRC_L", "DMA_SRC_M", "DMA_SRC_H"]


class Dis:
    def __init__(s, rom, A, covs):
        s.rom = rom; s.A = A
        s.rd = lambda a: (rom[a] << 8 | rom[a + 1]) if 0 <= a < len(rom) - 1 else 0
        s.insn = {}          # pc -> Insn (code starts)
        s.sub = set()        # call targets
        s.labels = set()     # branch/jump targets
        s.datarefs = collections.defaultdict(set)   # rom addr -> {referencing pcs}
        s.callers = collections.defaultdict(set)
        s.ramx = collections.defaultdict(lambda: [set(), set()])   # addr -> [readers, writers]
        s.covered = set()
        s.spec = set()       # addresses decoded speculatively (not executed, not statically reachable)
        for c in covs:
            for l in open(c):
                l = l.strip()
                if re.fullmatch(r"[0-9A-Fa-f]{6}", l): s.covered.add(int(l, 16))
        s.region_at = {}
        for lo, hi, t, d in A["regions"]:
            if t == "code": A["seeds"].add(lo)

    def run(s):
        q = []
        v = lambda off: (s.rd(off) << 16) | s.rd(off + 2)
        for off in range(4, 0x100, 4):
            t = v(off)
            if t < len(s.rom) and (off == 4 or True): q.append(t); s.sub.add(t)
        q += sorted(s.covered) + sorted(s.A["seeds"])
        for a in s.A["seeds"]: s.sub.add(a)
        s._descend(q)

    def run_from(s, q):
        s._descend(list(q))

    def _descend(s, q):
        while q:
            pc = q.pop()
            while pc < len(s.rom) and pc not in s.insn and pc % 2 == 0:
                if s._in_data_region(pc): break
                i = m68k.decode(s.rd, pc)
                if i.flow == "illegal" and pc not in s.covered and False: break
                s.insn[pc] = i
                for a, k in i.refs:
                    if a < len(s.rom) and k in ("pc", "r", "a", "w"): s.datarefs[a].add(pc)
                    if 0xFF0000 <= a <= 0xFFFFFF: s.ramx[a][1 if k == "w" else 0].add(pc)
                if i.target is not None and i.target < len(s.rom):
                    if i.flow in ("bsr", "jsr"): s.sub.add(i.target); s.callers[i.target].add(pc)
                    else: s.labels.add(i.target)
                    q.append(i.target)
                if i.flow in ("jmp", "jsr") and i.text.find("(pc,") >= 0 and i.refs:
                    s._jumptable(i.refs[-1][0], q)
                if i.flow in ("bra", "jmp", "rts", "rte", "illegal"): break
                pc += i.size

    def _try_spec(s, a):
        """decode forward from a; accept if it reaches a terminator with only sane instructions"""
        seq = []; pc = a
        while pc < len(s.rom) and len(seq) < 150:
            if pc in s.insn:
                break
            i = m68k.decode(s.rd, pc)
            if i.flow in ("illegal", "trap") or s.rd(pc) == 0 or i.text.startswith("dc.w"): return None
            if i.target is not None and not (0x200 <= i.target < len(s.rom)) or (i.target or 0) % 2: return None
            if any(k in ("w", "r") and 0xE00000 > ad >= len(s.rom) and ad < 0xA00000 for ad, k in i.refs): return None
            seq.append(i); pc += i.size
            if i.flow in ("rts", "rte", "bra", "jmp"): return seq if len(seq) >= 2 or i.flow in ("rts", "rte") else None
        return seq if pc in s.insn and seq else None

    def speculate(s):
        changed = True
        while changed:
            changed = False
            starts = sorted(pc + i.size for pc, i in s.insn.items() if i.flow in ("rts", "rte", "bra", "jmp"))
            for a in starts:
                if a in s.insn or a % 2 or a >= len(s.rom) or s._in_data_region(a): continue
                seq = s._try_spec(a)
                if not seq: continue
                before = set(s.insn)
                for i in seq: s.spec.add(i.pc)
                s.A["seeds"].add(a); s.sub.add(a)
                s.run_from([i.pc for i in seq[:1]])
                for pc in set(s.insn) - before: s.spec.add(pc)
                changed = True

    def _in_data_region(s, pc):
        for lo, hi, t, d in s.A["regions"]:
            if t != "code" and lo <= pc <= hi: return True
        return False

    def _jumptable(s, base, q):
        """pc-relative indexed jump: table of bra opcodes"""
        a = base
        n = 0
        while a < len(s.rom) and n < 128:
            o = s.rd(a)
            if o & 0xFF00 != 0x6000: break
            if o & 0xFF == 0: t = a + 2 + m68k.sx(s.rd(a + 2), 16); sz = 4
            elif o & 0xFF != 0xFF: t = a + 2 + m68k.sx(o & 0xFF, 8); sz = 2
            else: break
            s.labels.add(a); q.append(a)
            a += sz; n += 1

    # ------------------------------------------------------------------ naming
    def name(s, a):
        A = s.A
        if a in A["sym"]: return A["sym"][a]
        if a in A["hw"]: return A["hw"][a]
        if a in A["ram"]: return A["ram"][a]
        if a in s.sub: return "sub_%06X" % a
        if a in s.insn: return "loc_%06X" % a
        if a in s.datarefs and a < len(s.rom): return "dat_%06X" % a
        return None

    def symbolize_addr(s, a):
        n = s.name(a)
        if n: return n
        for d in range(1, 4):  # byte/word/long inside a named variable
            n = s.A["ram"].get(a - d) or s.A["hw"].get(a - d)
            if n and 0xFF0000 <= a: return "%s+%d" % (n, d)
        return None

    def operand_text(s, i):
        t = i.text
        def rep_abs(m):
            a = int(m.group(1), 16)
            if m.group(2) == "w" and a >= 0xFFFF8000: a &= 0xFFFFFF
            elif m.group(2) == "w": return m.group(0)
            n = s.symbolize_addr(a & 0xFFFFFF)
            return n if n else m.group(0)
        t = re.sub(r"\$([0-9a-f]+)\.([lw])\b", rep_abs, t)
        def rep_pc(m):
            a = int(m.group(1), 16)
            n = s.symbolize_addr(a)
            return (n + "(pc" + m.group(2)) if n else m.group(0)
        t = re.sub(r"\$([0-9a-f]+)\(pc([,)])", lambda m: (s.symbolize_addr(int(m.group(1), 16)) or "$" + m.group(1)) + "(pc" + m.group(2), t)
        if i.target is not None and i.flow in ("bra", "bsr", "bcc", "dbcc", "jmp", "jsr"):
            n = s.name(i.target)
            if n: t = re.sub(r"\$%x\b" % i.target, n, t, count=1)
        return t

    def vdp_note(s, i):
        t = i.text
        m = re.match(r"move\.([wl])\s+#\$([0-9a-f]+),(.+)", t)
        if not m: return None
        v = int(m.group(2), 16); dest = m.group(3)
        isctl = "VDP_CTRL" in s.operand_text(i) or "$c00004" in dest or "$c00006" in dest
        if not isctl: return None
        if m.group(1) == "w" and 0x8000 <= v < 0x9800:
            r = (v >> 8) & 31; nm = VDP_REGS[r] if r < len(VDP_REGS) else "?"
            return "VDP reg %d (%s) = $%02X" % (r, nm, v & 0xFF)
        if m.group(1) == "l": return vdp_cmd(v)
        return None

    # ------------------------------------------------------------------ output
    def region_for(s, a):
        for lo, hi, t, d in s.A["regions"]:
            if lo <= a <= hi: return (lo, hi, t, d)
        return None

    def write(s, out):
        A = s.A; rom = s.rom
        o = []
        P = o.append
        P("; Super Hang-On (Genesis, World Rev A) - generated by tools/disasm.py; do not edit")
        P("; %d instructions, %d routines, %d coverage addresses used" % (len(s.insn), len(s.sub), len(s.covered)))
        P("")
        a = 0
        n = len(rom)
        while a < n:
            if a in A["doc"] or a in s.sub and a in s.insn:
                P("")
                P(";" + "=" * 70)
                nm = s.name(a)
                P("; %s  ($%06X)%s" % (nm or "", a, "" if a in A["sym"] else "  (not yet analysed)"))
                for d in A["doc"].get(a, []): P(";; " + d)
                cs = sorted(s.callers.get(a, []))
                if cs: P("; called from: " + ", ".join("$%06X" % c for c in cs[:12]) + (" ..." if len(cs) > 12 else ""))
                P(";" + "=" * 70)
            reg = s.region_for(a)
            if a in s.insn and not (reg and reg[2] != "code"):
                i = s.insn[a]
                lbl = s.name(a)
                if lbl and (a in s.labels or a in s.sub or a in A["sym"]): P("%s:" % lbl)
                txt = s.operand_text(i)
                bytes_ = "".join("%04x " % w for w in i.words)
                cm = []
                note = s.vdp_note(i)
                if note: cm.append(note)
                cm += A["com"].get(a, [])
                if i.flow == "illegal" and a not in s.covered: cm.append("probably data")
                if a in s.spec: cm.append("? not executed in any trace")
                line = "  %06X  %-22s %s" % (a, bytes_, txt)
                if cm: line = line.ljust(64) + " ; " + " | ".join(cm)
                P(line)
                a += i.size
                continue
            # data
            end = a + 1
            hi_lim = n
            if reg: hi_lim = min(n, reg[1] + 1)
            while end < hi_lim and end not in s.insn and end not in A["sym"] and (end not in s.datarefs or end - a < 2):
                if end - a >= 16 and not reg: break
                end += 1
                if end in s.insn: break
            if end % 2 and end < n: end += 1
            end = min(end, hi_lim if reg else n)
            if end <= a: end = a + 1
            lbl = s.name(a)
            if lbl: P("%s:" % lbl)
            typ = reg[2] if reg else "bytes"
            if reg and a == reg[0] and reg[3]: P("; " + reg[3])
            chunk = rom[a:end]
            for d in A["com"].get(a, []): pass
            if typ in ("words", "gfx") and len(chunk) >= 2:
                ws = ["$%04x" % (chunk[k] << 8 | chunk[k + 1]) for k in range(0, len(chunk) - 1, 2)]
                P("  %06X  dc.w    %s" % (a, ",".join(ws)))
                if len(chunk) % 2: P("  %06X  dc.b    $%02x" % (a + len(chunk) - 1, chunk[-1]))
            elif typ in ("longs", "ptrs") and len(chunk) >= 4:
                for k in range(0, len(chunk) - 3, 4):
                    v = int.from_bytes(chunk[k:k + 4], "big"); nm = s.name(v) if typ == "ptrs" else None
                    P("  %06X  dc.l    %s" % (a + k, nm or "$%08x" % v))
            else:
                txt = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
                P("  %06X  dc.b    %-48s ; %s" % (a, ",".join("$%02x" % b for b in chunk), txt))
            a = end
        open(out, "w").write("\n".join(o) + "\n")
        # ram xref
        with open(out + ".ramxref.txt", "w") as f:
            f.write("# RAM address  name  | writers | readers   (pc of instruction; from static decode of discovered code)\n")
            for ad in sorted(s.ramx):
                rd, wr = s.ramx[ad]
                f.write("%06X %-22s | W %s | R %s\n" % (ad, A["ram"].get(ad, ""),
                        " ".join("%06X" % x for x in sorted(wr)[:10]) + (" ..(%d)" % len(wr) if len(wr) > 10 else ""),
                        " ".join("%06X" % x for x in sorted(rd)[:10]) + (" ..(%d)" % len(rd) if len(rd) > 10 else "")))


def main():
    a = sys.argv[1:]
    rom = open(a[0], "rb").read(); out = a[1]
    covs = []; annot = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "disasm", "annot")
    i = 2
    while i < len(a):
        if a[i] == "--cov": covs.append(a[i + 1]); i += 2
        elif a[i] == "--annot": annot = a[i + 1]; i += 2
        else: i += 1
    A = parse_annot(annot)
    d = Dis(rom, A, covs); d.run(); d.speculate(); d.write(out)
    print("%d instructions, %d routines; wrote %s" % (len(d.insn), len(d.sub), out))


if __name__ == "__main__":
    main()
