"""Franklin/Van Buren garage exterior draft; mapped plan, +Y north, +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
concrete=material('Pale cast concrete garage structure',(.55,.53,.49),roughness=.9)
slab=material('Grey parking slabs and ramps',(.29,.30,.29),roughness=.92)
metal=material('Dark metal retail frames and guardrails',(.12,.15,.15),roughness=.7)
glass=material('Recessed retail glass',(.13,.21,.22),roughness=.5)
light=material('Night recessed garage ceiling fixtures',(.72,.70,.60),roughness=.6,glow=.25)
sign=material('Green parking sign panels',(.08,.23,.15),roughness=.8)
letter=material('Pale physical sign lettering',(.74,.76,.68),roughness=.8)
cx,cz=-859.5,844.05
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w74268219')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def facade(name,pos,size,mat,a,b):
 obj=box(name,pos,size,mat)
 tx,ty=(b[0]-a[0],b[1]-a[1]);d=math.hypot(tx,ty);tx/=d;ty/=d
 nx,ny=ty,-tx
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*nx,a[1]+x*ty+y*ny,z)
 for poly in obj.data.polygons:poly.flip()
 return obj
prism('Retained mapped six vertex foundation',plan,-8,.05,concrete)
# Fourteen parking levels follow the historical structural brochure; heights are photo-fit.
levels=[0,6.1]+[6.1+i*3.3 for i in range(1,13)]
assert len(levels)==14 and abs(levels[-1]-45.7)<.001
for z in levels+[49.0]:prism('Physical parking floor plate',plan,z-.23,z,slab)
for a,b in zip(plan,plan[1:]+plan[:1]):
 length=math.dist(a,b)
 if length<8:continue
 bays=max(1,round(length/4.2));pitch=length/bays
 for j in range(bays+1):
  facade('Continuous exposed vertical pier',(j*pitch,-.38,24.5),(.55,.65,49),concrete,a,b)
 for z in levels[1:]+[49.0]:
  facade('Exposed slab edge and hanging beam',(length/2,-.35,z-.23),(length,.75,.48),concrete,a,b)
 for z in levels[1:]:
  facade('Parking bay concrete guard spandrel',(length/2,-.32,z+.52),(length,.55,1.04),concrete,a,b)
  facade('Guardwall coping',(length/2,-.24,z+1.07),(length,.70,.10),concrete,a,b)
 # Recessed ground retail panes leave each bay open behind the structural piers.
 for j in range(bays):
  h=(j+.5)*pitch
  if 2<=j<=3:continue
  facade('Ground retail pane',(h,-1.1,2.6),(pitch-.7,.06,4.2),glass,a,b)
  facade('Retail pane head',(h,-1.04,4.75),(pitch-.6,.14,.12),metal,a,b)
  facade('Retail pane centre mullion',(h,-1.04,2.6),(.075,.14,4.3),metal,a,b)
 for z in levels[1:]:
  for j in range(bays):
   facade('Recessed ceiling strip fixture',((j+.5)*pitch,-2.0,z+2.85),(1.4,.35,.06),light,a,b)
# Interior beams and ramps give open bays depth rather than a black wall behind them.
for z,next_z in zip(levels[1:],levels[2:]):
 for x in (-10,10):
  box('Interior supporting beam',(x,0,next_z-.6),(.55,61,.75),concrete)
  ramp=box('Visible internal sloped ramp',(x,0,(z+next_z)/2),(7,24,.23),slab)
  for v in ramp.data.vertices:v.co.z+=(v.co.y/24)*(next_z-z)
for x in (-10,10):
 for y in (-22,0,22):box('Interior column',(x,y,24),(.65,.65,48),concrete)
# Photo-fit rounded northeast corner stair core with real narrow slot apertures.
tx,ty=19.8,28.4
for z in levels[1:]:
 for j in range(32):
  a=j*math.tau/32;b=(j+1)*math.tau/32
  def band(lo,hi):
   return mesh('Rounded corner concrete band',[(tx+r*math.cos(t),ty+r*math.sin(t),h) for h in (lo,hi) for r,t in [(2.55,a),(2.55,b),(2.15,b),(2.15,a)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],concrete)
  band(z,z+1.0);band(z+1.45,z+3.3)
  if j%8<5:band(z+1.0,z+1.45)
box('Recessed corner stair core',(tx,ty,24),(2.4,2.4,48),slab)
box('North physical parking sign',(tx,ty+2.62,4.2),(3.8,.14,1.2),sign)
text('North parking letters','SELF PARK',(tx,ty+2.72,4.2),.40,letter,rotate=(math.pi/2,0,math.pi))
for x in (-19,19):
 for y in (-27,27):box('Roof guard upright',(x,y,49.55),(.16,.16,1.1),metal)
for y in (-27,27):box('Roof north south guardrail',(0,y,50),(38,.12,.12),metal)
for x in (-19,19):box('Roof east west guardrail',(x,0,50),(.12,54,.12),metal)
for side in (-1,1):
 for i in range(21):
  y=-26+i*2.6
  box('Photo fit rooftop parking stall stripe',(side*14,y,49.012),(6,.10,.018),letter)
  box('Roof parking wheel stop',(side*17,y+1.3,49.10),(.20,1.3,.18),concrete)
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z<=50.1 for v in o.data.vertices),o.name
finish('franklin_garage',OUT)
