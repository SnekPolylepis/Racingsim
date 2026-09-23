"""Rebuild the compact Spa source crop; Python 3 + NumPy, network only for missing raw responses."""
import json, math, pathlib, urllib.parse, urllib.request, concurrent.futures, time, sys
import numpy as np
ROOT=pathlib.Path(__file__).resolve().parent
SERVICE='https://geoservices.wallonie.be/arcgis/rest/services/RELIEF/WALLONIE_MNT_2021_2022/MapServer/identify'
def save(name,data):
    (ROOT/name).write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def fetch_pixels(name,coords):
    dest=ROOT/'raw-lidar'/f'{name}.json'; dest.parent.mkdir(exist_ok=True)
    if dest.exists():
        raw=dest.read_bytes()
    else:
        params={'f':'json','geometryType':'esriGeometryMultipoint','geometry':json.dumps({'points':coords,'spatialReference':{'wkid':4326}},separators=(',',':')),'sr':4326,'layers':'all:0','tolerance':0,'mapExtent':'5.95,50.42,5.99,50.46','imageDisplay':'100000,100000,96','returnGeometry':'false'}
        req=urllib.request.Request(SERVICE,data=urllib.parse.urlencode(params).encode(),headers={'User-Agent':'RacingSim/1.0 (public circuit authoring)'})
        for attempt in range(3):
            try:
                raw=urllib.request.urlopen(req,timeout=45).read(); doc=json.loads(raw)
                if len(doc.get('results',[])) != len(coords): raise ValueError(str(doc)[:300])
                dest.write_bytes(raw); break
            except Exception:
                if attempt==2: raise
                time.sleep(1+attempt)
    results=json.loads(raw)['results']
    if len(results)!=len(coords): raise ValueError(f'{name}: expected {len(coords)} results, got {len(results)}')
    values=[float(r['attributes']['Stretch.Pixel Value']) for r in results]
    if not all(math.isfinite(v) and 200<v<800 for v in values): raise ValueError(f'{name}: invalid heights')
    return values
ways=json.loads((ROOT/'osm-ways.json').read_text(encoding='utf-8'))['elements']
nodes={n['id']:(n['lat'],n['lon']) for n in json.loads((ROOT/'osm-nodes.json').read_text(encoding='utf-8'))['elements']}
adj={}; edgeway={}
for w in ways:
    if w.get('tags',{}).get('name') in {'Kart','Pit Lane','Support Pit Lane','Moto layout'} or w.get('tags',{}).get('sport')=='karting': continue
    for a,b in zip(w['nodes'],w['nodes'][1:]):
        adj.setdefault(a,[]).append(b); edgeway[a,b]=w
start=next(w for w in ways if w.get('tags',{}).get('name')=='Kemmel')['nodes'][0]
loop=[start]; cur=start
while True:
    nxt=adj[cur]
    if len(nxt)!=1: raise ValueError(f'non-unique GP edge {cur}: {nxt}')
    cur=nxt[0]
    if cur==start: break
    if cur in loop: raise ValueError('premature loop')
    loop.append(cur)
