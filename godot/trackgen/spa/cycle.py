import json,math,sys
sys.setrecursionlimit(10000)
d=json.load(open('spa.json')); nodes={e['id']:(e['lat'],e['lon']) for e in d['elements'] if e['type']=='node'}
ways=[e for e in d['elements'] if e['type']=='way']
skip={'Kart','Pit Lane','Support Pit Lane','Moto layout'}
def dist(a,b):
    la=math.radians((nodes[a][0]+nodes[b][0])/2); return math.hypot((nodes[a][1]-nodes[b][1])*111320*math.cos(la),(nodes[a][0]-nodes[b][0])*110540)
adj={}; wayof={}
for w in ways:
    n=w.get('tags',{}).get('name')
    if n in skip or w.get('tags',{}).get('sport')=='karting': continue
    ns=w['nodes']; both=w.get('tags',{}).get('oneway')!='yes'
    for a,b in zip(ns,ns[1:]):
        adj.setdefault(a,[]).append(b); wayof[(a,b)]=n
        if both: adj.setdefault(b,[]).append(a); wayof[(b,a)]=n
kem=[w for w in ways if w.get('tags',{}).get('name')=='Kemmel'][0]['nodes']
start=kem[0]; best=[]
def dfs(u,path,L,seen):
    if L>7600: return
    for v in adj.get(u,[]):
        if v==start and L>1000: best.append((L+dist(u,v),path[:])); continue
        if v in seen: continue
        seen.add(v); path.append(v); dfs(v,path,L+dist(u,v),seen); path.pop(); seen.discard(v)
dfs(start,[start],0,{start})
best.sort(key=lambda c:abs(c[0]-7004))
for L,p in best[:6]:
    names=[]
    for a,b in zip(p,p[1:]):
        n=wayof.get((a,b))
        if n and (not names or names[-1]!=n): names.append(n)
    print(round(L),len(p),names)
json.dump([nodes[n] for n in best[0][1]],open('loop.json','w'))
