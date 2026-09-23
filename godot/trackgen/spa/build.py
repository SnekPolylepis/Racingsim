import json,math
loop=json.load(open('loop.json')); E=json.load(open('ele.json'))
d=json.load(open('spa.json')); nodes={e['id']:(e['lat'],e['lon']) for e in d['elements'] if e['type']=='node'}
ways=[e for e in d['elements'] if e['type']=='way']
lat0=sum(p[0] for p in loop)/len(loop); lon0=sum(p[1] for p in loop)/len(loop)
kx=111320*math.cos(math.radians(lat0)); ky=110540
# SCALE matches the official 7.004 km lap: the OSM chord polyline runs ~0.5 % short through corners.
SCALE=7004/6970.5
P=lambda p:(( p[1]-lon0)*kx*SCALE, -(p[0]-lat0)*ky*SCALE)
# Elevation: surface models read tree canopy as terrain, so take the lower of EU-DEM and SRTM at each
# 20 m sample, a 5-sample circular median to drop spikes, then a Gaussian (sigma 3 samples = 60 m).
za=E['z']['eudem25m']; zb=E['z']['srtm30m']; z=[min(a,b) for a,b in zip(za,zb)]; n=len(z)
z=[sorted(z[(i+j)%n] for j in range(-2,3))[2] for i in range(n)]
w=[math.exp(-k*k/(2*3.0**2)) for k in range(-9,10)]
zs=[sum(w[j+9]*z[(i+j)%n] for j in range(-9,10))/sum(w) for i in range(n)]
print('raw range',min(z),max(z),'smoothed',min(zs),max(zs), 'max diff eudem-srtm',max(abs(a-b) for a,b in zip(za,zb)))
mid=(min(zs)+max(zs))/2
ep=[P(p) for p in E['pts']]
# arc positions of elevation samples
earc=[0.0]
for i in range(1,n): earc.append(earc[-1]+math.dist(ep[i-1],ep[i]))
elen=earc[-1]+math.dist(ep[-1],ep[0])
def z_at_point(x,y):
    i=min(range(n),key=lambda k:(ep[k][0]-x)**2+(ep[k][1]-y)**2)
    # interpolate with neighbour
    j=(i+1)%n; a=ep[i]; b=ep[j]; dx=b[0]-a[0]; dy=b[1]-a[1]; L2=dx*dx+dy*dy or 1
    t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/L2))
    return zs[i]+(zs[j]-zs[i])*t-mid
# outline resample 4 m
pts=[P(p) for p in loop]
ev=[pts[0]]; carry=0
for i in range(1,len(pts)+1):
    a=pts[i-1]; b=pts[i%len(pts)]; seg=math.dist(a,b); t=4-carry
    while t<=seg: ev.append((a[0]+(b[0]-a[0])*t/seg,a[1]+(b[1]-a[1])*t/seg)); t+=4
    carry=seg-(t-4)
