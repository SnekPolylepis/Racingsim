"""200 South Wacker physical exterior draft; mapped foundation and LiDAR roof tiers."""
import bpy,math,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,line,text,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Pale precast facade panels',(.64,.66,.63),roughness=.87)
metal=material('Projecting silver facade frames',(.48,.53,.55),metallic=.25,roughness=.65)
glass=material('Recessed grey blue office panes',(.18,.25,.29),roughness=.48)
occupied=material('Night occupied office panes',(.18,.25,.29),roughness=.48,glow=.2)
dark=material('Recessed service roof and louvres',(.07,.08,.085),roughness=.9)
clear=material('Clear angled lobby glazing',(.32,.40,.42),roughness=.45)
clear.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.18
light=material('Night entrance fixtures',(.78,.71,.53),glow=.2)
cx,cz=-1076.05,641.75
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w64888042')
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

prism('Retained six vertex mapped foundation',plan,-8,0,stone)
# shortcut: upper tier follows the 2m roof raster, refine the diagonal join and corners when measured rooftop dimensions are available.
upper=[(x-cx,-(z-cz)) for x,z in [(-1100.0,625.8),(-1051.6,617.0),(-1051.6,620.0),(-1090.0,665.8),(-1092.9,666.4)]]
if sum(x*v-y*u for (x,y),(u,v) in zip(upper,upper[1:]+upper[:1]))<0:upper.reverse()
def facade(poly,bottom,top):
 rows=round((top-bottom)/3.7);pitch=(top-bottom)/rows
 for a,b in zip(poly,poly[1:]+poly[:1]):
  width=math.dist(a,b);bays=max(1,round(width/2.5));bay=width/bays
  for row in range(rows):
   z=bottom+row*pitch
   part('Precast horizontal spandrel',(width/2,.02,z+.55),(width,.28,1.10),stone,a,b)
   for j in range(bays):
    x=(j+.5)*bay
    part('Distinct recessed office pane',(x,-.20,z+pitch/2+.55),(bay-.12,.05,pitch-1.23),occupied if (row*17+j*7)%31==2 else glass,a,b)
    part('Physical silver jamb',(j*bay,-.09,z+pitch/2),(.065,.15,pitch),metal,a,b)
   for zz in (z+1.11,z+pitch-.05):part('Projecting horizontal frame',(width/2,-.07,zz),(width,.17,.065),metal,a,b)
prism('Lower tier recessed opaque backing',[(x*.98,y*.98) for x,y in plan],10,122,dark)
facade(plan,10,122)
prism('Upper tier recessed opaque backing',upper,121.8,146.5,dark)
facade(upper,122,146.5)
prism('Lower service roof',plan,121.7,122,dark)
prism('Upper service roof',upper,146.2,146.5,dark)
# Published152.3m and mapped155.5m differ; this roof-service envelope remains provisional.
mechanical=[(x-cx,-(z-cz)) for x,z in [(-1083,651),(-1063,629),(-1072,625),(-1090,647)]]
if sum(x*v-y*u for (x,y),(u,v) in zip(mechanical,mechanical[1:]+mechanical[:1]))<0:mechanical.reverse()
prism('Long diagonal rooftop mechanical enclosure',mechanical,146.5,154.3,dark)
for a,b in zip(mechanical,mechanical[1:]+mechanical[:1]):
 width=math.dist(a,b)
 for z in [147+i*.45 for i in range(17)]:part('Physical diagonal roof enclosure louvre',(width/2,.04,z),(width,.12,.10),metal,a,b)
for x,y in [(12,-13),(15,-9),(9,-16)]:
 box('Lower triangular roof service cabinet',(x,y,122.6),(1.8,1.6,1.2),dark)
 for z in [122.1+i*.18 for i in range(6)]:box('Lower roof cabinet physical louvre',(x+.93,y,z),(.07,1.6,.07),metal)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b);bays=max(1,round(width/5));bay=width/bays
 for j in range(bays+1):part('Tall pale podium column',(j*bay,0,5),(.65,.65,10),stone,a,b)
 for j in range(bays):
  x=(j+.5)*bay
  part('Recessed lobby ground pane',(x,-1.4,1.6),(bay-.7,.06,3),clear,a,b)
  # The architect's interior photo shows angled glazing above the entry level.
  vertices=[]
  for h,depth in [(3.2,-1.4),(7,-.3),(10,-.3)]:
   for xx in (x-bay/2+.35,x+bay/2-.35):
    tx,ty=(b[0]-a[0])/width,(b[1]-a[1])/width
    vertices.append((a[0]+xx*tx+depth*ty,a[1]+xx*ty-depth*tx,h))
  mesh('Physical angled lobby pane',vertices,[(0,1,3,2),(2,3,5,4)],clear)
  part('Lobby mullion',(j*bay,-.30,8.5),(.08,.14,3),metal,a,b)
  part('Entrance soffit light',(x,-1.0,9.75),(1,.5,.04),light,a,b)
# Existing developer entrance photo: suspended glass canopy and extruded corner number.
box('Recessed corner address plaque',(24.88,22.6,3.2),(.10,3.9,1.5),dark)
text('Physical corner entrance number','200',(24.96,22.6,3.15),1.10,stone,rotate=(math.pi/2,0,math.pi/2),depth=.06)
for j in range(4):
 y=18.7+j*1.5
 box('Separate suspended canopy glass pane',(25.05,y+.7,4.25),(1.0,1.38,.065),clear)
 box('Canopy cross steel arm',(25.05,y,4.16),(1.15,.09,.16),metal)
 line('Canopy suspension rod',[(24.65,y,8.6),(25.5,y,4.3)],.028,metal)
box('Canopy outer fascia',(25.57,21.7,4.16),(.10,6.1,.16),metal)
prism('Podium pale soffit',plan,9.8,10,stone)
for name,(vertices,faces) in facade_batches.items():
 assert len(vertices)%8==0 and len(faces)*4==len(vertices)*3,name
 mesh('Batched physical facade '+name,vertices,faces,bpy.data.materials[name])
assert len(plan)==6
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z+o.location.z<=155.51 for v in o.data.vertices),o.name
finish('wacker_200',OUT)
