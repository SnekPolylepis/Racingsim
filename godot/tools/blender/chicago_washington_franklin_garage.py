"""Washington/Franklin Self Park photo-fit exterior draft; +Y north, +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Washington garage pale masonry piers',(.56,.52,.44),roughness=.9)
panel=material('Washington garage pale inset spandrels',(.66,.63,.55),roughness=.9)
slab=material('Washington garage recessed concrete slabs',(.28,.28,.26),roughness=.95)
metal=material('Washington garage dark bay frames',(.10,.12,.11),roughness=.8)
glass=material('Washington garage recessed retail glazing',(.12,.19,.20),roughness=.45)
green=material('Washington garage green parking sign',(.055,.23,.12),roughness=.8)
letters=material('Washington garage pale sign lettering',(.80,.80,.71),roughness=.8)
cx,cz=-871.5,136.7
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w147095680')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def facade(name,pos,size,mat,a,b):
 obj=box(name,pos,size,mat)
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
 for p in obj.data.polygons:p.flip()
 return obj
# ponytail: mapped49m and ten upper rows are provisional; verify full elevations before integration.
H=49
levels=[0,6]+[6+i*4.3 for i in range(1,11)]
prism('Exact seven vertex buried foundation',plan,-8,0,stone)
for z in levels:prism('Physical recessed parking floor plate',plan,z-.22,z,slab)
# Model the parking voids with floor plates and deep piers, not dark facade images.
for a,b in zip(plan,plan[1:]+plan[:1]):
 length=math.dist(a,b)
 if length<4:continue
 bays=max(1,round(length/5.9));pitch=length/bays
 west=a[0]<-23 and b[0]<-23
 north=a[1]>25 and b[1]>25
 for j in range(bays+1):
  facade('Broad continuous masonry pier',(j*pitch,-.38,H/2),(1.10,.70,H),stone,a,b)
  for offset in (-.40,.40):facade('Shallow paired pier relief',(j*pitch+offset,.005,H/2),(.10,.10,H),panel,a,b)
 for z in levels[1:]:
  facade('Horizontal slab fascia',(length/2,-.27,z-.25),(length,.80,.50),stone,a,b)
 for z in levels[1:-1]:
  for j in range(bays):
   x=(j+.5)*pitch
   facade('Inset pale parking spandrel',(x,-.38,z+.85),(pitch-1.10,.30,1.70),panel,a,b)
   facade('Spandrel top coping',(x,-.14,z+1.73),(pitch-1.03,.55,.12),stone,a,b)
   facade('Dark open bay centre upright',(x,-.46,z+2.92),(.10,.18,2.25),metal,a,b)
   facade('Interior bay supporting beam',(x,-3.0,z+3.98),(pitch,.50,.42),slab,a,b)
 # Ground-level retail and vehicle entry, photo-fit Franklin entrance in northern bay.
 for j in range(bays):
  x=(j+.5)*pitch
  if west and j==bays-2:
   facade('Recessed entrance overhead panel',(x,-.35,4.90),(pitch-1.05,.25,.65),panel,a,b)
   # Entrance corridor recedes9m; no wall blocks its opening.
   for dx in (-.5,.5):facade('Garage entry corridor wall',(x+dx*(pitch-1.20),-4.70,2.30),(.20,8.50,4.60),stone,a,b)
   facade('Garage entry inner ceiling',(x,-4.70,4.5),(pitch-1.20,8.50,.20),slab,a,b)
  else:
   for k in (-1,1):facade('Deeply recessed retail pane',(x+k*(pitch-1.20)/4,-.80,2.20),((pitch-1.20)/2-.08,.05,4.15),glass,a,b)
   for dx in (-.5,0,.5):facade('Retail dark upright',(x+dx*(pitch-1.20),-.68,2.20),(.10,.18,4.30),metal,a,b)
  facade('Ground transom beam',(x,-.22,5.65),(pitch-.90,.55,.42),stone,a,b)
 facade('Upper parapet coping',(length/2,-.20,H-.20),(length,.90,.40),stone,a,b)
 if west:
  facade('Projecting Franklin green parking sign',(length*.58,.50,14.5),(2.3,.45,3.3),green,a,b)
  # Face west; original text geometry is reference signage, never a pasted photo.
  sx=a[0]+length*.58*(b[0]-a[0])/length
  sy=a[1]+length*.58*(b[1]-a[1])/length
  text('Physical parking P','P',(sx-.78,sy,14.9),1.25,letters,rotate=(math.pi/2,0,-math.pi/2))
for o in bpy.context.scene.objects:
 if o.type=='MESH':assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
finish('washington_franklin_garage',OUT)