def segd(p,a,b):
    dx=b[0]-a[0]; dy=b[1]-a[1]; L2=dx*dx+dy*dy
    if L2==0: return math.dist(p,a)
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/L2)); return math.dist(p,(a[0]+dx*t,a[1]+dy*t))
N=len(ev); keep={0,N//2}; st=[(0,N//2),(N//2,N)]
while st:
    lo,hi=st.pop(); a=ev[lo%N]; b=ev[hi%N]; best=-1; at=-1
    for i in range(lo+1,hi):
        dd=segd(ev[i%N],a,b)
        if dd>best: best=dd; at=i
    if best>0.7: keep.add(at%N); st+= [(lo,at),(at,hi)]
ki=sorted(keep); out=[]
for k in range(len(ki)):
    a=ev[ki[k]]; b=ev[ki[(k+1)%len(ki)]]; out.append(a); g=math.dist(a,b); m=int(g/32)
    for s in range(1,m+1): out.append((a[0]+(b[0]-a[0])*s/(m+1),a[1]+(b[1]-a[1])*s/(m+1)))
merged=[]
for p in out:
    if not merged or math.dist(p,merged[-1])>=5: merged.append(p)
if math.dist(merged[0],merged[-1])<5: merged.pop()
# The track spline interpolates height per segment parameter, not per metre, so uneven control-point
# spacing (5 m next to 30 m) turns into vertical kinks. Resample the 4 m outline at an even ~16 m.
cum=[0.0]
for i in range(1,len(ev)): cum.append(cum[-1]+math.dist(ev[i-1],ev[i]))
Ltot=cum[-1]+math.dist(ev[-1],ev[0]); nres=round(Ltot/16); merged=[]; j=0
for k in range(nres):
    s0=k*Ltot/nres
    while j+1<len(ev) and cum[j+1]<=s0: j+=1
    a=ev[j]; b=ev[(j+1)%len(ev)]; seglen=(cum[j+1] if j+1<len(ev) else Ltot)-cum[j]; t=(s0-cum[j])/max(seglen,1e-6)
    merged.append((a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t))
# which way is each control point on (nearest loop node)
wayname={}
for wy in ways:
    for nd in wy['nodes']: wayname.setdefault(tuple(nodes[nd]), wy.get('tags',{}).get('name'))
names=[]
for p in merged:
    ll=min(loop,key=lambda q:(P(q)[0]-p[0])**2+(P(q)[1]-p[1])**2); names.append(wayname.get(tuple(ll)))
# start straight = points between the Chicane (Bus Stop) and La Source
width=[12.0]*len(merged)
ch=[i for i,nm in enumerate(names) if nm=='Chicane']; ls=[i for i,nm in enumerate(names) if nm=='La Source']
i=ch[-1]+1
while names[i%len(merged)]!='La Source': width[i%len(merged)]=14.0; i+=1
# Vertical curvature limit: DEM noise between closely spaced control points makes kinks that the spline
# turns into crests/compressions of several g. Relax heights until every vertical radius is >= 400 m
# (0.8 g extra at 200 km/h), keeping the overall profile.
zc=[z_at_point(*p) for p in merged]; nz=len(zc)
arcs=[0.0]
for i in range(1,nz): arcs.append(arcs[-1]+math.dist(merged[i-1],merged[i]))
LL=arcs[-1]+math.dist(merged[-1],merged[0]); H=5.0; ng=int(LL/H)
def interp(s):
    s%=LL; j=max(k for k in range(nz) if arcs[k]<=s); a2=arcs[j]; b2=arcs[j+1] if j+1<nz else LL
    return zc[j]+(zc[(j+1)%nz]-zc[j])*(s-a2)/max(b2-a2,1e-6)
g=[interp(k*LL/ng) for k in range(ng)]; h=LL/ng
KMAX=1/800  # grid limit; the track spline overshoots between knots, giving ~1/400 m effective
for it in range(20000):
    worst=0
    for i in range(ng):
        m=(g[i-1]+g[(i+1)%ng])/2; kv=(g[i-1]-2*g[i]+g[(i+1)%ng])/(h*h)
        if abs(kv)>KMAX:
            worst=max(worst,abs(kv)); g[i]=m-math.copysign(KMAX*h*h/2,kv)
    if worst<KMAX*1.02: break
zs_old=zc[:]
zc=[g[int(round(arcs[i]/h))%ng] for i in range(nz)]
# Clip once more on the control points themselves (they are what the game interpolates).
seg=[math.dist(merged[i],merged[(i+1)%nz]) for i in range(nz)]
for it2 in range(20000):
    worst=0
    for i in range(nz):
        h0=seg[i-1]; h1=seg[i]; a=zc[i-1]; c=zc[(i+1)%nz]; lin=(a*h1+c*h0)/(h0+h1)
        kv=2*((c-zc[i])/h1-(zc[i]-a)/h0)/(h0+h1)
        if abs(kv)>KMAX:
            worst=max(worst,abs(kv)); zc[i]=lin-math.copysign(KMAX*h0*h1/2,kv)
    if worst<KMAX*1.02: break
print('control clip iterations',it2)
print('vertical relax iterations',it,'max dz from DEM %.2f m'%max(abs(zc[i]-zs_old[i]) for i in range(nz)))
points=[{"x":round(p[0],1),"y":round(p[1],1),"w":width[i],"z":round(zc[i],2),"bank":0.0} for i,p in enumerate(merged)]
# arc length of control polyline (approx) for start line
arc=[0.0]
for i in range(1,len(merged)): arc.append(arc[-1]+math.dist(merged[i-1],merged[i]))
L=arc[-1]+math.dist(merged[-1],merged[0])
la=ls[len(ls)//2]
start=(arc[la]-170)%L
# labels from OSM way names (midpoint node of each named way)
m={'La Source':'La Source','Eau Rouge':'Eau Rouge','Raidillon':'Raidillon','Kemmel':'Kemmel','Les Combes':'Les Combes','Malmedy':'Malmedy','Bruxelles':'Bruxelles','No Name':"Speaker's Corner",'Pouhon':'Double Gauche','Fagnes':'Fagnes','Stavelot':'Campus','Paul Frère':'Courbe Paul Frère','Blanchimont':'Blanchimont','Bus Stop':'Chicane'}
labels=[]
for label,osm in m.items():
    cands=[wy for wy in ways if wy.get('tags',{}).get('name')==osm and any(tuple(nodes[nd]) in {tuple(q) for q in loop} for nd in wy['nodes'])]
    wy=max(cands,key=lambda q:len(q['nodes'])); c=P(nodes[wy['nodes'][len(wy['nodes'])//2]])
    labels.append({"name":label,"x":round(c[0],1),"y":round(c[1],1)})
old=json.load(open('old_spa.json'))  # previous hand-traced file: keeps curb colours/theme
pres=old['presentation']; pres['labels']=labels
pres['source']="OpenStreetMap raceway centreline (© OpenStreetMap contributors, ODbL); elevation: lower of EU-DEM 25 m and SRTM 30 m via OpenTopoData, median + 60 m smoothing, effective vertical radius ~400 m"
pres['description']="Grand Prix layout from OSM survey data with real elevation (%.0f m range). Widths, curbs, runoff and scenery are approximations." % (max(zs)-min(zs))
pres["scenery"]={"trees":5.0,"pines":.88,"treeline":28,"treeHeight":1.7}
doc={"schema":1,"name":"Spa-Francorchamps","savedAt":None,"points":points,"curbAuto":True,"curbOverride":{},"paint":{},"objects":[],"autoBarriers":True,"startS":round(start,1),"gridS":None,"presentation":pres}
json.dump(doc,open('spa_new.json','w'),indent=2)
print(len(points),'points, polyline',round(L),'m, start',round(start),'names',sorted(set(filter(None,names))))