lat0=(min(nodes[n][0] for n in loop)+max(nodes[n][0] for n in loop))/2
lon0=(min(nodes[n][1] for n in loop)+max(nodes[n][1] for n in loop))/2
r=6371008.8; ky=math.pi*r/180; kx=ky*math.cos(math.radians(lat0))
def local(ll): return [(ll[1]-lon0)*kx,-(ll[0]-lat0)*ky]
def geographic(p): return [round(lon0+p[0]/kx,8),round(lat0-p[1]/ky,8)]
p=np.array([local(nodes[n]) for n in loop]); arc=np.concatenate(([0.],np.cumsum(np.linalg.norm(np.roll(p,-1,axis=0)-p,axis=1)))); L=float(arc[-1])
loopset=set(loop); landmarks={}
labels={'La Source':'La Source','Eau Rouge':'Eau Rouge','Raidillon':'Raidillon','Kemmel':'Kemmel','Les Combes':'Les Combes','Malmedy':'Malmedy','Bruxelles':'Bruxelles','No Name':"Speaker's Corner",'Pouhon':'Double Gauche','Fagnes':'Fagnes','Stavelot':'Campus','Paul Frere':'Courbe Paul Frère','Blanchimont':'Blanchimont','Bus Stop':'Chicane'}
for label,osm in labels.items():
    candidates=[w for w in ways if w.get('tags',{}).get('name')==osm and all(n in loopset for n in w['nodes'])]
    w=max(candidates,key=lambda w:len(w['nodes'])); mid=w['nodes'][len(w['nodes'])//2]; landmarks[label]=float(arc[loop.index(mid)])
start_s=(landmarks['La Source']-170.)%L
sections={k:round((v-start_s)%L,3) for k,v in landmarks.items()}
def sample(ss):
    ss=np.asarray(ss)%L
    return np.column_stack([np.interp(ss,arc,np.append(p[:,c],p[0,c])) for c in range(2)])
# A regular 10m planar polyline preserves the surveyed corner shape; generator supplies smooth handles.
count=round(L/10); stations=np.arange(count)*L/count; points=sample(stations+start_s)
ecount=round(L/20); es=np.arange(ecount)*L/ecount; ep=sample(es+start_s)
ecoords=[geographic(x) for x in ep]
save('lidar-road-query.json',{'service':SERVICE,'coordinates_lon_lat':ecoords,'station_m':es.tolist(),'resolution_m':0.5,'imageDisplay':'100000,100000,96'})
heights=np.array(fetch_pixels('road',ecoords)); measured=heights.copy()
# Remove a single-pixel spike, then modest ~20m Gaussian averaging. Preserve the steep Raidillon ascent.
heights=np.array([np.median([heights[(i+j)%ecount] for j in [-1,0,1]]) for i in range(ecount)])
weights=np.array([math.exp(-.5*j*j) for j in range(-3,4)]); weights/=sum(weights)
heights=sum(np.roll(heights,j)*weights[j+3] for j in range(-3,4))
# Restrict finite-difference vertical curvature to ~1/180 outside the Raidillon crest, ~1/110 there.
delta=L/ecount
limit=np.ones(ecount)/180.
for i,s in enumerate(es):
    if sections['Raidillon']-20 < s < sections['Raidillon']+170: limit[i]=1/110.
for iteration in range(1000):
    worst=0.
    for i in range(ecount):
        m=(heights[i-1]+heights[(i+1)%ecount])*.5
        diff=heights[i]-m; allowed=limit[i]*delta*delta*.5
        if abs(diff)>allowed:
            worst=max(worst,abs(diff)-allowed); heights[i]=m+math.copysign(allowed,diff)
    if worst<1e-8: break
# Match RoadBuilder's periodic cubic system; between-knot second derivative is linear.
a=np.eye(ecount)*4+np.roll(np.eye(ecount),1,axis=0)+np.roll(np.eye(ecount),-1,axis=0)
second=np.linalg.solve(a,6*(np.roll(heights,1)-2*heights+np.roll(heights,-1))/(delta*delta))
outside=(es < sections['Raidillon']-20)|(es > sections['Raidillon']+170)
min_radius_outside=1/float(max(abs(second[outside])))
if min_radius_outside < 150: raise ValueError(f'Periodic elevation spline too sharp: {min_radius_outside}m')
base=float(heights[0]); relative=heights-base
poly_length=float(np.sum(np.linalg.norm(np.roll(points,-1,axis=0)-points,axis=1)))
metrics={'source_polyline_length_m':L,'resampled_planar_length_m':poly_length,'elevation_range_m':float(np.ptp(heights)),'road_absolute_min_m':float(min(heights)),'road_absolute_max_m':float(max(heights)),'max_smoothing_change_m':float(max(abs(heights-measured))),'max_gradient_percent':float(max(abs(np.roll(heights,-1)-heights))/delta*100),'elevation_key_spacing_m':delta,'point_count':count,'elevation_key_count':ecount,'periodic_spline_min_radius_m':1/float(max(abs(second))),'periodic_spline_min_radius_outside_raidillon_m':min_radius_outside}
centre={'schema':1,'source':'OpenStreetMap contributors; official OSM API 2026-09-23 (Overpass endpoints unavailable)','attribution':'© OpenStreetMap contributors · ODbL 1.0 | Elevation © SPW 2021–2022 · CC BY 4.0','origin':{'lat':lat0,'lon':lon0,'elevation_m':base,'projection':'equirectangular, Earth mean radius 6371008.8m, X east, Z south'},'start_offset_m':0,'points':np.round(points,5).tolist(),'elevation_keys':[{'s':round(float(s),5),'height':round(float(h),5)} for s,h in zip(es,relative)],'sections':sections,'measurements':metrics}
save('centreline.json',centre); print('CENTRELINE READY',json.dumps(metrics),flush=True); print('SECTIONS',json.dumps(sections),flush=True)
# Terrain is a 20m regular crop sampled from the 0.5m public LiDAR raster, with at least 600m padding.
spacing=20.; low=np.floor((np.min(p,axis=0)-600)/spacing)*spacing; high=np.ceil((np.max(p,axis=0)+600)/spacing)*spacing
width,height=(np.rint((high-low)/spacing).astype(int)+1).tolist()
terrain_coords=[geographic([low[0]+x*spacing,low[1]+z*spacing]) for z in range(height) for x in range(width)]
chunks=[terrain_coords[i:i+400] for i in range(0,len(terrain_coords),400)]
save('lidar-terrain-query.json',{'service':SERVICE,'width':width,'height':height,'origin_offset':low.tolist(),'metres_per_pixel':spacing,'origin':centre['origin'],'batch_size':400,'coordinate_order':'rows north to south; each row west to east; inverse equirectangular to lon,lat, rounded8 decimal places','imageDisplay':'100000,100000,96'})
values=[None]*len(chunks)
def task(pair):
    i,c=pair; return i,fetch_pixels(f'terrain-{i:03}',c)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for i,v in pool.map(task,enumerate(chunks)):
        values[i]=v
        if i%10==0: print(f'TERRAIN {i+1}/{len(chunks)}',flush=True)
all_values=np.array([v for c in values for v in c]); (all_values-base).astype('<f4').tofile(ROOT/'dem.raw')
header={'schema':1,'file':'dem.raw','width':width,'height':height,'metres_per_pixel':spacing,'origin_offset':low.tolist(),'height_scale':1.,'height_offset':0.,'dtype':'little-endian IEEE754 float32','layout':'row-major, x east then z south','vertical_reference':'relative to smoothed road at start/finish','absolute_height_offset_m':base,'source_resolution_m':0.5,'source':'SPW MNT 2021–2022, updated2024-01-23, sampled via identify layer0','source_catalogue':'https://geoportail.wallonie.be/catalogue/a004e570-99d6-4fe5-b83d-49b774409278.html','licence':'CC BY 4.0','raw_response_directory':'raw-lidar','sample_count':len(all_values),'absolute_min_m':float(min(all_values)),'absolute_max_m':float(max(all_values))}
save('terrain.json',header); print('TERRAIN READY',json.dumps(header),flush=True)
