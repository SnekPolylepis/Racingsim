"""Original 311 South Wacker draft, mapped foundation and LiDAR-guided stepped masses."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, line, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Flamed Texas red granite',(.59,.38,.31),roughness=.88)
strap=material('Polished red granite strapping',(.39,.23,.19),roughness=.62)
metal=material('Pale silver window frames',(.59,.65,.64),metallic=.2,roughness=.68)
glass=material('Recessed blue office glass',(.13,.23,.28),roughness=.5)
occupied=material('Night occupied office glass',(.13,.23,.28),roughness=.5,glow=.2)
dark=material('Dark mechanical and roof recesses',(.07,.085,.085),roughness=.85)
crown=material('Night translucent crown glazing',(.52,.55,.44),roughness=.65,glow=.2)
clear=material('Clear winter garden glazing',(.28,.39,.40),roughness=.45)
clear.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.18
white=material('Pale winter garden steel and columns',(.72,.74,.68),roughness=.75)
light=material('Night winter garden fixtures',(.77,.68,.46),roughness=.7,glow=.2)
leaf=material('Winter garden palm foliage',(.13,.25,.095),roughness=.95)
trunk=material('Palm trunks and fountain bronze',(.27,.16,.085),roughness=.9)
water=material('Still fountain water',(.14,.26,.29),roughness=.45)
cx,cz=-928.0,817.0
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w147350208')
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
prism('Retained twenty two vertex foundation',plan,-8,.10,stone)
# ponytail: roof masses follow 2m LiDAR and photos; measured facade/crown elevations will replace these draft proportions.
main=[(-21,7),(-15,20),(0,22),(15,16),(20,2),(15,-14),(0,-22),(-15,-16)]
if sum(x*v-y*u for (x,y),(u,v) in zip(main,main[1:]+main[:1]))<0:main.reverse()
BASE,TOP=12.,292.5
prism('Recessed octagonal office backing',[(x*.96,y*.96) for x,y in main],BASE,262,dark)
prism('Octagonal service roof',main,261.6,262,dark)
def facade(poly,top,rows):
 pitch=(top-BASE)/rows
 for a,b in zip(poly,poly[1:]+poly[:1]):
  width=math.dist(a,b);bays=max(1,round(width/5.7));bay=width/bays
  for row in range(rows):
   z=BASE+row*pitch
   band=row in (9,10,42,43)
   part('Granite office spandrel',(width/2,.01,z+.8),(width,.35,1.6),strap if band else stone,a,b)
   for j in range(bays):
    h=(j+.5)*bay;pane=(bay-.55)/3
    for k in range(3):
     x=h+(k-1)*(pane+.055)
     mat=dark if band else occupied if (row*13+j*7+k)%37 in (2,11,19) else glass
     part('Separate grouped recessed office pane',(x,-.25,z+2.7),(pane,.055,pitch-1.87),mat,a,b)
     for dx in (-pane/2,pane/2):part('Pale physical pane jamb',(x+dx,-.13,z+2.7),(.055,.13,pitch-1.75),metal,a,b)
     for zz in (z+1.69,z+pitch-.10):part('Pale office rail',(x,-.13,zz),(pane,.13,.065),metal,a,b)
    part('Granite bay pier',(j*bay,.09,z+pitch/2),(.43,.42,pitch),stone,a,b)
   part('Granite end pier',(width,.09,z+pitch/2),(.43,.42,pitch),stone,a,b)
  for z in (BASE,BASE+10*pitch,BASE+43*pitch,top):part('Polished horizontal granite strap',(width/2,.10,z),(width,.46,.26),strap,a,b)
  for j in range(bays+1):
   h=j*bay
   part('Dense granite podium column',(h,0,6),(.60,.55,12),stone,a,b)
  for row in range(3):
   for j in range(bays):
    h=(j+.5)*bay
    for k in range(3):
     pane=(bay-.6)/3;x=h+(k-1)*(pane+.045)
     part('Recessed three level podium pane',(x,-.80,2+row*4),(pane,.06,3.45),glass,a,b)
     for dx in (-pane/2,pane/2):part('Podium silver mullion',(x+dx,-.69,2+row*4),(.075,.16,3.55),metal,a,b)
   part('Podium polished granite course',(width/2,.06,4*(row+1)),(width,.40,.50),strap,a,b)
facade(main,262,62)
# The two lower eastern blade masses are distinct from the higher octagonal tower.
for side in (-1,1):
 poly=[(5,side*18),(19.2,side*18),(19.2,side*34),(5,side*34)]
 if sum(x*v-y*u for (x,y),(u,v) in zip(poly,poly[1:]+poly[:1]))<0:poly.reverse()
 prism('Recessed lower blade backing',[(x-.15,y-side*.15) for x,y in poly],BASE,225,dark)
 prism('Lower blade service roof',poly,224.7,225,dark)
 facade(poly,225,52)
 for x in (5,19.2):box('Lower blade projecting Gothic pier',(x,side*34,222),(.65,.65,12),stone)
# Crown cylinders contain discrete curved glazing panes, ribs, ties and open finials.
def cylinder(x,y,radius,bottom,top):
 for i in range(64):
  a=i*math.tau/64;b=(i+1)*math.tau/64
  p=(x+radius*math.cos(a),y+radius*math.sin(a));q=(x+radius*math.cos(b),y+radius*math.sin(b))
  mesh('Separate curved crown glass',[(p[0],p[1],bottom),(q[0],q[1],bottom),(q[0],q[1],top),(p[0],p[1],top)],[(0,1,2,3)],crown)
  if i%4==0:line('Crown vertical steel rib',[(p[0],p[1],bottom),(p[0],p[1],top+1.5)],.08,white)
 for z in (bottom,top-8,top):line('Crown circular horizontal tie',[(x+(radius+.04)*math.cos(i*math.tau/96),y+(radius+.04)*math.sin(i*math.tau/96),z) for i in range(97)],.11,white)
 for i in range(16):
  a=i*math.tau/16
  line('Raised crown finial',[(x+radius*math.cos(a),y+radius*math.sin(a),top),(x+radius*math.cos(a),y+radius*math.sin(a),top+2.5)],.12,white)
cylinder(0,0,10.2,262,290)
for x in (-12,12):
 for y in (-12,12):
  cylinder(x,y,6.2,262,279)
  # The outward granite portals remain open around the smaller glazed cylinders.
  for axis,sign in ((0,math.copysign(1,x)),(1,math.copysign(1,y))):
   for offset in (-4.2,4.2):
    pos=(x+sign*6.35,y+offset,270) if axis==0 else (x+offset,y+sign*6.35,270)
    box('Corner crown granite portal pier',pos,(1.0,1.0,19),stone)
   pos=(x+sign*6.35,y,279) if axis==0 else (x,y+sign*6.35,279)
   size=(1.05,9.4,1.0) if axis==0 else (9.4,1.05,1.0)
   box('Corner crown open portal architrave',pos,size,strap)
for side in (-1,1):
 for axis in (0,1):
  for offset in (-4.2,4.2):
   pos=(side*10.35,offset,274.0) if axis==0 else (offset,side*10.35,274.0)
   box('Central crown projecting granite portal pier',pos,(1.0,1.0,24),stone)
  pos=(side*10.35,0,285.5) if axis==0 else (0,side*10.35,285.5)
  size=(1.05,9.4,1.0) if axis==0 else (9.4,1.05,1.0)
  box('Central crown open portal architrave',pos,size,strap)
# Western winter garden wing stays within the mapped nine-by-forty-metre half-span corridor.
WEST,EAST,Y0,HALF=-70.5,-30.5,-1.0,9.5
for y in (Y0-HALF,Y0+HALF):
 for i in range(17):
  x=WEST+i*(EAST-WEST)/16
  box('Winter garden granite base column',(x,y,6),(.45,.45,12),stone)
  box('Upper winter garden steel column',(x,y,16.25),(.16,.16,8.5),white)
 for i in range(16):
  x=WEST+(i+.5)*(EAST-WEST)/16
  box('Separate winter garden clerestory pane',(x,y,16.25),(2.40,.06,8.25),clear)
  box('Separate winter garden ground pane',(x,y,6.1),(2.35,.06,11.55),clear)
 for z in (4,8,12):box('Wing polished horizontal course',((WEST+EAST)/2,y,z),(40,.45,.32),strap)
# Real curved glass roof and open arched trusses, based on the architect's exterior/interior photos.
for i in range(16):
 x=WEST+i*(EAST-WEST)/16;u=WEST+(i+1)*(EAST-WEST)/16
 for k in range(24):
  a=k*math.pi/24;b=(k+1)*math.pi/24
  y=Y0+HALF*math.cos(a);v=Y0+HALF*math.cos(b);z=20.5+5.4*math.sin(a);w=20.5+5.4*math.sin(b)
  mesh('Separate curved winter garden roof pane',[(x,y,z),(u,y,z),(u,v,w),(x,v,w)],[(3,2,1,0)],clear)
 if i%2==0:line('Winter garden open arched roof rib',[(x,Y0+HALF*math.cos(k*math.pi/48),20.5+5.4*math.sin(k*math.pi/48)) for k in range(49)],.16,white)
for y in (Y0-6,Y0,Y0+6):
 z=20.5+5.4*math.sqrt(1-((y-Y0)/HALF)**2)
 line('Winter garden longitudinal roof tie',[(WEST,y,z),(EAST,y,z)],.12,white)
for x in (WEST,EAST):
 for j in range(12):
  y=Y0-HALF+(j+.5)*2*HALF/12;top=20.5+5.4*math.sqrt(max(0,1-((y-Y0)/HALF)**2))
  box('Tall glazed winter garden end pane',(x,y,top/2),(.06,1.50,top-.2),clear)
  box('Winter garden end mullion',(x+.08,y-.79,top/2),(.16,.10,top),white)
box('Winter garden stone floor',((WEST+EAST)/2,Y0,.14),(40,19,.12),stone)
for x in (-65,-57,-49,-41,-33):
 for y in (-7,5):
  line('Winter garden palm trunk',[(x,y,.2),(x+.12,y,8)],.16,trunk)
  for k in range(18):
   a=k*math.tau/18
   points=[(x,y,8),(x+1.5*math.cos(a),y+1.5*math.sin(a),9),(x+3*math.cos(a),y+3*math.sin(a),7.3)]
   line('Palm frond centre rib',points,.035,leaf)
   mesh('Physical palm leaf',[(x,y,8),(x+1.5*math.cos(a)-.20*math.sin(a),y+1.5*math.sin(a)+.20*math.cos(a),9),(x+3*math.cos(a),y+3*math.sin(a),7.3),(x+1.5*math.cos(a)+.20*math.sin(a),y+1.5*math.sin(a)-.20*math.cos(a),9)],[(0,1,2),(0,2,3)],leaf)
  box('Recessed winter garden ceiling light',(x,y,19.9),(1.6,.12,.04),light)
# ponytail: do not invent the Gem of the Lakes sculpture; add its distinct form from close reference in the next fidelity pass.
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=2.4,depth=.4,location=(-50,Y0,.45));bpy.context.object.name='Winter garden fountain basin';bpy.context.object.data.materials.append(trunk)
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=2.15,depth=.04,location=(-50,Y0,.67));bpy.context.object.name='Still fountain surface';bpy.context.object.data.materials.append(water)
for name,(vertices,faces) in facade_batches.items():
 assert len(vertices)%8==0 and len(faces)*4==len(vertices)*3,name
 mesh('Batched physical facade '+name,vertices,faces,bpy.data.materials[name])
print('Geometry authored; exporting',flush=True)
assert len(plan)==22 and len(main)==8
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z+o.location.z<=TOP+.01 for v in o.data.vertices),o.name
finish('wacker_311',OUT)
