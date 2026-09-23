import json,math,time,urllib.request,urllib.parse,sys
loop=json.load(open('loop.json'))
def m(a,b):
    la=math.radians((a[0]+b[0])/2); return math.hypot((a[1]-b[1])*111320*math.cos(la),(a[0]-b[0])*110540)
pts=[loop[0]]; acc=0
for i in range(1,len(loop)+1):
    a=loop[i-1]; b=loop[i%len(loop)]; seg=m(a,b); t=20-acc
    while t<=seg: pts.append((a[0]+(b[0]-a[0])*t/seg,a[1]+(b[1]-a[1])*t/seg)); t+=20
    acc=seg-(t-20)
print(len(pts))
out={}
for ds in sys.argv[1:]:
    zs=[]
    for k in range(0,len(pts),100):
        loc='|'.join('%.6f,%.6f'%tuple(p) for p in pts[k:k+100])
        req=urllib.request.Request('https://api.opentopodata.org/v1/'+ds,data=urllib.parse.urlencode({'locations':loc}).encode(),headers={'User-Agent':'RacingSim-track-builder'})
        r=json.load(urllib.request.urlopen(req,timeout=60)); zs+= [x['elevation'] for x in r['results']]; time.sleep(1.2)
    out[ds]=zs; print(ds,min(zs),max(zs))
json.dump({'pts':pts,'z':out},open('ele.json','w'))
