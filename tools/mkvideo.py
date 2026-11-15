#!/usr/bin/env python3
"""Overlay turn numbers / speed / lateral bar on the snapshots written by autolap2.lua (SHO_SNAP=n) and encode an mp4.
Usage: tools/mkvideo.py LOG TAG OUT.mp4 FPS   (LOG = the run's stdout with TURN/REC lines; frames in out/rec/TAG_%05d.png)"""
import sys, re, os, subprocess
from multiprocessing import Pool
from PIL import Image, ImageDraw, ImageFont
log, tag, out, fps = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
turns, recs = {}, []
for ln in open(log):
    m = re.match(r'\S+ TURN (\d+) start=(\d+) len=(\d+) dir=(\w) r=(\d+)', ln)
    if m: turns[int(m[1])] = (int(m[2]), int(m[3]), m[4], int(m[5]))
    m = re.match(r'REC (.*)', ln)
    if m: recs.append(list(map(int, m[1].split())))
S = 3
def font(sz):
    for p in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
F1, F2 = font(34), font(22)
tmp = os.path.join(root, 'out', 'vid'); os.makedirs(tmp, exist_ok=True)
def render(i):
    k, d, tn, st, r, lat, v, skid, ntn, dn = recs[i]
    im = Image.open(f'{root}/out/rec/{tag}_{k:05d}.png').convert('RGB').resize((320*S, 224*S), Image.NEAREST)
    base = Image.new('RGB', (320*S, 224*S + 84), (0, 0, 0)); base.paste(im, (0, 0)); im = base
    dr = ImageDraw.Draw(im, 'RGBA'); Y = 224*S
    if tn:
        t = turns[tn]
        dr.text((12, Y+4), f'TURN {tn}  ({"RIGHT" if t[2]=="R" else "LEFT"}, r={t[3]})', font=F1, fill=(255, 220, 60))
    else:
        dr.text((12, Y+4), f'straight  -  next: TURN {ntn} in {dn} u', font=F1, fill=(160, 220, 255))
    kmh = v * 279 // 240
    dr.text((12, Y+48), f'{kmh} km/h   t={k/60:5.1f}s   d={d}', font=F2, fill=(255, 255, 255))
    if skid: dr.text((700, Y+4), 'SKID', font=F1, fill=(255, 60, 60))
    elif abs(lat) > 270: dr.text((640, Y+4), 'OFF-ROAD', font=F1, fill=(255, 150, 40))
    # lateral bar: +lat = left side
    bx0, bx1, by = 560, 940, Y+56
    dr.rectangle((bx0, by-8, bx1, by+8), fill=(60, 60, 60, 220))
    for edge in (-270, 270):
        x = bx0 + (bx1-bx0) * (300 - edge) / 600
        dr.line((x, by-12, x, by+12), fill=(255, 60, 60), width=3)
    x = bx0 + (bx1-bx0) * (300 - max(-330, min(330, lat))) / 600
    dr.ellipse((x-7, by-7, x+7, by+7), fill=(80, 255, 120))
    im.save(f'{tmp}/f_{i:05d}.png')
if __name__ == '__main__':
    for f in os.listdir(tmp):
        if f.startswith('f_') and f.endswith('.png'): os.remove(os.path.join(tmp, f))
    with Pool(6) as p: p.map(render, range(len(recs)), chunksize=50)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps), '-i', f'{tmp}/f_%05d.png', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', out], check=True)
    print('wrote', out, len(recs), 'frames')
