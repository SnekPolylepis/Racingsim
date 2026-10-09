"""Sharp/Champlain working draft: mapped foundation and physical Chicago windows."""
import bpy,math,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,line,arch,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
brick=material('Sharp warm tan brick',(.45,.38,.28),roughness=.9)
trim=material('Sharp pale terracotta surrounds',(.63,.56,.43),roughness=.85)
metal=material('Sharp dark cast iron window frames',(.10,.12,.11),metallic=.3,roughness=.7)
glass=material('Sharp recessed blue grey panes',(.17,.24,.27),roughness=.4)
night=material('Night occupied Sharp panes',(.17,.24,.27),roughness=.4,glow=.2)
roof=material('Sharp dark recessed interior and roof',(.08,.09,.09),roughness=.95)
cx,cz=-105,423
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w147478374')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
assert len(plan)==9
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



# CVU architectural height61.3m supersedes unverified mapped71.5m; floor-count conflict remains documented.
H=61.3
prism('Sharp mapped buried foundation',plan,-8,0,trim)
prism('Sharp recessed opaque interior',[(x*.94,y*.90) for x,y in plan],0,H-1.5,roof)
prism('Sharp roof slab',plan,H-1.5,H-1.2,roof)
# shortcut: four narrow-face bays follow the restoration photo; long/rear bay counts need fuller elevation evidence.
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b)
 if width<4:continue
 bays=4 if 20<width<26 else max(1,round(width/5.8));bay=width/bays
 for row in range(13):
  bottom=0 if row==0 else 5 if row==1 else 10+(row-2)*(H-12)/11
  top=5 if row==0 else 10 if row==1 else bottom+(H-12)/11
  wh=top-bottom-1.25;z=(top+bottom)/2
  for j in range(bays):
   x=(j+.5)*bay
   part('Sharp brick bay pier',(j*bay,.02,z),(.62,.40,top-bottom),brick,a,b)
   if not (row==0 and a[0]<-25 and b[0]<-25 and j==0):
    part('Sharp masonry floor spandrel',(x,.02,bottom+.5),(bay,.40,1.0),brick,a,b)
   west=a[0]<-25 and b[0]<-25
   if west and row==0:
    # shortcut: northern entrance bay and moldings follow the owner photo; refine against measured frontage before acceptance.
    entry=j==0
    if entry:
     for dx in (-.65,.65):part('Sharp recessed paired entrance door',(x+dx,-.55,1.55),(1.20,.06,2.85),glass,a,b)
     part('Sharp separate entrance transom',(x,-.55,3.45),(2.55,.06,.65),glass,a,b)
     for dx in (-1.36,0,1.36):part('Sharp entrance dark jamb',(x+dx,-.32,1.90),(.12,.32,3.70),metal,a,b)
     for zrail in (.15,3.05,3.85):part('Sharp entrance transom rail',(x,-.32,zrail),(2.8,.32,.12),metal,a,b)
     for dx in (-1.65,1.65):part('Sharp molded entrance surround pier',(x+dx,.20,2.40),(.40,.70,4.80),trim,a,b)
     for zrail in (4.65,4.85):part('Sharp molded portal lintel',(x,.24,zrail),(3.75,.80,.18),trim,a,b)
     part('Sharp physical entry plaque',(x,.03,4.22),(2.50,.12,.50),trim,a,b)
     for dx in (-.16,.16):part('Sharp paired door pull',(x+dx,-.12,1.60),(.04,.10,.60),metal,a,b)
    else:
     for k in range(3):
      u=x+(k-1)*(bay-.8)/3
      part('Sharp ground storefront pane',(u,-.30,1.90),((bay-.8)/3-.10,.06,3.40),glass,a,b)
     part('Sharp broad storefront transom',(x,-.30,4.15),(bay-.80,.06,.70),glass,a,b)
     for dx in (-.5,-1/6,1/6,.5):part('Sharp ground silver frame',(x+dx*(bay-.8),-.10,2.45),(.10,.28,4.65),metal,a,b)
     for zrail in (.15,3.65,4.65):part('Sharp ground storefront rail',(x,-.10,zrail),(bay-.70,.28,.14),metal,a,b)
    continue
   for k in range(3):
    u=x+(k-1)*(bay-.8)/3
    part('Sharp separate tripartite recessed pane',(u,-.24,z+.10),((bay-.8)/3-.08,.04,wh),night if (row*13+j*5+k)%43==4 else glass,a,b)
   for dx in (-.5,-1/6,1/6,.5):
    part('Sharp window frame upright',(x+dx*(bay-.8),-.08,z+.10),(.08,.24,wh+.15),metal,a,b)
   for zz in (z+.10-wh/2,z+.10+wh/2):
    part('Sharp window frame rail',(x,-.08,zz),(bay-.72,.24,.09),metal,a,b)
   part('Sharp projecting terracotta window sill',(x,.16,z+.10-wh/2-.10),(bay-.55,.60,.15),trim,a,b)
   part('Sharp terracotta window head',(x,.08,z+.10+wh/2+.14),(bay-.55,.42,.20),trim,a,b)
   if west and row==1:
    part('Sharp monumental second floor meeting rail',(x,-.02,z+.45),(bay-.72,.34,.14),metal,a,b)
    for dx in (-.5,.5):part('Sharp monumental cast iron outer upright',(x+dx*(bay-.8),.01,z+.10),(.16,.36,wh+.35),metal,a,b)
  part('Sharp end masonry pier',(width,.02,z),(.62,.4,top-bottom),brick,a,b)
 for z,h,depth in [(10,.55,.70),(H-1.1,.45,.85),(H-.25,.50,1.0)]:
  part('Sharp continuous projecting belt/cornice',(width/2,.15,z),(width,depth,h),trim,a,b)
 # shortcut: two-tier arch size/spacing are photo-fit; replace with measured parapet sections when available.
 count=max(1,round(width/.75));pitch=width/count
 assert pitch>.6
 for tier in range(2):
  z=H-1.65+tier*.75
  for j in range(count):
   x=(j+.5)*pitch
   part('Sharp dark recessed parapet opening',(x,-.12,z+.04),(.40,.05,.48),roof,a,b)
   orient(arch('Sharp physical terracotta parapet arch',.20,.31,(x,z+.05),.10,.32,trim,segments=16),a,b)
   for dx in (-.255,.255):part('Sharp parapet arch jamb',(x+dx,.10,z-.12),(.11,.32,.34),trim,a,b)
   part('Sharp parapet arch sill',(x,.10,z-.32),(.62,.32,.10),trim,a,b)
for name,(vertices,faces) in facade_batches.items():
 assert len(vertices)%8==0 and len(faces)*4==len(vertices)*3,name
 mesh('Batched '+name,vertices,faces,bpy.data.materials[name])
finish('sharp_building',OUT)
