#!/usr/bin/env python3 -I
"""Original-mode speedrun planner: race-time model + purchase schedule search (win every race, no crashes).
Model (verified in the emulator, see docs/08): speed_model runs every 3rd frame (20/s at 60 Hz):
  s += mult*(279-s)/1024      mult = engine{3,4,6,6,8,8} + (oil+muffler tier)/4
  s > 240 without turbo -> pulled back to 241; turbo (C held, engine >= 3) adds {1,3,5}/call up to 279
  distance += 269*s/65536 per call; a lap is 2048 units (inside-line gain ignored: it scales every config alike)
"""
import sys, functools
EM=[3,4,6,6,8,8]; TB=[0,0,0,1,3,5]
EP=[600,2000,8000,32000,512000,8192000]; OP=[100,200,3200,14000]; MP=[300,1500,6000,90000]
MECH=[0,1000,2000,13000,34500,178000,2000000]; MP_=[1/2,3/4,7/8,15/16,31/32,63/64,127/128]
WIN=[1200,2200,10000,30000,130000,500000,2000000]; LAPS=[2,2,3,3,4,5,6]
WEAR=dict(e=2,o=3,m=1)

@functools.lru_cache(None)
def lap_times(e,o,m):
    """seconds for 1..6 laps (cumulative) at 60 fps"""
    mult=EM[e]+(o+m)/4; s=0.0; d=0.0; calls=0; out=[]
    target=2048
    while len(out)<6:
        # one speed_model call
        s+=mult*(279-s)/1024
        if s>240:
            if TB[e]: s=min(279,s+TB[e])
            else: s=min(s,241)
        d+=269*s/65536; calls+=1
        if d>=target*(len(out)+1): out.append(calls*3/60)
    return tuple(out)

if __name__=="__main__" and len(sys.argv)>1 and sys.argv[1]=="table":
    print("race time (s), 2 laps / 6 laps  and per-lap cruise")
    for e in range(6):
        for (o,m) in [(0,0),(1,0),(3,3)]:
            t=lap_times(e,o,m); print(f"engine T{e} oil T{o} muf T{m}: mult {EM[e]+(o+m)/4:5.2f}  2 laps {t[1]:6.1f}  6 laps {t[5]:6.1f}  (lap1 {t[0]:.1f}, lap6 {t[5]-t[4]:.1f})")


def plan(margin=3.0, max_pareto=3, allow_engine=(0,1,2,3,4), allow_mech=(0,1,2,3,4), allow_oil=(0,1,2)):
    """Pareto search over purchases (engine, oil, mechanic) before each of the 35 races (5 per rival, all won).
    Health is an expectation (mechanic roll = +/-1 with probability p): engine and oil need >= margin at race start.
    The muffler stays at tier 0 (its whole range is worth < 0.5 s/race once the speed is capped)."""
    races=[r for r in range(7) for _ in range(5)]
    S={(0,0,0,15.0,15.0):[(0.0,0,())]}
    for i,r in enumerate(races):
        N={}
        for (e,o,mc,he,ho),lst in S.items():
            eopts=[(e,he,0,False)]+[(t,15.0,EP[t],True) for t in range(e,6) if t in allow_engine]
            oopts=[(o,ho,0,False)]+[(t,15.0,OP[t],True) for t in range(o,4) if t in allow_oil]
            mopts=[(mc,0,False)]+[(k,MECH[k],True) for k in range(mc+1,7) if k in allow_mech]
            for (tm,mo,hist) in lst:
                for (ne,nhe,ce,be) in eopts:
                    if nhe<margin: continue
                    for (no,nho,co,bo) in oopts:
                        if nho<margin: continue
                        for (nm,cm,bm) in mopts:
                            cost=ce+co+cm
                            if cost>mo: continue
                            buys=tuple(x for x,b in (("E%d"%ne,be),("O%d"%no,bo),("M%d"%nm,bm)) if b)
                            t2=tm+lap_times(ne,no,0)[LAPS[r]-1]
                            d=2*MP_[nm]-1
                            he2=min(15.0,nhe-WEAR["e"]+d); ho2=min(15.0,nho-WEAR["o"]+d)
                            key=(ne,no,nm,round(he2*2)/2,round(ho2*2)/2)
                            N.setdefault(key,[]).append((t2,mo-cost+WIN[r],hist+((i,buys),) if buys else hist))
        # pareto prune: smaller time, larger money
        S={}
        for k,lst in N.items():
            lst.sort(key=lambda x:(x[0],-x[1]))
            keep=[];best=-1
            for x in lst:
                if x[1]>best: keep.append(x); best=x[1]
            S[k]=keep[:max_pareto]
        # global prune: drop states dominated by another state with same-or-better tier/health (cheap heuristic: none)
    best=min((x for lst in S.values() for x in lst), key=lambda x:x[0])
    return best

