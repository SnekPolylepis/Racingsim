"""Brooks Building original exterior, mapped footprint, +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
terra=material('Orange brown terracotta piers',(.48,.31,.21),roughness=.88)
trim=material('Warm terracotta mouldings',(.59,.42,.29),roughness=.85)
stone=material('Pale two storey retail base',(.65,.63,.56),roughness=.9)
green=material('Green glazed terra cotta ornament',(.16,.30,.24),roughness=.72)
bronze=material('Dark bronze window frames',(.15,.12,.09),metallic=.15,roughness=.7)
glass=material('Recessed blue grey office panes',(.14,.22,.27),roughness=.5)
occupied=material('Night occupied office panes',(.14,.22,.27),roughness=.5,glow=.2)
dark=material('Dark roof and doorway recesses',(.09,.10,.10),roughness=.9)
red=material('Red Jackson retail awnings',(.38,.05,.04),roughness=.85)
light=material('Night recessed entrance lighting',(.70,.58,.39),roughness=.65,glow=.2)
cx,cz=-861.3,769.8
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w73766157')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def orient(obj,a,b):
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d;nx,ny=ty,-tx
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*nx,a[1]+x*ty+y*ny,z)
 for p in obj.data.polygons:p.flip()
 return obj
def part(name,pos,size,mat,a,b):return orient(box(name,pos,size,mat),a,b)
prism('Retained five vertex foundation',plan,-8,.10,stone)
# Merge the nearly collinear mapped north split only for the facade bay layout.
outline=[(x-cx,-(z-cz)) for x,z in b['f'][:4]]
if sum(x*v-y*u for (x,y),(u,v) in zip(outline,outline[1:]+outline[:1]))<0:outline.reverse()
# ponytail: mapped height and photo-fit reliefs remain provisional; refine with measured elevations and sculpture closeups.
BASE=9.4;PITCH=4.35;TOP=57.0
for row in range(11):prism('Thin physical office floor',plan,BASE+row*PITCH-.20,BASE+row*PITCH-.08,dark)
prism('Recessed flat roof',[(x*.98,y*.98) for x,y in plan],55.6,55.8,dark)
for edge,(a,b) in enumerate(zip(outline,outline[1:]+outline[:1])):
 length=math.dist(a,b);bays=8 if length>40 else 5;pitch=length/bays
 north=(a[1]+b[1])/2>10;west=(a[0]+b[0])/2<-15
 for j in range(bays+1):
  h=j*pitch
  part('Narrow full height terra cotta pier',(h,.06,31.1),(.65,.56,43.4),terra,a,b)
  for k in range(5):part('Gothic bundled vertical pier rib',(h+(k-2)*.10,.37+(2-abs(k-2))*.035,31.1),(.07,.12,43.4),trim,a,b)
  part('Pale retail pier',(h,.08,4.7),(.73,.66,9.4),stone,a,b)
  for k in (-1,1):part('Retail pier vertical profile',(h+k*.24,.43,4.7),(.085,.12,8.8),stone,a,b)
  # Original relief silhouettes repeat the green floral caps visible in city closeups.
  for z in (9.4,54.5):
   for k in range(8):
    angle=k*math.tau/8
    x=h+.24*math.cos(angle);height=z+.24*math.sin(angle)
    o=mesh('Raised green floral capital',[(x-.09,.43,height),(x,.57,height-.13),(x+.09,.43,height),(x,.57,height+.13),(x,.64,height)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],green)
    orient(o,a,b)
 for row in range(10):
  z=BASE+row*PITCH
  part('Terracotta office spandrel',(length/2,.04,z+.49),(length,.46,.98),terra,a,b)
  part('Projecting storey sill',(length/2,.30,z+1.05),(length,.63,.13),trim,a,b)
  part('Storey head moulding',(length/2,.20,z+4.20),(length,.53,.12),trim,a,b)
  for j in range(bays):
   h=(j+.5)*pitch;w=(pitch-.90)/3
   for pane in range(3):
    x=h+(pane-1)*(w+.10)
    mat=occupied if (edge*19+row*11+j*3+pane)%7==0 else glass
    part('Separate recessed grouped office pane',(x,-.29,z+2.62),(w,.055,2.95),mat,a,b)
    for dx in (-w/2,w/2):part('Bronze pane jamb',(x+dx,-.19,z+2.62),(.065,.13,3.06),bronze,a,b)
    for zz in (z+1.12,z+2.73,z+4.12):part('Physical pane rail',(x,-.19,zz),(w,.13,.075),bronze,a,b)
   for seam in range(7):part('Spandrel tile vertical joint',(h+(seam-3)*(pitch-.9)/7,.285,z+.48),(.025,.035,.64),trim,a,b)
 for z in (4.45,9.2):
  part('Pale retail spandrel',(length/2,.05,z),(length,.52,.48),stone,a,b)
  part('Retail cornice profile',(length/2,.27,z+.27),(length,.64,.12),stone,a,b)
 for j in range(bays):
  h=(j+.5)*pitch;entry=north and j==4
  for z,height in ((2.1,3.9),(6.8,4.0)):
   for pane in range(3):
    w=(pitch-.9)/3;x=h+(pane-1)*(w+.10)
    part('Recessed retail pane',(x,-1.3 if entry and z<3 else -.32,z),(w,.065,height),glass,a,b)
    for dx in (-w/2,w/2):part('Retail pane vertical frame',(x+dx,-1.2 if entry and z<3 else -.20,z),(.085,.18,height),bronze,a,b)
   for zz in (z-height/2,z+height/2):part('Retail transom',(h,-1.2 if entry and z<3 else -.20,zz),(pitch-.75,.18,.09),bronze,a,b)
  if entry:
   part('Actual recessed entrance ceiling',(h,-.65,4.03),(pitch-.8,1.5,.18),stone,a,b)
   part('Recessed entrance ceiling fixture',(h,-.70,3.92),(2.1,.45,.04),light,a,b)
   for dx in (-.52,.52):part('Bronze entrance door pull',(h+dx,-1.07,1.35),(.035,.10,.55),bronze,a,b)
  if north and j in (0,1,2,6,7):
   awn=box('Jackson red projecting awning',(h,.77,3.5),(pitch-.75,1.9,.12),red)
   for v in awn.data.vertices:v.co.z-=.18*(v.co.y-.77)
   orient(awn,a,b)
 for z,depth,height in ((53.1,.30,.32),(55.3,.42,.25),(55.8,.62,.28),(56.3,.84,.28),(56.75,1.05,.5)):
  part('Tiered projecting cornice',(length/2,depth/2-.05,z),(length+1.0,depth,height),trim,a,b)
 for j in range(bays):
  h=(j+.5)*pitch
  part('Green glazed frieze panel',(h,.16,54.05),(pitch-.9,.20,1.3),green,a,b)
  for dx in (-1.2,-.6,0,.6,1.2):
   o=mesh('Raised frieze diamond',[(h+dx-.16,.31,54.05),(h+dx,.31,53.80),(h+dx+.16,.31,54.05),(h+dx,.31,54.30),(h+dx,.40,54.05)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],trim);orient(o,a,b)
assert abs(BASE+10*PITCH-52.9)<.001
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z<=57.01 for v in o.data.vertices),o.name
finish('brooks_building',OUT)
