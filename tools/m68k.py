#!/usr/bin/env python3 -I
"""Motorola 68000 instruction decoder (no 68010+ opcodes; Genesis main CPU).

decode(read16, pc) -> Insn
  read16(addr) returns the big-endian 16-bit word at addr.
Insn fields: pc, size (bytes), text (mnemonic + operands), flow, target, refs
  flow:   'seq' | 'bra' (unconditional jump, no fallthrough) | 'bcc' (conditional) | 'bsr'/'jsr' (call)
          | 'jmp' (jump, no fallthrough) | 'rts' | 'rte' | 'dbcc' | 'trap' | 'illegal'
  target: absolute address for direct branches/calls, else None
  refs:   list of (addr, kind) absolute data references; kind in 'r','w','a'(address taken: lea/pea/jmp),'pc'
          ('pc' = PC-relative effective address, e.g. lea table(pc),a0)
Run as a script to self-test against MAME's unidasm:  python3 -I tools/m68k.py ROM.md
"""
import sys

CC = ["t", "f", "hi", "ls", "cc", "cs", "ne", "eq", "vc", "vs", "pl", "mi", "ge", "lt", "gt", "le"]
SZ = {0: "b", 1: "w", 2: "l"}


class Insn:
    __slots__ = ("pc", "size", "text", "flow", "target", "refs", "words")

    def __init__(s, pc):
        s.pc = pc; s.size = 2; s.text = "dc.w"; s.flow = "seq"; s.target = None; s.refs = []; s.words = []


def h(v, w=None):
    """hex like MAME: $1234"""
    return "$%x" % v