def show(best,label):
    tm,mo,hist=best
    print(f"{label}: total race time {tm/60:.1f} min ({tm:.0f} s), money left ${mo:,}")
    for i,b in hist: print(f"   before race {i+1:2d} (rival {i//5}, win #{i%5+1}): buy {', '.join(b)}")


TP=[300,400,1500,6000,24000]; BP=[400,1500,6000,24000,90000]
WEAR.update(t=4,b=1)

def plan2(tire_req=3, req_from=10, brake_req=0, margin=3.0, max_pareto=2, mechs=(0,1), engines=(0,1,3,4), oils=(0,1), tires=(0,3,4), brakes=(0,2)):
    """Like plan(), but tires and brakes are tracked too.
    From race index `req_from` (0-based; 10 = first race of rival 2) the tire tier must be >= tire_req and the brake tier >= brake_req;
    before that tires/brakes only need health >= margin (tier 0 is fine). Frame stays tier 0 (it never wears without crashes)."""
    races=[r for r in range(7) for _ in range(5)]
    S={(0,0,0,0,0,15.0,15.0,15.0,15.0):[(0.0,0,())]}
    names=("E","O","M","T","B")
    for i,r in enumerate(races):
        N={}
        need_t=tire_req if i>=req_from else 0; need_b=brake_req if i>=req_from else 0
        for (e,o,mc,t,b,he,ho,ht,hb),lst in S.items():
            eo=[(e,he,0,False)]+[(x,15.0,EP[x],True) for x in range(e,6) if x in engines]
            oo=[(o,ho,0,False)]+[(x,15.0,OP[x],True) for x in range(o,4) if x in oils]
            mo_=[(mc,0,False)]+[(k,MECH[k],True) for k in range(mc+1,7) if k in mechs]
            to=[(t,ht,0,False)]+[(x,15.0,TP[x],True) for x in range(t,5) if x in tires]
            bo=[(b,hb,0,False)]+[(x,15.0,BP[x],True) for x in range(b,5) if x in brakes]
            for (tm,mo,hist) in lst:
                for (ne,nhe,ce,be) in eo:
                  if nhe<margin: continue
                  for (no,nho,co,bb) in oo:
                    if nho<margin: continue
                    for (nt,nht,ct,bt) in to:
                      if nt<need_t or nht<margin: continue
                      c1=ce+co+ct
                      if c1>mo: continue
                      for (nb,nhb,cb,bbk) in bo:
                        if nb<need_b or nhb<margin: continue
                        c2=c1+cb
                        if c2>mo: continue
                        for (nm,cm,bm) in mo_:
                          cost=c2+cm
                          if cost>mo: continue
                          buys=tuple(f"{n}{v}" for n,v,f in zip(names,(ne,no,nm,nt,nb),(be,bb,bm,bt,bbk)) if f)
                          t2=tm+lap_times(ne,no,0)[LAPS[r]-1]
                          d=2*MP_[nm]-1
                          wr=lambda h,w: min(15.0,h-w+d)
                          key=(ne,no,nm,nt,nb,round(wr(nhe,2)),round(wr(nho,3)),round(wr(nht,4)),round(wr(nhb,1)))
                          N.setdefault(key,[]).append((t2,mo-cost+WIN[r],hist+((i,buys),) if buys else hist))
        S={}
        for k,lst in N.items():
            lst.sort(key=lambda x:(x[0],-x[1])); keep=[];best=-1
            for x in lst:
                if x[1]>best: keep.append(x); best=x[1]
            S[k]=keep[:max_pareto]
    return min((x for lst in S.values() for x in lst), key=lambda x:x[0])

