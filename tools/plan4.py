#!/usr/bin/env python3 -I
"""Original-mode speedrun planner v4 (win every race, no crashes).  Builds on runplan.py's speed model.
New vs plan3: safe margins from the exact health model (tools/reliab.py), shop-visit time cost, frame requirement,
optional muffler, per-rival tire requirement, per-rival engine caps, tie-break on money.
Parts: E engine, O oil, F muffler, M mechanic, T tire, B brake (tier 0 only), R frame (only a one-off requirement)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from runplan import lap_times, EP, OP, MP, MECH, MP_, WIN, LAPS, TP, BP
RACES=[r for r in range(7) for _ in range(5)]
WEARS=dict(e=2,o=3,t=4,b=1,f=1)
FR=[1200,2000,8000,128000]   # frame tier 0..3 prices

def plan4(tire_req=(0,0,3,3,3,3,3), frame_req=(0,0,2,2,2,2,2), margins=(6,5,5,6,4), mechs=(0,1,2,3), engines=(0,1,3,4),
          oils=(0,1), tires=(0,3,4), mufs=(0,1), visit=5.0, visit_from=4, buyonly=False, max_pareto=2, engine_cap=None, quiet=True, max_keep=60, engine_req=None):
    me,mo_,mt,mb,mf_=margins
    S={(0,0,0,0,0,0,15,15,15,15,15):[(0.0,0,())]}      # e,o,mc,t,f(frame tier),mf, he,ho,ht,hb,hm
    def opt(tier,h,pr,al,need,m):
        out=[]
        if h>=m and tier>=need: out.append((tier,h,0,False))
        for x in range(tier,len(pr)):
            if x in al and x>=need and (x>tier or h<m): out.append((x,15,pr[x],True))
        return out
    for i,r in enumerate(RACES):
        N={}
        nt=tire_req[r]; nf=frame_req[r]
        for (e,o,mc,t,f,mf,he,ho,ht,hb,hm),lst in S.items():
            ealw=[x for x in engines if engine_cap is None or x<=engine_cap[r] or x<e]
            eo=opt(e,he,EP,ealw,(engine_req[i] if engine_req else 0),me); oo=opt(o,ho,OP,oils,0,mo_); to=opt(t,ht,TP,tires,nt,mt)
            bo=opt(0,hb,BP,(0,),0,mb)
            # muffler: lapse to tier 0 allowed when stale
            fo=[]
            if mf==0: fo.append((0,15,0,False))
            elif hm>=mf_: fo.append((mf,hm,0,False))
            else: fo.append((0,15,0,False))
            for x in mufs:
                if x>=1 and (x>mf or (x==mf and hm<mf_)): fo.append((x,15,MP[x],True))
            if mf==0:
                for x in mufs:
                    if x>=1: fo.append((x,15,MP[x],True))
            fro=[(f,0,False)] if f>=nf else []
            if f<2: fro.append((2,FR[2],True))
            mo2=[(mc,0,False)]+[(k,MECH[k],True) for k in range(mc+1,7) if k in mechs]
            for (tm,mon,hist) in lst:
              for (ne,nhe,ce,be) in eo:
                for (no,nho,co,bo_) in oo:
                  c0=ce+co
                  if c0>mon: continue
                  for (nt_,nht,ct,bt) in to:
                    c1=c0+ct
                    if c1>mon: continue
                    for (nb,nhb,cb,bk) in bo:
                      c2=c1+cb
                      if c2>mon: continue
                      for (nf2,nhm,cf,bf) in fo:
                        c3=c2+cf
                        if c3>mon: continue
                        for (nfr,cfr,bfr) in fro:
                          c4=c3+cfr
                          if c4>mon: continue
                          for (nm,cm,bm) in mo2:
                            cost=c4+cm
                            if cost>mon: continue
                            flags=(be,bo_,bf,bm,bt,bk,bfr)
                            anybuy=any(flags)
                            tt=tm+lap_times(ne,no,nf2)[LAPS[r]-1]
                            if anybuy and (buyonly or i<visit_from): tt+=visit
                            buys=tuple(f"{n}{v}" for n,v,fl in zip("EOFMTBR",(ne,no,nf2,nm,nt_,nb,nfr if nfr else 0),flags) if fl) if anybuy else ()
                            d=2*MP_[nm]-1
                            w=lambda h,x: max(0,min(15,round(h-x+d)))
                            nf_tier=2 if (f>=2 or bfr) else 0
                            key=(ne,no,nm,nt_,nf_tier,nf2,w(nhe,2),w(nho,3),w(nht,4),w(nhb,1),w(nhm,1) if nf2 else 15)
                            N.setdefault(key,[]).append((tt,mon-cost+WIN[r],hist+((i,buys),) if buys else hist))
        # dominance prune: same tiers, health >= in every part, time <=, money >=
        G={}
        for k,lst in N.items():
            G.setdefault(k[:6],[]).extend((k[6:],x[0],x[1],x[2]) for x in lst)
        S={}
        for tiers,lst in G.items():
            lst.sort(key=lambda z:(z[1],-z[2],[-h for h in z[0]]))
            keep=[]
            for hh,tm,mo,hist in lst:
                dom=False
                for h2,t2,m2,_ in keep:
                    if m2>=mo and all(a>=b for a,b in zip(h2,hh)): dom=True; break
                if not dom:
                    keep.append((hh,tm,mo,hist))
                    if len(keep)>=max_keep: break
            for hh,tm,mo,hist in keep:
                S.setdefault(tiers+hh,[]).append((tm,mo,hist))
        if not quiet: print("race",i+1,"states",len(S),file=sys.stderr,flush=True)
    return min((x for lst in S.values() for x in lst), key=lambda x:(x[0],-x[1]))

def replay(hist,visit=5.0,visit_from=4,buyonly=False):
    """per-race table from the buy list"""
    b={i:bs for i,bs in hist}
    e=o=mc=t=f=mf=0; money=0; rows=[]
    for i,r in enumerate(RACES):
        bs=b.get(i,())
        cost=0
        for x in bs:
            k,v=x[0],int(x[1:])
            if k=="E": cost+=EP[v]; e=v
            elif k=="O": cost+=OP[v]; o=v
            elif k=="F": cost+=MP[v]; mf=v
            elif k=="M": cost+=MECH[v]; mc=v
            elif k=="T": cost+=TP[v]; t=v
            elif k=="B": cost+=BP[v]
            elif k=="R": cost+=FR[2]; f=2
        tm=lap_times(e,o,mf)[LAPS[r]-1]+(visit if bs and (buyonly or i<visit_from) else 0)
        money+=-cost+WIN[r]
        rows.append((i+1,r,bs,e,o,mf,mc,t,tm,money))
    return rows

def show(best,label,**kw):
    tm,mo,hist=best
    print(f"## {label}\ntotal {tm/60:.2f} min ({tm:.0f} s) incl. extra shop visits, money left ${mo:,}")
    for i,b in hist: print(f"   before race {i+1:2d} (rival {i//5}, win #{i%5+1}): buy {', '.join(b)}")
    rows=replay(hist,**kw)
    print("   per rival: time (s) / money after the stage")
    for r in range(7):
        rr=[x for x in rows if x[1]==r]
        print(f"     rival {r}: {sum(x[8] for x in rr):7.1f} s   engines {[x[3] for x in rr]} oil {[x[4] for x in rr]} tires {[x[7] for x in rr]}  money ${rr[-1][9]:,}")

if __name__=="__main__":
    import time, json
    t0=time.time()
    kw=json.loads(sys.argv[2]) if len(sys.argv)>2 else {}
    for k in ("tire_req","frame_req","margins","mechs","engines","oils","tires","mufs","engine_req"):
        if k in kw: kw[k]=tuple(kw[k])
    if "engine_cap" in kw: kw["engine_cap"]=tuple(kw["engine_cap"])
    rk={k:kw[k] for k in ("visit","visit_from","buyonly") if k in kw}
    best=plan4(quiet=False,**kw)
    show(best,sys.argv[1],**rk); print("%.0fs"%(time.time()-t0))
