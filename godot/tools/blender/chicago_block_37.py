"""Block 37 draft: retained compound base, roof-raster tiers and physical woven podium."""
import bpy,math,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,line,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Block37 pale podium piers',(.61,.60,.55),roughness=.85)
metal=material('Block37 silver curtain wall frames',(.49,.54,.57),metallic=.2,roughness=.75)
panel=material('Block37 woven silver steel panels',(.57,.60,.61),metallic=.3,roughness=.8)
glass=material('Block37 recessed blue grey panes',(.15,.24,.31),roughness=.38)
night=material('Night occupied Block37 panes',(.15,.24,.31),roughness=.38,glow=.2)
clear=material('Clear Block37 recessed storefront glazing',(.29,.37,.40),roughness=.5)
clear.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.18
roof=material('Block37 dark backing and roof',(.07,.08,.09),roughness=.9)
bronze=material('Block37 warm tower inset panels',(.45,.27,.13),metallic=.3,roughness=.6)
cx,cz=-357.2,104.25
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w124865494')
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



def rectangle(x0,z0,x1,z1):
 return [(x0-cx,-(z1-cz)),(x1-cx,-(z1-cz)),(x1-cx,-(z0-cz)),(x0-cx,-(z0-cz))]
# shortcut: tower envelopes follow the 2m roof raster; refine corners and crown against measured plans before acceptance.
tower=rectangle(-405,47,-317,73)
office=rectangle(-403,125,-336,161)
assert all(-52<x<52 and -61<y<61 for poly in (tower,office) for x,y in poly)
prism('Retained mapped compound foundation',plan,-8,0,stone)
prism('Recessed podium interior',[(x*.98,y*.98) for x,y in plan],0,25.7,roof)
prism('Retail roof',plan,25.7,26,roof)
def facade(poly,bottom,top,rows,woven=False):
 pitch=(top-bottom)/rows
 assert pitch>2.5
 for a,b in zip(poly,poly[1:]+poly[:1]):
  width=math.dist(a,b);bays=max(1,round(width/(4.8 if woven else 2.4)));bay=width/bays
  state_front=woven and a[0]>48 and b[0]>48
  for row in range(rows):
   z=bottom+row*pitch
   part('Floor spandrel',(width/2,-.12,z+.28),(width,.16,.56),metal,a,b)
   for j in range(bays):
    x=(j+.5)*bay
    if state_front and row==0:
     # shortcut: tenant-door spacing is photo-fit; calibrate bays against a complete State Street elevation.
     entrance=j in (2,7,13,20)
     if entrance:
      flank=(bay-2.2)/2
      assert flank>.8
      for dx in (-.54,.54):part('Individual recessed retail door pane',(x+dx,-.45,1.50),(1.0,.05,2.72),clear,a,b)
      for dx in (-1.1-flank/2,1.1+flank/2):part('Door flanking showcase pane',(x+dx,-.45,1.80),(flank-.10,.05,3.35),clear,a,b)
      part('Separate paired door transom pane',(x,-.45,3.19),(2.10,.05,.52),clear,a,b)
     else:
      for dx in (-bay/4,bay/4):part('Clear individual storefront pane',(x+dx,-.45,1.80),(bay/2-.10,.05,3.35),clear,a,b)
     for dx in ((-bay/2+.04,-1.08,0,1.08,bay/2-.04) if entrance else (-bay/2+.04,0,bay/2-.04)):
      part('Shopfront silver ground jamb',(x+dx,-.32,1.80),(.065,.20,3.55),metal,a,b)
     part('Shopfront door transom rail',(x,-.32,2.85),(bay-.07,.20,.07),metal,a,b)
     part('Shopfront lower rail',(x,-.32,.13),(bay-.07,.20,.07),metal,a,b)
     if entrance:
      for dx in (-.16,.16):part('Paired recessed door pull',(x+dx,-.18,1.50),(.035,.08,.55),metal,a,b)
     part('Shopfront display ceiling',(x,-.67,3.65),(bay-.10,.50,.10),roof,a,b)
     part('Night shopfront soffit fixture',(x,-.57,3.58),(.35,.20,.035),night,a,b)
    else:
     part('Separate physical curtain pane',(x,-.25,z+pitch/2+.28),(bay-.09,.05,pitch-.65),night if (row*19+j*7)%37==3 else glass,a,b)
    part('Vertical curtain mullion',(j*bay,-.10,z+pitch/2),(.065,.22,pitch),metal,a,b)
   part('End curtain mullion',(width,-.10,z+pitch/2),(.065,.22,pitch),metal,a,b)
   part('Horizontal curtain rail',(width/2,-.08,z+pitch-.04),(width,.23,.08),metal,a,b)
  if state_front:
   part('Continuous shallow storefront soffit',(width/2,.12,3.85),(width,.70,.18),metal,a,b)
   for k in range(16):part('Individual horizontal ground ventilation louvre',(width/2,.01,4.05+k*.085),(width,.16,.035),roof,a,b)
   part('Ventilation fascia upper rail',(width/2,.02,5.40),(width,.20,.09),metal,a,b)
  if woven:
   for j in range(bays+1):part('Tall stone podium pier',(j*bay,.04,(bottom+top)/2),(.36,.42,top-bottom),stone,a,b)
   # Photo shows alternating bowed strips with gaps, not a flat metal texture.
   if width>30:
    for row in range(48):
     z=7.5+row*.34
     for j in range(1,bays-1):
      x=(j+.5)*bay
      points=[]
      for k in range(9):
       u=x-bay*.49+bay*.98*k/8
       depth=.25+.40*math.sin(k*math.pi/8)*(1 if (j+row)%2 else -1)
       points.extend([(u,depth,z),(u,depth,z+.30)])
      obj=mesh('Bowed woven metal strip',points,[(2*k,2*k+2,2*k+3,2*k+1) for k in range(8)],panel)
      orient(obj,a,b)
