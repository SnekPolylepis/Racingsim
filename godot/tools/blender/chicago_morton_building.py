"""Original Morton exterior draft, mapped base and photo-fit Wells-side upper court."""
import bpy,math,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,line,arch,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Morton pale stone base and attic',(.60,.56,.46),roughness=.9)
brick=material('Morton red brick shaft',(.43,.23,.16),roughness=.95)
green=material('Morton green terra cotta panels',(.20,.34,.28),roughness=.65)
metal=material('Morton dark window sashes',(.13,.14,.13),roughness=.8)
glass=material('Morton recessed blue grey panes',(.14,.21,.25),roughness=.55)
night=material('Night occupied Morton panes',(.14,.21,.25),roughness=.55,glow=.2)
roof=material('Morton dark roof and interior',(.095,.09,.085),roughness=.95)
iron=material('Morton dark hung balcony iron',(.29,.17,.14),roughness=.85)
cx,cz=-813.5,136.65
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w147095676')
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
# Batch the repeated facade boxes so Blender does not manage thousands of separate objects.
facade_batches={}
def part(name,pos,size,mat,a,b):
 vertices,faces=facade_batches.setdefault(mat.name,([],[]))
 x,y,z=pos;sx,sy,sz=(v/2 for v in size)
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 offset=len(vertices)
 for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
  u,v=x+dx*sx,y+dy*sy
  vertices.append((a[0]+u*tx+v*ty,a[1]+u*ty-v*tx,z+dz*sz))
 faces.extend(tuple(offset+i for i in reversed(face)) for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])


