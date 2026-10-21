#!/usr/bin/env python3 -I
"""Build out/hazards/index.html: per-track map of the crash hazards (static roadside objects) of the 7 Original-mode tracks,
with sprite crops taken by scripts/photo.lua (out/photo2/).  Usage: python3 -I tools/hazard_report.py   (from the repo root)"""
import glob, html, importlib.util, os, re, shutil
from PIL import Image

ROOT = os.getcwd()
spec = importlib.util.spec_from_file_location("rs", os.path.join(ROOT, "tools/roadside.py"))
rs = importlib.util.module_from_spec(spec); spec.loader.exec_module(rs)

OUT = os.path.join(ROOT, "out/hazards"); IMG = OUT + "/img"
shutil.rmtree(OUT, ignore_errors=True); os.makedirs(IMG)

# rival index -> (name, sponsor-free track description, laps, stream address read from the emulator at race start)
TRACKS = [
    (0, "MIA FERRARU", 2, 0x56168, "beach road, palms (course 3)"),
    (1, "JOSE ALVEREZ", 2, 0x56C9E, "desert, cactus (course 2)"),
    (2, "NOBUHIKO HASEGAWA", 3, 0x5707C, "daytime city (course 1)"),
    (3, "FELICA PEREZ", 3, 0x554D8, "sea-side road (course 3)"),
    (4, "HANS BRAUN", 4, 0x55F1E, "desert with trees (course 3)"),
    (5, "MARIE LEFOURE", 5, 0x5573E, "night city (course 3)"),
    (6, "KING ARTHUR", 6, 0x55D36, "evening plains (course 2)"),
]
NAMES = {14: "chevron sign (left)", 15: "chevron sign (right)", 19: "fir tree", 20: "'Soroban' billboard", 21: "leafy tree",
         22: "oil drum", 23: "curve mirror post", 24: "tall cactus", 25: "gold lamp post", 26: "white pole (right side)",
         27: "white pole (left side)", 28: "'Genesis' billboard", 29: "dead tree", 30: "'Disco Nova' billboard",
         31: "'Bird Bird' billboard", 32: "'NOK Spark Plugs' billboard", 34: "tall palm", 35: "round cactus",
         36: "phone booth", 37: "boulder", 38: "palm tree"}
ROAD = 270          # approx. half width of the asphalt in object "lat" units (measured from screenshots)
OUTER, INNER = 224 / 0x71, 224 / 0xBF   # a crash is tested from depth $71 on; lat reach = halfwidth * 224 / depth

# ---- best screenshot per (subtype, attr) -------------------------------------------------------------------------------
best = {}
for lf in sorted(glob.glob(ROOT + "/out/photo2/log_r*.txt")):
    last = {}
    for l in open(lf):
        m = re.search(r"PHOTO (\S+) sub=(\d+) attr=(\w+) x=(\d+) y=(\d+) z=(\w+)", l)
        if m: last[m.group(1)] = (int(m.group(2)), int(m.group(3), 16), int(m.group(4)), int(m.group(5)), int(m.group(6), 16))
    for f, (sub, attr, x, y, z) in last.items():
        k = (sub, attr)
        if k not in best or best[k][3] < z: best[k] = (f, x, y, z)

def crop(sub, attr):
    k = (sub, attr)
    if k not in best:
        c = [v for (s, a), v in best.items() if s == sub]
        if not c: return None
        k = [kk for kk in best if kk[0] == sub][0]
    f, x, y, z = best[k]
    name = "sub%d_%04X.png" % k
    path = IMG + "/" + name
    if not os.path.exists(path):
        im = Image.open(ROOT + "/out/" + f).convert("RGB")
        box = (max(0, x - 50), max(0, y - 100), min(320, x + 50), min(224, y + 10))
        im.crop(box).resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2), Image.NEAREST).save(path)
    return "img/" + name

PALETTE = ["#e6194b", "#3cb44b", "#4363d8", "#f58231", "#911eb4", "#42d4f4", "#f032e6", "#bfef45", "#fabed4", "#469990",
           "#dcbeff", "#9a6324", "#fffac8", "#800000", "#aaffc3", "#808000", "#ffd8b1", "#000075", "#a9a9a9", "#e6beff"]
col = {s: PALETTE[i % len(PALETTE)] for i, s in enumerate(sorted(NAMES))}

W, H, X0, Y0 = 1000, 340, 40, 10
sx = lambda d: X0 + d * (W - X0 - 10) / 2048
sy = lambda lat: Y0 + (1000 - lat) * (H - 2 * Y0) / 2000