if __name__=="__main__" and len(sys.argv)>1 and sys.argv[1]=="plan2":
    import time; t0=time.time()
    tr=int(sys.argv[2]); br=int(sys.argv[3]); rf=int(sys.argv[4]) if len(sys.argv)>4 else 10
    show(plan2(tire_req=tr,brake_req=br,req_from=rf),f"tires>={tr} brakes>={br} from race {rf+1}"); print("%.0fs"%(time.time()-t0))


def plan3(tire_req=3, req_from=10, brake_req=0, margin=3, max_pareto=2, mechs=(0,1), engines=(0,1,3,4), oils=(0,1), tires=(0,3,4), brakes=(0,2)):
    """Faster plan2: a same-tier rebuy only happens when forced (health below margin); voluntary buys are upgrades.
    Health is tracked as an integer (expected value rounded)."""
    races=[r for r in range(7) for _ in range(5)]
    S={(0,0,0,0,0,15,15,15,15):[(0.0,0,())]}
    def o2(tier,h,pr,al,need):
        out=[]
        if h>=margin and tier>=need: out.append((tier,h,0,False))
        for x in range(tier,len(pr)):
            if x in al and x>=need and (x>tier or h<margin): out.append((x,15,pr[x],True))
        return out
    for i,r in enumerate(races):
        N={}
        nt_=tire_req if i>=req_from else 0; nb_=brake_req if i>=req_from else 0
        for (e,o,mc,t,b,he,ho,ht,hb),lst in S.items():
            eo=o2(e,he,EP,engines,0); oo=o2(o,ho,OP,oils,0); to=o2(t,ht,TP,tires,nt_); bo=o2(b,hb,BP,brakes,nb_)
            mo_=[(mc,0,False)]+[(k,MECH[k],True) for k in range(mc+1,7) if k in mechs]
            for (tm,mo,hist) in lst:
              for (ne,nhe,ce,be) in eo:
                for (no,nho,co,bb) in oo:
                  c0=ce+co
                  if c0>mo: continue
                  tt=tm+lap_times(ne,no,0)[LAPS[r]-1]
                  for (nt,nht,ct,bt) in to:
                    c1=c0+ct
                    if c1>mo: continue
                    for (nb,nhb,cb,bk) in bo:
                      c2=c1+cb
                      if c2>mo: continue
                      for (nm,cm,bm) in mo_:
                        cost=c2+cm
                        if cost>mo: continue
                        buys=tuple(f"{n}{v}" for n,v,f in zip("EOMTB",(ne,no,nm,nt,nb),(be,bb,bm,bt,bk)) if f)
                        d=2*MP_[nm]-1
                        w=lambda h,x: max(0,min(15,round(h-x+d)))
                        key=(ne,no,nm,nt,nb,w(nhe,2),w(nho,3),w(nht,4),w(nhb,1))
                        N.setdefault(key,[]).append((tt,mo-cost+WIN[r],hist+((i,buys),) if buys else hist))
        S={}
        for k,lst in N.items():
            lst.sort(key=lambda x:(x[0],-x[1])); keep=[];best=-1
            for x in lst:
                if x[1]>best: keep.append(x); best=x[1]
            S[k]=keep[:max_pareto]
        print("race",i+1,"states",len(S),file=sys.stderr,flush=True)
    return min((x for lst in S.values() for x in lst), key=lambda x:x[0])

if __name__=="__main__" and len(sys.argv)>1 and sys.argv[1]=="plan3":
    import time; t0=time.time()
    tr=int(sys.argv[2]); br=int(sys.argv[3]); rf=int(sys.argv[4]) if len(sys.argv)>4 else 10
    kw={}
    for a in sys.argv[5:]:
        k,v=a.split("="); kw[k]=tuple(int(c) for c in v.split(",")) if k!="max_pareto" else int(v)
    show(plan3(tire_req=tr,brake_req=br,req_from=rf,**kw),f"tires>={tr} brakes>={br} from race {rf+1}"); print("%.0fs"%(time.time()-t0))