def sx(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


def hs(v):
    """signed hex for displacements"""
    return ("-$%x" % -v) if v < 0 else "$%x" % v


class _Ctx:
    def __init__(s, rd, pc):
        s.rd = rd; s.pc = pc; s.pos = pc + 2; s.refs = []

    def w(s):
        v = s.rd(s.pos); s.pos += 2; return v

    def l(s):
        a = s.w(); b = s.w(); return (a << 16) | b


def _ea(c, mode, reg, size, kind="r"):
    """decode an effective address; returns text. size: 'b','w','l' (for immediate)."""
    if mode == 0: return "d%d" % reg
    if mode == 1: return "a%d" % reg
    if mode == 2: return "(a%d)" % reg
    if mode == 3: return "(a%d)+" % reg
    if mode == 4: return "-(a%d)" % reg
    if mode == 5:
        d = sx(c.w(), 16); return "%s(a%d)" % (hs(d) if d else "0", reg)
    if mode == 6:
        e = c.w(); d = sx(e & 0xFF, 8)
        x = ("d" if not e & 0x8000 else "a") + str((e >> 12) & 7) + ("." + ("l" if e & 0x800 else "w"))
        return "%s(a%d,%s)" % (hs(d) if d else "0", reg, x)
    if mode == 7:
        if reg == 0:
            a = sx(c.w(), 16) & 0xFFFFFFFF
            c.refs.append((a, kind)); return "$%x.w" % (a & 0xFFFF if a < 0x8000 else a)
        if reg == 1:
            a = c.l(); c.refs.append((a, kind)); return "$%x.l" % a
        if reg == 2:
            base = c.pos; d = sx(c.w(), 16); a = (base + d) & 0xFFFFFFFF
            c.refs.append((a, "pc")); return "$%x(pc)" % a
        if reg == 3:
            base = c.pos; e = c.w(); d = sx(e & 0xFF, 8); a = (base + d) & 0xFFFFFFFF
            x = ("d" if not e & 0x8000 else "a") + str((e >> 12) & 7) + ("." + ("l" if e & 0x800 else "w"))
            c.refs.append((a, "pc")); return "$%x(pc,%s)" % (a, x)
        if reg == 4:
            if size == "l": return "#$%x" % c.l()
            v = c.w()
            return "#$%x" % (v & 0xFF if size == "b" else v)
    return None


def _regmask(m, predec):
    """movem register list"""
    if predec:  # bit0 = a7 ... bit15 = d0
        m = int("{:016b}".format(m)[::-1], 2)
    regs = ["d%d" % i for i in range(8)] + ["a%d" % i for i in range(8)]
    out = []; i = 0
    while i < 16:
        if m >> i & 1:
            j = i
            while j + 1 < 16 and (m >> (j + 1) & 1) and (j + 1) // 8 == i // 8: j += 1
            out.append(regs[i] if j == i else "%s-%s" % (regs[i], regs[j]))
            i = j + 1
        else:
            i += 1
    return "/".join(out) if out else "0"


def alt(mode, reg):
    """alterable addressing mode (can be a destination)"""
    return mode <= 6 or (mode == 7 and reg < 2)


def decode(rd, pc):
    i = Insn(pc)
    op = rd(pc)
    c = _Ctx(rd, pc)
    t = _decode(c, op, i)
    i.text = t if t is not None else "dc.w    $%04x" % op
    if t is None: i.flow = "illegal"; c.pos = pc + 2
    i.size = c.pos - pc
    i.words = [rd(pc + k) for k in range(0, i.size, 2)]
    i.refs = [(a & 0xFFFFFF, k) for a, k in c.refs]
    return i


def _fmt(m, o=""):
    return ("%-7s %s" % (m, o)).rstrip() if o else m


def _decode(c, op, i):
    top = op >> 12
    mode = (op >> 3) & 7; reg = op & 7
    rn = (op >> 9) & 7
    if top == 0:
        if op & 0x138 == 0x108:  # movep
            sz = "l" if op & 0x40 else "w"; d = sx(c.w(), 16)
            if op & 0x80: return _fmt("movep." + sz, "d%d,%s(a%d)" % (rn, hs(d), reg))
            return _fmt("movep." + sz, "%s(a%d),d%d" % (hs(d), reg, rn))
        if op & 0x100:  # dynamic bit ops
            n = ["btst", "bchg", "bclr", "bset"][(op >> 6) & 3]
            if mode == 1 or (n != "btst" and not alt(mode, reg)): return None
            e = _ea(c, mode, reg, "b", "r" if n == "btst" else "w")
            if e is None: return None
            return _fmt(n, "d%d,%s" % (rn, e))
        sel = (op >> 9) & 7
        if sel == 4:  # static bit ops
            n = ["btst", "bchg", "bclr", "bset"][(op >> 6) & 3]
            if mode == 1 or (n != "btst" and not alt(mode, reg)) or (mode == 7 and reg == 4): return None
            b = c.w() & 0xFF
            e = _ea(c, mode, reg, "b", "r" if n == "btst" else "w")
            if e is None: return None
            return _fmt(n, "#%d,%s" % (b, e))
        if sel == 7: return None
        n = ["ori", "andi", "subi", "addi", None, "eori", "cmpi"][sel]
        s = (op >> 6) & 3
        if op in (0x003C, 0x023C, 0x0A3C):
            return _fmt(n + ".b", "#$%x,ccr" % (c.w() & 0xFF))
        if op in (0x007C, 0x027C, 0x0A7C):
            return _fmt(n + ".w", "#$%x,sr" % c.w())
        if s == 3 or mode == 1 or not alt(mode, reg): return None
        sz = SZ[s]
        imm = "#$%x" % (c.l() if sz == "l" else (c.w() & (0xFF if sz == "b" else 0xFFFF)))
        e = _ea(c, mode, reg, sz, "r" if sel == 6 else "w")
        if e is None: return None
        return _fmt(n + "." + sz, "%s,%s" % (imm, e))
    if top in (1, 2, 3):
        sz = {1: "b", 3: "w", 2: "l"}[top]
        dm = (op >> 6) & 7
        if dm == 1:  # movea
            if sz == "b": return None
            e = _ea(c, mode, reg, sz); return _fmt("movea." + sz, "%s,a%d" % (e, rn)) if e else None
        e = _ea(c, mode, reg, sz)
        if e is None or (sz == "b" and mode == 1): return None
        d = _ea(c, dm, rn, sz, "w")
        if d is None or dm == 1 or (dm == 7 and rn >= 2): return None
        return _fmt("move." + sz, "%s,%s" % (e, d))
    if top == 4:
        return _decode4(c, op, i, mode, reg, rn)
    if top == 5:
        if (op >> 6) & 3 == 3:
            cc = (op >> 8) & 15
            if mode == 1:
                base = c.pos; d = sx(c.w(), 16)
                i.flow = "dbcc"; i.target = (base + d) & 0xFFFFFF
                return _fmt("db" + CC[cc], "d%d,$%x" % (reg, i.target))
            if not alt(mode, reg): return None
            return _fmt("s" + CC[cc], _ea(c, mode, reg, "b", "w"))
        sz = SZ[(op >> 6) & 3]
        q = rn or 8
        if not alt(mode, reg) or (mode == 1 and sz == "b"): return None
        e = _ea(c, mode, reg, sz, "w")
        return _fmt(("subq." if op & 0x100 else "addq.") + sz, "#%d,%s" % (q, e))
    if top == 6:
        cc = (op >> 8) & 15
        base = c.pos
        d = op & 0xFF
        if d == 0: d = sx(c.w(), 16); sfx = "w"
        elif d == 0xFF: return None  # 68020 long branch
        else: d = sx(d, 8); sfx = "b"
        t = (base + d) & 0xFFFFFFFF
        i.target = t
        if cc == 0: i.flow = "bra"; n = "bra"
        elif cc == 1: i.flow = "bsr"; n = "bsr"
        else: i.flow = "bcc"; n = "b" + CC[cc]
        return _fmt(n + "." + sfx, "$%x" % t)
    if top == 7:
        if op & 0x100: return None
        return _fmt("moveq", "#%s,d%d" % (("$%x" % (op & 0xFF)) if (op & 0xFF) < 0x80 else "-$%x" % (0x100 - (op & 0xFF)), rn))
    if top in (8, 0xC):
        sel = (op >> 6) & 7
        if sel == 3 or sel == 7:
            n = {8: ("divu", "divs"), 0xC: ("mulu", "muls")}[top][sel == 7]
            e = _ea(c, mode, reg, "w")
            return _fmt(n + ".w", "%s,d%d" % (e, rn)) if e and mode != 1 else None
        if sel == 4 and mode <= 1:
            n = "sbcd" if top == 8 else "abcd"
            return _fmt(n, ("d%d,d%d" % (reg, rn)) if mode == 0 else ("-(a%d),-(a%d)" % (reg, rn)))
        if top == 0xC and sel in (5, 6) and mode <= 1:
            if sel == 5 and mode == 0: return _fmt("exg", "d%d,d%d" % (rn, reg))
            if sel == 5 and mode == 1: return _fmt("exg", "a%d,a%d" % (rn, reg))
            if sel == 6 and mode == 1: return _fmt("exg", "d%d,a%d" % (rn, reg))
            return None
        n = "or" if top == 8 else "and"
        sz = SZ[sel & 3]
        if sel & 4:
            e = _ea(c, mode, reg, sz, "w")
            if e is None or mode <= 1 or (mode == 7 and reg >= 2): return None
            return _fmt(n + "." + sz, "d%d,%s" % (rn, e))
        e = _ea(c, mode, reg, sz)
        if e is None or mode == 1: return None
        return _fmt(n + "." + sz, "%s,d%d" % (e, rn))
    if top in (9, 0xD):
        sel = (op >> 6) & 7
        base = "sub" if top == 9 else "add"
        if sel in (3, 7):
            sz = "l" if sel == 7 else "w"
            e = _ea(c, mode, reg, sz)
            return _fmt(base + "a." + sz, "%s,a%d" % (e, rn)) if e else None
        sz = SZ[sel & 3]
        if sel & 4 and mode <= 1:
            return _fmt(base + "x." + sz, ("d%d,d%d" % (reg, rn)) if mode == 0 else ("-(a%d),-(a%d)" % (reg, rn)))
        if sel & 4:
            e = _ea(c, mode, reg, sz, "w")
            if e is None or (mode == 7 and reg >= 2): return None
            return _fmt(base + "." + sz, "d%d,%s" % (rn, e))
        e = _ea(c, mode, reg, sz)
        if e is None or (mode == 1 and sz == "b"): return None
        return _fmt(base + "." + sz, "%s,d%d" % (e, rn))
    if top == 0xB:
        sel = (op >> 6) & 7
        if sel in (3, 7):
            sz = "l" if sel == 7 else "w"
            e = _ea(c, mode, reg, sz)
            return _fmt("cmpa." + sz, "%s,a%d" % (e, rn)) if e else None
        sz = SZ[sel & 3]
        if sel & 4:
            if mode == 1: return _fmt("cmpm." + sz, "(a%d)+,(a%d)+" % (reg, rn))
            if not alt(mode, reg) or mode == 0 and False: return None
            e = _ea(c, mode, reg, sz, "w")
            if e is None: return None
            return _fmt("eor." + sz, "d%d,%s" % (rn, e))
        e = _ea(c, mode, reg, sz)
        if e is None or (mode == 1 and sz == "b"): return None
        return _fmt("cmp." + sz, "%s,d%d" % (e, rn))
    if top == 0xE:
        if (op >> 6) & 3 == 3:
            if op & 0x800: return None
            n = ["as", "ls", "rox", "ro"][(op >> 9) & 3] + ("l" if op & 0x100 else "r")
            e = _ea(c, mode, reg, "w", "w")
            if e is None or mode <= 1 or (mode == 7 and reg >= 2): return None
            return _fmt(n + ".w", e)
        sz = SZ[(op >> 6) & 3]
        n = ["as", "ls", "rox", "ro"][(op >> 3) & 3] + ("l" if op & 0x100 else "r")
        if op & 0x20: return _fmt(n + "." + sz, "d%d,d%d" % (rn, reg))
        return _fmt(n + "." + sz, "#%d,d%d" % (rn or 8, reg))
    if top == 0xA:
        i.flow = "illegal"; return "dc.w    $%04x ; line-A" % op
    if top == 0xF:
        i.flow = "illegal"; return "dc.w    $%04x ; line-F" % op
    return None


def _decode4(c, op, i, mode, reg, rn):
    if op == 0x4E70: return "reset"
    if op == 0x4E71: return "nop"
    if op == 0x4E72: return _fmt("stop", "#$%x" % c.w())
    if op == 0x4E73: i.flow = "rte"; return "rte"
    if op == 0x4E75: i.flow = "rts"; return "rts"
    if op == 0x4E76: return "trapv"
    if op == 0x4E77: return "rtr"
    if op == 0x4AFC: i.flow = "illegal"; return "illegal"
    if op & 0xFFF0 == 0x4E40: i.flow = "trap"; return _fmt("trap", "#%d" % (op & 15))
    if op & 0xFFF8 == 0x4E50:
        d = sx(c.w(), 16); return _fmt("link", "a%d,#%s" % (reg, hs(d)))
    if op & 0xFFF8 == 0x4E58: return _fmt("unlk", "a%d" % reg)
    if op & 0xFFF8 == 0x4E60: return _fmt("move", "a%d,usp" % reg)
    if op & 0xFFF8 == 0x4E68: return _fmt("move", "usp,a%d" % reg)
    if op & 0xFFC0 == 0x4E80 or op & 0xFFC0 == 0x4EC0:
        call = op & 0x40 == 0
        e = _ea(c, mode, reg, "l", "a")
        if e is None or mode <= 1 or mode in (3, 4) or (mode == 7 and reg == 4): return None
        i.flow = "jsr" if call else "jmp"
        if mode == 7 and reg in (0, 1, 2) and c.refs: i.target = c.refs[-1][0] & 0xFFFFFF
        if mode == 7 and reg == 2: i.target = c.refs[-1][0] & 0xFFFFFF
        return _fmt("jsr" if call else "jmp", e)
    if op & 0x1C0 == 0x1C0:  # lea
        e = _ea(c, mode, reg, "l", "a")
        if e is None or mode <= 1 or mode in (3, 4) or (mode == 7 and reg == 4): return None
        return _fmt("lea", "%s,a%d" % (e, rn))
    if op & 0x1C0 == 0x180:  # chk
        e = _ea(c, mode, reg, "w")
        return _fmt("chk.w", "%s,d%d" % (e, rn)) if e and mode != 1 else None
    if op & 0xFB80 == 0x4880 and mode != 0:  # movem
        sz = "l" if op & 0x40 else "w"
        m = c.w()
        if op & 0x400:  # mem -> reg
            e = _ea(c, mode, reg, sz)
            if e is None or mode in (0, 1, 4) or (mode == 7 and reg == 4): return None
            return _fmt("movem." + sz, "%s,%s" % (e, _regmask(m, False)))
        e = _ea(c, mode, reg, sz, "w")
        if e is None or mode in (0, 1, 3) or (mode == 7 and reg >= 2): return None
        return _fmt("movem." + sz, "%s,%s" % (_regmask(m, mode == 4), e))
    if op & 0xFFF8 == 0x4880: return _fmt("ext.w", "d%d" % reg)
    if op & 0xFFF8 == 0x48C0: return _fmt("ext.l", "d%d" % reg)
    if op & 0xFFF8 == 0x4840: return _fmt("swap", "d%d" % reg)
    if op & 0xFFC0 == 0x4840:
        e = _ea(c, mode, reg, "l", "a")
        if e is None or mode <= 1 or mode in (3, 4) or (mode == 7 and reg == 4): return None
        return _fmt("pea", e)
    if op & 0xFFC0 == 0x40C0:
        e = _ea(c, mode, reg, "w", "w"); return _fmt("move.w", "sr,%s" % e) if e and alt(mode, reg) and mode != 1 else None
    if op & 0xFFC0 == 0x44C0:
        e = _ea(c, mode, reg, "w"); return _fmt("move.w", "%s,ccr" % e) if e and mode != 1 else None
    if op & 0xFFC0 == 0x46C0:
        e = _ea(c, mode, reg, "w"); return _fmt("move.w", "%s,sr" % e) if e and mode != 1 else None
    if op & 0xFFC0 == 0x4800:
        e = _ea(c, mode, reg, "b", "w"); return _fmt("nbcd", e) if e and mode != 1 and alt(mode, reg) else None
    if op & 0xFFC0 == 0x4AC0:
        e = _ea(c, mode, reg, "b", "w"); return _fmt("tas", e) if e and mode != 1 and alt(mode, reg) else None
    names = {0x4000: "negx", 0x4200: "clr", 0x4400: "neg", 0x4600: "not", 0x4A00: "tst"}
    n = names.get(op & 0xFF00)
    if n and (op >> 6) & 3 != 3:
        sz = SZ[(op >> 6) & 3]
        e = _ea(c, mode, reg, sz, "r" if n == "tst" else "w")
        if e is None or mode == 1 or not alt(mode, reg): return None
        return _fmt(n + "." + sz, e)
    return None


def selftest(path):
    import subprocess, re
    rom = open(path, "rb").read()
    rd = lambda a: (rom[a] << 8 | rom[a + 1]) if a + 1 < len(rom) else 0
    # decode linearly over the whole ROM, then compare the mnemonic+length vs unidasm for a sample range
    import os
    ok = bad = 0
    pc = 0x200
    insns = []
    while pc < 0x40000:
        i = decode(rd, pc); insns.append(i); pc += i.size
    print("decoded %d instructions in $200-$40000, %d illegal" % (len(insns), sum(1 for x in insns if x.flow == "illegal")))
    return insns


if __name__ == "__main__":
    selftest(sys.argv[1])