def svg_track(objs):
    s = ['<svg viewBox="0 0 %d %d" class="chart" role="img">' % (W, H)]
    s.append('<rect x="%d" y="%.1f" width="%d" height="%.1f" class="road"/>' % (X0, sy(ROAD), W - X0 - 10, sy(-ROAD) - sy(ROAD)))
    s.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="mid"/>' % (X0, W - 10, sy(0), sy(0)))
    for lat in (-1000, -500, 500, 1000):
        s.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" class="grid"/><text x="2" y="%.1f" class="ax">%d</text>' % (X0, W - 10, sy(lat), sy(lat), sy(lat) + 4, lat))
    for d in range(0, 2049, 256):
        s.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" class="grid"/><text x="%.1f" y="%d" class="ax">%d</text>' % (sx(d), sx(d), Y0, H - Y0, sx(d) - 8, H - 1, d))
    for d, sub, lat, attr, idx in objs:
        w = rs.halfwidth(sub) or 0
        c = col.get(sub, "#fff")
        for k, op in ((OUTER, .25), (INNER, .9)):
            r = w * k
            s.append('<rect x="%.1f" y="%.1f" width="2.2" height="%.1f" fill="%s" opacity="%.2f"><title>dist %d: %s, lat %d, half-width %d -> crash if you are within %d..%d lat of it</title></rect>'
                     % (sx(d) - 1.1, sy(lat + r), max(1.5, sy(lat - r) - sy(lat + r)), c, op, d, NAMES.get(sub, sub), lat, w, int(r), int(OUTER * w)))
    s.append('<text x="%d" y="%d" class="ax">lap distance &#8594;</text></svg>' % (W - 110, Y0 + 8))
    return "".join(s)

sections = []
summary_rows = []
for r, name, laps, addr, scene in TRACKS:
    objs = rs.expand(addr)
    by = {}
    for d, sub, lat, attr, idx in objs: by.setdefault(sub, []).append((d, lat, attr))
    rows = []
    for sub in sorted(by):
        l = by[sub]; w = rs.halfwidth(sub)
        lats = sorted({a for _, a, _ in l})
        inner_gap = min(abs(a) - w * INNER for a in lats); outer_gap = min(abs(a) - w * OUTER for a in lats)
        img = crop(sub, l[0][2])
        rows.append("<tr><td>%s</td><td>%d</td><td>%s</td><td>%d</td><td>%s</td><td>%d</td><td>%+d / %+d</td></tr>" % (
            ('<img src="%s" height="90">' % img) if img else "", sub, html.escape(NAMES.get(sub, "?")), len(l),
            ", ".join(map(str, lats)), w, outer_gap - ROAD, inner_gap - ROAD))
    sections.append("""<section id="r%d"><h2>%s &middot; %d laps <small>(rival %d, %s &mdash; %d objects per lap)</small></h2>
%s
<table><tr><th></th><th>type</th><th>object</th><th>count/lap</th><th>lat positions</th><th>crash half-width</th><th>room beyond road edge<br>(first-test / contact)</th></tr>%s</table></section>"""
                    % (r, name, laps, r, scene, len(objs), svg_track(objs), "".join(rows)))
    summary_rows.append("<tr><td><a href='#r%d'>%s</a></td><td>%s</td><td>%d</td><td>%s</td></tr>" % (r, name, scene, len(objs), ", ".join("%d&times;%s" % (len(v), NAMES[k]) for k, v in sorted(by.items(), key=lambda kv: -len(kv[1]))[:4])))

