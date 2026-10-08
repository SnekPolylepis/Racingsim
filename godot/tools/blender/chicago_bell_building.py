"""Original Bell Building exterior draft: NPS tripartite facade and mapped L foundation."""
import bpy,math,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,arch,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Bedford limestone base and crown',(.61,.57,.47),roughness=.9)
brick=material('Warm brown brick shaft',(.36,.24,.17),roughness=.95)
terra=material('Pale terra cotta surrounds',(.58,.49,.35),roughness=.87)
metal=material('Dark bronze window sashes',(.15,.13,.105),roughness=.8)
glass=material('Recessed blue grey panes',(.15,.23,.26),roughness=.55)
night=material('Night occupied Bell panes',(.15,.23,.26),roughness=.55,glow=.2)
roof=material('Dark service roof and mortar',(.11,.105,.09),roughness=.95)
clear=material('Clear recessed entrance glazing',(.29,.35,.36),roughness=.5)
clear.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.18
iron=material('Physical iron balcony rails',(.10,.115,.105),roughness=.85)
cx,cz=-850.25,136.7
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w147095658')
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


prism('Retained six vertex L foundation',plan,-8,0,stone)
# shortcut: 82m main roof follows dominant 2m returns; measured crown/service elevations will replace photo-fit heights.
H,PITCH=82.,4.1
prism('Inset brick shaft and crown backing',[(x*.97,y*.97) for x,y in plan],12.3,81.6,roof)
prism('Main recessed service roof',plan,81.4,81.6,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b);bays=max(1,round(width/3.9));bay=width/bays
 front=a[1]<-26 and b[1]<-26
 for row in range(20):
  z=row*PITCH;mat=stone if row<3 else brick
  pier_mat=stone if row<3 or row>=16 else brick
  solid_width=width-10 if front and row==0 else width
  part('Physical tripartite spandrel',(solid_width/2,0,z+.5),(solid_width,.34,1),mat,a,b)
  for j in range(bays):
   x=(j+.5)*bay
   portal=front and row==0 and x>width-10
   if not portal:
    part('Dark interior behind paired glazing',(x,-.35,z+2.4),(2.4,.055,2.85),roof,a,b)
    for k in (-1,1):
     part('Separate recessed paired window',(x+k*.56,-.24,z+2.4),(1.02,.055,2.70),night if (row*11+j*7)%29==2 else glass,a,b)
    part('Window central sash',(x,-.12,z+2.4),(.065,.14,2.80),metal,a,b)
    for dx in (-1.12,1.12):part('Projecting window reveal',(x+dx,-.02,z+2.4),(.18,.32,2.95),terra if 3<=row<16 else stone,a,b)
    for zz in (z+1,z+3.85):part('Physical window sill and lintel',(x,.08,zz),(2.46,.40,.20),terra if 3<=row<16 else stone,a,b)
   if not (front and row==0 and j*bay>width-10):
    part('Tripartite bay pier',(j*bay,.02,z+2.05),(.66,.40,4.1),pier_mat,a,b)
  part('Tripartite end pier',(width,.02,z+2.05),(.66,.40,4.1),pier_mat,a,b)
  if row<3:
   for zz in [z+.32+i*.44 for i in range(9)]:
    for j in range(bays+1):
     if j*bay<=solid_width:part('Rusticated stone pier band',(j*bay,.22,zz),(.70,.08,.055),stone,a,b)
  if 3<=row<16:
   for zz in [z+.12+i*.28 for i in range(4)]:part('Fine brick spandrel bed joint',(width/2,.18,zz),(width,.015,.018),roof,a,b)
 for j in range(bays+1):
  x=j*bay
  for dx in (-.20,0,.20):
   part('Physical fluted crown pilaster ridge',(x+dx,.26,73.65),(.065,.14,14.8),stone,a,b)
 for zz,depth,h in [(12.1,.48,.32),(65.5,.45,.32),(80.5,.50,.30),(81.0,.67,.24),(81.6,.83,.30)]:
  part('Projected stone belt or cornice',(width/2,depth,zz),(width,.40,h),stone,a,b)
 for j in range(bays):
  for dx in (-.15,0,.15):part('Crown triglyph vertical ridge',((j+.5)*bay+dx,.69,80.0),(.06,.12,.55),stone,a,b)
 if front:
  for x in (width-7.8,width-4.0):
   orient(arch('Recessed double entrance stone arch',1.4,1.78,(x,2.35),.08,.34,stone),a,b)
   for dx in (-1.59,1.59):part('Portal banded stone jamb',(x+dx,.15,1.17),(.36,.50,2.35),stone,a,b)
   part('Dark recessed portal interior',(x,-1.40,1.95),(2.8,.055,3.9),roof,a,b)
   for dx in (-1.42,1.42):part('Entrance recess side wall',(x+dx,-.55,1.9),(.12,1.65,3.8),stone,a,b)
   part('Deep recessed double portal glazing',(x,-1.25,1.85),(2.7,.07,3.65),clear,a,b)
   part('Portal central bronze door stile',(x,-1.16,1.5),(.08,.15,3),metal,a,b)
   for zz in (4.4,8.5):
    part('Entrance bracket supported balcony',(x,.67,zz),(3.3,1.40,.20),stone,a,b)
    for dx in (-1.1,1.1):part('Physical entrance balcony bracket',(x+dx,.48,zz-.45),(.27,.80,.70),stone,a,b)
  # shortcut: visible continuous balcony stacks are photo-fit; survey actual widths and floor coverage before acceptance.
  for row in range(5,20):
   for j in range(1,bays-1,3):
    x=(j+.5)*bay;z=row*PITCH+.90
    part('Added residential balcony slab',(x,.55,z),(4.0,1.55,.16),iron,a,b)
    for dx in (-1.97,1.97):part('Balcony side rail post',(x+dx,1.30,z+.55),(.045,.045,1.1),iron,a,b)
    part('Open balcony top rail',(x,1.30,z+1.1),(4.0,.055,.055),iron,a,b)
    for k in range(17):part('Physical balcony picket',(x-1.92+k*.24,1.30,z+.53),(.025,.025,1.04),iron,a,b)
box('Provisional rooftop service enclosure',(10,7,84.5),(7,12,5.8),roof)
for name,(vertices,faces) in facade_batches.items():
 assert len(vertices)%8==0 and len(faces)*4==len(vertices)*3,name
 mesh('Batched physical facade '+name,vertices,faces,bpy.data.materials[name])
assert len(plan)==6 and abs(PITCH*20-H)<.001
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z+o.location.z<=91.51 for v in o.data.vertices),o.name
finish('bell_building',OUT)
