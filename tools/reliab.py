#!/usr/bin/env python3 -I
"""Exact health distribution of a part after purchase (health 15) under the wear + shared mechanic roll.
Per race: h -> max(0,h-wear); then with prob p: min(15,h+1), else h-1 if h>0.  A part at health 0 at race start counts as 'at risk'."""
import sys
P=[1/2,3/4,7/8,15/16,31/32,63/64,127/128]
W=dict(engine=2,oil=3,tire=4,brake=1,muffler=1)
def dist(w,p,n):
    d=[0.0]*16; d[15]=1.0; out=[]
    for _ in range(n):
        out.append(d)
        nd=[0.0]*16
        for h,pr in enumerate(d):
            if pr==0: continue
            x=max(0,h-w)
            nd[min(15,x+1)]+=pr*p
            nd[x-1 if x>0 else 0]+=pr*(1-p)
        d=nd
    return out
if __name__=="__main__":
    for part,w in W.items():
        print(f"== {part} (wear {w}): P(health>=1 at the start of race n after a buy), n=1.. ; last n with P>=99% / 95%")
        for mt,p in enumerate(P[:4]):
            ds=dist(w,p,40)
            ok=[sum(d[1:]) for d in ds]
            n99=max([i+1 for i,v in enumerate(ok) if v>=0.99]+[0]); n95=max([i+1 for i,v in enumerate(ok) if v>=0.95]+[0])
            mean=[sum(h*x for h,x in enumerate(d)) for d in ds]
            print(f"  mechanic {mt} (p={p:.3f}): safe races 99%={n99} 95%={n95}   P(h>=1) n=1..8: "+" ".join(f"{v:.3f}" for v in ok[:8])+"   mean h: "+" ".join(f"{m:.1f}" for m in mean[:8]))