facade(plan,0,26,4,True)
# Seventeen total office stories leave thirteen shaft rows above the four modeled base rows.
for poly,top,rows in [(tower,130,37),(office,80,13)]:
 mx=sum(x for x,y in poly)/len(poly);my=sum(y for x,y in poly)/len(poly)
 assert min(math.dist(a,b) for a,b in zip(poly,poly[1:]+poly[:1]))*.02>.25
 prism('Tower recessed interior',[(mx+(x-mx)*.96,my+(y-my)*.96) for x,y in poly],26,top-.25,roof)
 facade(poly,26,top,rows)
 prism('Tower service roof',poly,top-.25,top,roof)
# shortcut: fascia depth/height follow the engineer's photo; replace with measured coping sections when available.
for a,b in zip(office,office[1:]+office[:1]):
 width=math.dist(a,b)
 part('Office broad dark projecting roof fascia',(width/2,.18,78.55),(width,.70,2.90),roof,a,b)
 part('Office silver coping edge',(width/2,.18,79.95),(width,.74,.10),metal,a,b)
# shortcut: rooftop unit positions/heights are overhead-photo fits; replace with surveyed equipment sections when available.
for wx in (-366,-358,-350,-342):
 for wz in (130,147):
  x,y=wx-cx,-(wz-cz)
  box('Office rooftop unit plinth',(x,y,80.25),(5.4,5.4,.5),roof)
  bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=2.3,depth=1.8,location=(x,y,81.4))
  obj=bpy.context.object;obj.name='Office circular rooftop housing';obj.data.materials.append(stone)
  bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=1.8,depth=.05,location=(x,y,82.325))
  obj=bpy.context.object;obj.name='Office dark circular intake';obj.data.materials.append(roof)
  line('Office intake rim',[(x+1.9*math.cos(k*math.tau/24),y+1.9*math.sin(k*math.tau/24),82.35) for k in range(25)],.08,metal)
  for d in (-.9,-.45,0,.45,.9):
   box('Office intake grille',(x+d,y,82.38),(.05,2*math.sqrt(1.7**2-d*d),.05),metal)
for wx,wz,sx,sy in [(-374,140,5,12),(-361,138,5,5),(-347,138,5,5)]:
 box('Office rectangular roof service housing',(wx-cx,-(wz-cz),81.1),(sx,sy,2.2),metal)
# SCB photograph shows warm elongated inset panels across the long northern tower face.
a,b=tower[2],tower[3]
width=math.dist(a,b)
for j,z in [(1,45),(4,58),(8,75),(12,95),(16,114),(22,123),(28,87)]:
 if (j+1)*2.4<width:
  part('Warm elongated tower inset',((j+.5)*2.4,.02,z),(1.7,.16,5.6),bronze,a,b)
for name,(vertices,faces) in facade_batches.items():
 assert len(vertices)%8==0 and len(faces)*4==len(vertices)*3,name
 mesh('Batched '+name,vertices,faces,bpy.data.materials[name])
finish('block_37',OUT)