legend = "".join('<span class="lg"><i style="background:%s"></i>%d %s</span>' % (col[s], s, NAMES[s]) for s in sorted(NAMES) if any(s == o[1] for _, _, _, a, _ in TRACKS for o in rs.expand(a)))
bots = [(0, [0xd2, 0xcd, 0xc8, 0xbe, 0xb4, 0xaa, 0xa5, 0xa5, 0xa5]), ]
HTML = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Super Hang-On hazards</title><style>
:root{--bg:#14161a;--fg:#e8e8e8;--mut:#9aa0a6;--card:#1d2026;--road:#3a3f47;--line:#2c3038}
@media (prefers-color-scheme: light){:root{--bg:#fafafa;--fg:#1b1b1b;--mut:#5f6368;--card:#fff;--road:#cfd3d9;--line:#dadde1}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif}
main{max-width:1060px;margin:auto;padding:16px}
h1{margin:.4em 0}h2{margin-top:1.6em;border-bottom:1px solid var(--line);padding-bottom:.2em}small{color:var(--mut);font-weight:400}
section,.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 14px;margin:16px 0}
.chart{width:100%;height:auto;background:transparent}.road{fill:var(--road);opacity:.55}.mid{stroke:var(--mut);stroke-dasharray:6 6;stroke-width:1}
.grid{stroke:var(--line);stroke-width:1}.ax{fill:var(--mut);font:10px sans-serif}
table{border-collapse:collapse;width:100%;margin:8px 0;font-size:13px}th,td{border-bottom:1px solid var(--line);padding:4px 8px;text-align:left;vertical-align:middle}th{color:var(--mut);font-weight:500}
.lg{display:inline-block;margin:2px 10px 2px 0;font-size:12px}.lg i{display:inline-block;width:10px;height:10px;margin-right:4px;border-radius:2px}
img{image-rendering:pixelated;border-radius:4px}.tbl{overflow-x:auto}code{background:var(--line);padding:0 4px;border-radius:3px}
.heavy{color:#ff6b6b}.light{color:#ffb454}
</style></head><body><main>
<h1>Super Hang-On &mdash; Original-mode hazards</h1>
<p>Everything on this page is read from the ROM (object streams, collision tables) and confirmed with the emulator; the screenshots were taken by <code>scripts/photo.lua</code>.</p>
<div class="card"><h3>Two kinds of hit</h3>
<table><tr><th>kind</th><th>what</th><th>damage</th><th>how it was verified</th></tr>
<tr><td class="heavy"><b>Heavy</b></td><td>any <b>static roadside object</b> (signs, trees, poles, billboards, rocks&hellip;; object type <code>$34</code>, handler <code>$C7BE</code>) when your bike is within its crash half-width. You fall, and the damage is applied when the fall animation ends (~3.5 s later).</td>
<td>frame &minus;3, engine &minus;1, brake &minus;2, muffler &minus;2 (code <code>$AC3A</code>). A fall also resets your speed. If frame, engine or tire is then below 0 the race is retired.</td>
<td>Emulator: 5 crashes in a row each logged <code>$C7F8</code> (tree, billboard, billboard, tree, tree) then <code>$AC3A</code> with exactly this damage.</td></tr>
<tr><td class="light"><b>Light</b></td><td>a <b>backmarker bike</b> (object type <code>$48</code>, handler <code>$D482</code>, 5 slots). Not a crash: you are shoved sideways and keep riding.</td>
<td>frame &minus;1, muffler &minus;1, once per contact (code <code>$D53A</code>). If the frame was already 0 it drops to &minus;1: that triggers a crash and a retirement.</td>
<td>Emulator: steering into bots twice gave 15&rarr;14 on both frame and muffler, nothing else.</td></tr></table>
<p>So your memory was right about "bots &minus;1 frame, signs/trees &minus;3 frame", with two additions: bots also cost a muffler point and signs/trees also cost engine, brake and muffler points. <b>Nothing static stands on the asphalt</b>: every object in every track is at |lat| &ge; 350 and the road half-width is about 270 (estimated from screenshots), so you only hit scenery by leaving the road.</p></div>
<div class="card"><h3>Tracks</h3><div class="tbl"><table><tr><th>track (Original-mode rival)</th><th>scenery</th><th>objects / lap</th><th>most common</th></tr>@@SUMMARY@@</table></div></div>
<div class="card"><h3>How to read the charts</h3>
<p>x = distance along the lap (0&ndash;2047; every lap of a race repeats the same objects), y = lateral position of the object (0 = road centre, the grey band is the road &plusmn;270). Each object is a vertical bar: the <b>solid</b> part is the lateral range in which you hit it when it reaches you (&asymp; 1.17 &times; its crash half-width), the <b>faint</b> part is the reach at the first frame the game tests (depth $71, &asymp; 1.98 &times; the half-width: the test runs every frame once the object is past depth $71, so objects are hit slightly early). Hover for details.</p>
<p>The last table column is the room you have beyond the road edge (270): a positive number means you can drive that far off the asphalt before that object can hit you; negative = the object reaches onto the road.</p>
<p>@@LEGEND@@</p></div>
@@SECTIONS@@
<div class="card"><h3>Bots (light hazard) &mdash; not fixed per track</h3>
<ul><li>Spawning is <b>random</b> (the game's LCG): a countdown reloaded with 100 + 48&middot;(rnd&amp;3) ticks, a new bike appears when fewer than <i>N</i> bots are active and your speed is above $64. <i>N</i> in Original mode by lap 1&hellip;9 = 2,3,3,3,3,4,4,4,5 (table <code>$4930</code>, row 0).</li>
<li>Their speed is <b>fixed per lap</b> (table <code>$D42A</code>, row 0): $D2, $CD, $C8, $BE, $B4, $AA, $A5, $A5, $A5 for laps 1&hellip;9 (210&rarr;165). Relative to you they move at (your speed &minus; theirs).</li>
<li>Lane / target position comes from a second per-track stream (<code>$FF0672</code>, "traffic" state 1&ndash;3 at given distances) combined with random wobble; bot model (width $10/$10/$16/$1C) is chosen from a random value at spawn.</li>
<li>Bot spawning / lane code is read from the disassembly; only the damage and the "bots are objects of type $48" part was run in the emulator.</li></ul></div>
</main></body></html>"""
open(OUT + "/index.html", "w").write(HTML.replace("@@SUMMARY@@", "".join(summary_rows)).replace("@@SECTIONS@@", "".join(sections)).replace("@@LEGEND@@", legend))
print("wrote", OUT + "/index.html")
