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
  for row in range(rows):
   z=bottom+row*pitch
   part('Floor spandrel',(width/2,-.12,z+.28),(width,.16,.56),metal,a,b)
   for j in range(bays):
    x=(j+.5)*bay
    part('Separate physical curtain pane',(x,-.25,z+pitch/2+.28),(bay-.09,.05,pitch-.65),night if (row*19+j*7)%37==3 else glass,a,b)
    part('Vertical curtain mullion',(j*bay,-.10,z+pitch/2),(.065,.22,pitch),metal,a,b)
   part('End curtain mullion',(width,-.10,z+pitch/2),(.065,.22,pitch),metal,a,b)
   part('Horizontal curtain rail',(width/2,-.08,z+pitch-.04),(width,.23,.08),metal,a,b)
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
for poly,top,rows in [(tower,130,37),(office,80,17)]:
 mx=sum(x for x,y in poly)/len(poly);my=sum(y for x,y in poly)/len(poly)
 assert min(math.dist(a,b) for a,b in zip(poly,poly[1:]+poly[:1]))*.02>.25
 prism('Tower recessed interior',[(mx+(x-mx)*.96,my+(y-my)*.96) for x,y in poly],26,top-.25,roof)
 facade(poly,26,top,rows)
 prism('Tower service roof',poly,top-.25,top,roof)
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
