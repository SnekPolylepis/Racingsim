"""Six North Michigan authored exterior study; Blender +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, arch, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('SixMichigan pale stone surrounds',(.61,.57,.47),roughness=.9)
brick=material('SixMichigan warm brick piers',(.39,.255,.19),roughness=.95)
inset=material('SixMichigan recessed opaque masonry',(.34,.31,.26),roughness=.98)
trim=material('SixMichigan projecting carved stone',(.69,.64,.53),roughness=.87)
glass=material('SixMichigan separate recessed glass',(.12,.18,.19),roughness=.5)
night=material('Night SixMichigan occupied glass',(.12,.18,.19),roughness=.5,glow=.2)
frame=material('SixMichigan dark sash frames',(.075,.085,.08),metallic=.2)
roof=material('SixMichigan opaque roof surface',(.32,.32,.29),roughness=.96)
cx,cz=-48.5,274.4
data=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
plan=[(x-cx,-(z-cz)) for x,z in next(b for b in data['buildings'] if b['o']=='w126982631')['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()

def prism(name,points,lo,hi,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (lo,hi) for x,y in points],
 [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)

def orient(obj,a,b):
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
 for polygon in obj.data.polygons:polygon.flip()
 return obj

def facade(name,pos,size,mat,a,b):return orient(box(name,pos,size,mat),a,b)

def window(u,lo,pw,ph,a,b,mat=glass):
 facade('Separate recessed glazing',(u,-.58,lo+ph/2),(pw,.08,ph),mat,a,b)
 for dx in (-pw/2,pw/2):facade('Physical window sash upright',(u+dx,-.46,lo+ph/2),(.07,.18,ph),frame,a,b)
 for z in (lo,lo+ph*.30,lo+ph):facade('Physical horizontal sash rail',(u,-.45,z),(pw,.20,.07),frame,a,b)
 for dx in (-pw/2-.1,pw/2+.1):facade('Pale projecting window surround',(u+dx,-.02,lo+ph/2),(.18,.48,ph+.28),stone,a,b)
 for z in (lo-.14,lo+ph+.14):facade('Pale window sill and lintel',(u,-.02,z),(pw+.4,.50,.20),stone,a,b)

# ponytail: published86m envelope; base12m/body68m/crown splits and returns are photo-fit, not surveyed.
H=86.;base=12.;body=68.;rows=16;step=(body-base)/rows
prism('Exact mapped foundation',plan,-8,0,stone)
prism('Opaque inset main masonry',[(x*.96,y*.96) for x,y in plan],0,body,inset)
prism('Main roof membrane',plan,body-.25,body,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b);count=9 if width<30 else 15;pitch=width/count;pw=pitch-.85
 east=a[0]>24 and b[0]>24
 facade('Opaque lower wall',(width/2,-1.15,base/2),(width,.2,base),inset,a,b)
 for j in range(count+1):
  facade('Tall continuous brick or stone pier',(j*pitch,-.03,(base+body)/2),(.65,.80,body-base),stone if east and (j<=3 or j>=6) else brick,a,b)
  facade('Stone base structural pier',(j*pitch,-.05,base/2),(.65,1.0,base),stone,a,b)
 for row in range(rows):
  lo=base+row*step
  for j in range(count):
   u=(j+.5)*pitch
   window(u,lo+.4,pw,2.35,a,b,night if (row*13+j*7)%37==3 else glass)
   facade('Decorated spandrel panel',(u,-.06,lo+step-.25),(pw+.3,.4,.35),stone,a,b)
   for dx in (-pw*.34,pw*.34):facade('Spandrel relief boss',(u+dx,.18,lo+step-.25),(.17,.14,.17),trim,a,b)
  if row%2==0:
   facade('Rusticated horizontal stone course',(width/2,-.1,lo),(width,.48,.12),stone,a,b)
 for row,lo,ph in [(0,.3,4.6),(1,5.4,2.45),(2,8.9,2.45)]:
  for j in range(count):window((j+.5)*pitch,lo,pw,ph,a,b)
 for z,dep,h in [(5.1,1.05,.45),(8.5,.8,.35),(base,1.0,.5),(body-.7,1.2,.45),(body-.2,1.45,.35)]:
  facade('Projecting stone belt and body cornice',(width/2,.08,z),(width,dep,h),trim,a,b)
 for j in range(count*2):facade('Body cornice dentil',((j+.5)*pitch/2,.62,body-.9),(.22,.25,.25),trim,a,b)

# Raised crown sits over the central three Michigan Avenue bays. Hidden tower returns remain provisional.
tower=[(8,-6),(24.8,-6),(24.8,6),(8,6)]
prism('Raised crown recessed opaque core',[(16.4+(x-16.4)*.90,y*.88) for x,y in tower],body,82.3,brick)
prism('Crown flat roof',tower,82.3,82.6,roof)
for a,b in zip(tower,tower[1:]+tower[:1]):
 width=math.dist(a,b);pitch=width/3
 for j in range(3):
  u=(j+.5)*pitch
  window(u,68.8,pitch-.8,2.35,a,b)
  window(u,72.3,pitch-.8,2.0,a,b)
  pw=min(2.25,pitch-.8);spring=78.55
  window(u,75.5,pw,3.05,a,b)
  radius=pw/2
  arcpoints=[(u+radius*math.cos(math.pi*i/24),spring+radius*math.sin(math.pi*i/24)) for i in range(25)]
  orient(mesh('Physical arched crown glass',[(x,y,z) for y in (-.62,-.54) for x,z in arcpoints],
      [tuple(range(25)),tuple(reversed(range(25,50)))]+[(i,i+1,i+26,i+25) for i in range(24)],glass),a,b)
  orient(arch('Projecting semicircular crown surround',radius,radius+.22,(u,spring),-.10,.30,trim,segments=24),a,b)
 for z,dep,h in [(body,.95,.35),(74.7,1.3,.5),(81.3,1.4,.45),(82.3,1.7,.45)]:
  facade('Raised crown projecting cornice',(width/2,.05,z),(width,dep,h),trim,a,b)
 for j in range(12):facade('Crown cornice dentil',((j+.5)*width/12,.78,81.8),(.25,.25,.35),trim,a,b)
cap=[(10,-5),(23.8,-5),(23.8,5),(10,5)]
prism('Upper rectangular crown cap',cap,82.6,H-.3,brick)
prism('Upper cap opaque flat roof',cap,H-.3,H,roof)
for a,b in zip(cap,cap[1:]+cap[:1]):
 width=math.dist(a,b)
 for z in (83.,85.7):facade('Cap rectangular stone frame',(width/2,.02,z),(width,.75,.25),trim,a,b)
 for u in (.3,width-.3):facade('Cap upright stone frame',(u,.02,84.35),(.3,.75,2.7),trim,a,b)
 for j in range(3):
  u=width/2+(j-1)*1.5
  orient(arch('Upper cap circular relief',.27,.43,(u,84.3),.16,.18,trim,start=0,end=2*math.pi,segments=24),a,b)
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':assert all(math.isfinite(v) for vertex in obj.data.vertices for v in vertex.co),obj.name
finish('six_michigan',OUT)