prism('Retained seven point foundation',plan,-8,0,stone)
# shortcut: court opening and depth are photo-fit, replace with surveyed roof plan before full fidelity acceptance.
upper=[(-15,-28),(16,-28),(16,-12),(-1,-12),(-1,10),(15,10),(15,28),(-15,28)]
assert sum(x*v-y*u for (x,y),(u,v) in zip(upper,upper[1:]+upper[:1]))>0
prism('Four storey recessed base interior',[(x*.96,y*.96) for x,y in plan],4.35,17.4,roof)
prism('Upper U shaped interior backing',[(x*.98,y*.98) for x,y in upper],17.4,91.3,roof)
prism('Open court floor',upper,17.1,17.4,roof)
prism('U wing service roof',upper,91.2,91.5,roof)
PITCH=4.35
for ring,start,end in [(plan,0,4),(upper,4,21)]:
 for a,b in zip(ring,ring[1:]+ring[:1]):
  width=math.dist(a,b);bays=max(1,round(width/3.8));bay=width/bays
  front=a[1]<-26 and b[1]<-26
  east=a[0]>14 and b[0]>14
  if start==0:
   spans=[(width/2,width)] if not front else [((width-5)/4,(width-5)/2),(width-(width-5)/4,(width-5)/2)]
   for x0,span in spans:part('Ground interior backing outside entry',(x0,-.70,2.175),(span,.08,4.35),stone if front else roof,a,b)
  for row in range(start,end):
   z=row*PITCH
   if front and row==0:
    span=(width-5)/2
    for x0 in (span/2,width-span/2):part('Entry flanking base spandrel',(x0,0,.55),(span,.32,1.1),stone,a,b)
   else:part('Brick or stone floor spandrel',(width/2,0,z+.55),(width,.32,1.1),stone if row<4 else brick,a,b)
   for j in range(bays):
    x=(j+.5)*bay
    if front and row==0 and abs(x-width/2)<3:continue
    panel=(front or east) and (j in [0,bays-1] or abs(j-(bays-1)/2)<1.6)
    if row>=4 and panel:
     part('Green terra cotta spandrel',(x,.20,z+.55),(bay-.6,.12,.85),green,a,b)
     for dx in (-bay/2+.3,bay/2-.3):part('Green vertical panel band',(x+dx,.20,z+2.2),(.12,.12,4.35),green,a,b)
    part('Recessed paired dark interior',(x,-.35,z+2.65),(2.45,.06,2.8),roof,a,b)
    for dx in (-.57,.57):part('Physical recessed paired pane',(x+dx,-.22,z+2.65),(1.04,.05,2.65),night if (row*13+j*7)%31==3 else glass,a,b)
    for dx in (-1.15,0,1.15):part('Window sash',(x+dx,-.12,z+2.65),(.06,.18,2.78),metal,a,b)
    for zz in (z+1.22,z+4.08):part('Physical sill or lintel',(x,.03,zz),(2.5,.38,.16),stone if row<4 else brick,a,b)
    part('Continuous facade pier',(j*bay,.02,z+2.175),(.58,.38,4.35),stone if row<4 else brick,a,b)
    if front and row>=5 and j in [1,bays-2]:
     # Rounded balcony noses are visible in the south street photograph.
     outline=[(x+2.35*math.cos(t*math.pi/24),.25+2.2*math.sin(t*math.pi/24)) for t in range(25)]
     assert len(outline)==25 and max(y for _,y in outline)==2.45
     orient(prism('Curved hung balcony slab',outline,z+1.15,z+1.31,iron),a,b)
     tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
     railing=[(a[0]+u*tx+v*ty,a[1]+u*ty-v*tx,z+2.25) for u,v in outline]
     line('Curved physical balcony top rail',railing,.035,iron)
     for u,v in outline:part('Curved balcony upright',(u,v,z+1.78),(.035,.035,1.05),iron,a,b)
   part('Facade end pier',(width,.02,z+2.175),(.58,.38,4.35),stone if row<4 else brick,a,b)
  if start==0 and front:
   # shortcut: entrance shape follows labeled photo; bay position/dimensions need a wider surveyed street view.
   x=width/2
   part('Dark entrance interior',(x,-1.35,1.8),(3.9,.08,3.6),roof,a,b)
   for dx in (-2.15,2.15):part('Stone entrance jamb',(x+dx,-.45,2.05),(.70,1.25,4.1),stone,a,b)
   part('Recessed entrance soffit',(x,-.50,3.65),(3.6,1.15,.16),stone,a,b)
   for dx in (-1.4,-.58,.58,1.4):part('Glazed entrance leaf or sidelight',(x+dx,-1.0,1.35),(.45 if abs(dx)>1 else 1.03,.055,2.55),glass,a,b)
   part('Entrance glazed transom',(x,-1.0,3.03),(3.6,.055,.62),glass,a,b)
   for dx in (-1.8,-1.05,0,1.05,1.8):part('Entrance bronze mullion',(x+dx,-.92,1.75),(.075,.16,3.5),metal,a,b)
   for zz in (.08,2.65,3.4):part('Entrance bronze horizontal rail',(x,-.92,zz),(3.7,.16,.07),metal,a,b)
   for dx in (-.15,.15):part('Physical door pull',(x+dx,-.80,1.25),(.035,.11,.65),metal,a,b)
   for zz,w,depth,h in [(3.85,4.7,.38,.22),(4.02,4.9,.48,.16),(4.20,4.8,.28,.15)]:part('Green metal entrance cornice',(x,depth,zz),(w,.32,h),green,a,b)
   for dx in (-2.55,2.55):
    part('Wall light mounting plate',(x+dx,.15,2.25),(.22,.22,1.05),metal,a,b)
    part('Warm entrance wall light',(x+dx,.30,2.25),(.12,.12,.80),night,a,b)
   for dx in (-1.6,1.6):
    part('Dark entrance planter',(x+dx,1.05,.36),(.60,.60,.72),roof,a,b)
    for k in range(15):
     t=k*2*math.pi/15;u=x+dx+.27*math.cos(t);v=1.05+.27*math.sin(t)
     orient(mesh('Original planter leaf',[(x+dx,1.05,.65),(u-.045,v,1.30),(u,v,1.70),(u+.045,v,1.30)],[(0,1,2),(0,2,3)],green),a,b)
  if start==0:
   for zz in (4.4,17.1):part('Wrapping base stone cornice',(width/2,.38,zz),(width,.60,.36),stone,a,b)
   for j in range(bays+1):
    x=j*bay
    for zz in (7,10,13,16):part('Banded base pier',(x,.30,zz),(.72,.24,.16),stone,a,b)
    part('Base Egyptian capital block',(x,.32,16.6),(.96,.55,.45),stone,a,b)
    # shortcut: lotus fan relief is an original stylized fit; measured carving profiles remain future fidelity work.
    for dx in (-.26,-.13,0,.13,.26):
     leaf=[(x+dx*.4,.63,15.70),(x+dx-.065,.65,16.35),(x+dx,.69,16.65),(x+dx+.065,.65,16.35)]
     orient(mesh('Physical lotus capital fan',leaf,[(0,1,2),(0,2,3)],stone),a,b)
   for row in (1,2):
    for j in range(bays):
     x=(j+.5)*bay;zz=row*PITCH+.52
     part('Inset stone base spandrel panel',(x,.22,zz),(2.35,.06,.72),stone,a,b)
     for dx in (-1.18,1.18):part('Raised panel side moulding',(x+dx,.28,zz),(.06,.11,.80),stone,a,b)
     for dz in (-.40,.40):part('Raised panel horizontal moulding',(x,.28,zz+dz),(2.42,.11,.06),stone,a,b)
  if start==4:part('Wing parapet cornice',(width/2,.28,91.35),(width,.55,.30),stone,a,b)
# Raised southern attic visible in the reference photo, with physical circular stone surrounds.
box('Raised attic red brick',(0,-23,94.5),(24,9,6),brick)
for x in (-9,-4.5,0,4.5,9):
 arch('Attic oculus and wreath ring',.68,.94,(x,95.0),-27.65,.30,stone,start=0,end=2*math.pi,segments=48)
 box('Oculus dark backing',(x,-27.6,95), (1.25,.06,1.25),roof)
for zz,w,d,h in [(97.4,24.5,9.5,.35),(98.0,25.0,10,.45),(99.1,25.6,10.6,.8)]:box('Raised Egyptian attic cornice',(0,-23,zz),(w,d,h),stone)
for name,(vertices,faces) in facade_batches.items():
 assert len(vertices)%8==0 and len(faces)*4==len(vertices)*3,name
 mesh('Batched Morton facade '+name,vertices,faces,bpy.data.materials[name])
assert len(plan)==7 and len(upper)==8
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z+o.location.z<=99.51 for v in o.data.vertices),o.name
finish('morton_building',OUT)
