#!/usr/bin/env python3 -I
"""Contact sheet: tools/sheet.py out.png in1.png in2.png ... [--cols N] [--scale S]"""
import sys
from PIL import Image, ImageDraw
a = sys.argv[1:]
cols, scale = 3, 1
if "--cols" in a: i = a.index("--cols"); cols = int(a[i+1]); del a[i:i+2]
if "--scale" in a: i = a.index("--scale"); scale = float(a[i+1]); del a[i:i+2]
out, files = a[0], a[1:]
ims = [Image.open(f).convert("RGB") for f in files]
w = max(i.width for i in ims); h = max(i.height for i in ims)
w2, h2 = int(w*scale), int(h*scale)
rows = (len(ims)+cols-1)//cols
S = Image.new("RGB", (cols*w2, rows*(h2+12)), (40, 40, 40))
d = ImageDraw.Draw(S)
for n, (f, im) in enumerate(zip(files, ims)):
    x, y = (n % cols)*w2, (n//cols)*(h2+12)
    S.paste(im.resize((w2, h2), Image.NEAREST), (x, y+12))
    d.text((x+2, y), f.split("/")[-1][:40], fill=(255, 255, 0))
S.save(out)
