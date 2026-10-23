import random,json
from pathlib import Path
base=[[(0,0),(4,0),(2,2)]]*2+[[(0,0),(2,0),(0,2)]]+[[(0,0),(2,0),(1,1)]]*2+[[(1,0),(2,1),(1,2),(0,1)],[(1,0),(1,2),(0,3),(0,1)]]
def poly(i,r,f,x=0,y=0):
 p=base[i]
 if f:p=[(-a,b) for a,b in p]
 for _ in range(r):p=[(-b,a) for a,b in p]
 mx=min(a for a,b in p);my=min(b for a,b in p)
 return [(a-mx+x,b-my+y) for a,b in p]
def inside(p,x,y):
 signs=[(b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]) for a,b in zip(p,p[1:]+p[:1])]
 return min(signs)>-1e-8 or max(signs)<1e-8
def cover(p):
 return frozenset((y*7+x)*4+k for y in range(7) for x in range(7) for k,(dx,dy) in enumerate([(.5,1/6),(5/6,.5),(.5,5/6),(1/6,.5)]) if inside(p,x+dx,y+dy))
placements=[]
for i in range(7):
 a=[];seen=set()
 for f in range(2 if i==6 else 1):
  for r in range(4):
   p=poly(i,r,f);w=max(x for x,y in p);h=max(y for x,y in p)
   for y in range(8-h):
    for x in range(8-w):
     q=poly(i,r,f,x,y);c=cover(q)
     if c not in seen:seen.add(c);a.append(([x,y,r,f],q,c))
 placements.append(a)
def touches(p,q):
 # Sharing at least one complete unit edge, rather than just a corner.
 def edges(poly):
  out=set()
  for a,b in zip(poly,poly[1:]+poly[:1]):
   n=max(abs(b[0]-a[0]),abs(b[1]-a[1]));dx=(b[0]-a[0])//n;dy=(b[1]-a[1])//n
   for j in range(n):out.add(tuple(sorted(((a[0]+j*dx,a[1]+j*dy),(a[0]+(j+1)*dx,a[1]+(j+1)*dy)))))
  return out
 return bool(edges(p)&edges(q))
rng=random.Random(71239);results=[];silhouettes=set()
# Grow connected, nonoverlapping silhouettes from the seven true tangram pieces.
for attempt in range(10000):
 used=set();chosen=[]
 for i in range(7):
  options=[a for a in placements[i] if not used.intersection(a[2]) and (not chosen or any(touches(a[1],b[1]) for b in chosen))]
  if not options:break
  # compact enough for a phone and less likely to create isolated holes
  rng.shuffle(options)
  best=min(options[:40],key=lambda a:(max([v[0] for b in chosen+[a] for v in b[1]])-min([v[0] for b in chosen+[a] for v in b[1]]))*(max([v[1] for b in chosen+[a] for v in b[1]])-min([v[1] for b in chosen+[a] for v in b[1]]))+rng.random()*15)
  chosen.append(best);used.update(best[2])
 if len(chosen)!=7:continue
 minx=min(x for a in chosen for x,y in a[1]);miny=min(y for a in chosen for x,y in a[1]);maxx=max(x for a in chosen for x,y in a[1]);maxy=max(y for a in chosen for x,y in a[1])
 dx=(7-(maxx-minx))//2-minx;dy=(7-(maxy-miny))//2-miny
 vals=[[a[0][0]+dx,a[0][1]+dy,*a[0][2:]] for a in chosen]
 cov=frozenset(v for i,a in enumerate(vals) for v in cover(poly(i,a[2],a[3],a[0],a[1])))
 if cov in silhouettes:continue
 silhouettes.add(cov);results.append(vals)
 if len(results)==24:break
assert len(results)==24
text='import Foundation\n\n// Fixed, connected silhouettes; seven standard pieces, exact quarter-cell coverage.\nenum TangramLayouts {\n    static let all: [[[Int]]] = '+json.dumps(results)+'\n}\n'
(Path(__file__).resolve().parent.parent/'Core/TangramLayouts.swift').write_text(text)
print('Generated',len(results),'unique seven-piece connected silhouettes')
