"""100 North LaSalle / Lawyers Building authored exterior study, +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
brick=material('LaSalle100 painted brown masonry',(.34,.25,.21),roughness=.9)
terra=material('LaSalle100 brown terra cotta piers and crown',(.36,.27,.23),roughness=.85)
tile=material('LaSalle100 brown tiled altered base',(.30,.23,.21),roughness=.82)
granite=material('LaSalle100 black granite pointed portal',(.065,.07,.075),roughness=.45)
glass=material('LaSalle100 recessed green grey windows',(.105,.18,.175),roughness=.48)
night=material('Night LaSalle100 occupied windows',(.105,.18,.175),roughness=.48,glow=.2)
frame=material('LaSalle100 dark metal window frames',(.07,.085,.085),metallic=.25,roughness=.7)
roof=material('LaSalle100 opaque interior and flat roof',(.08,.09,.085),roughness=.95)
cx,cz=-695,148.95
building=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w147095666')
plan=[(x-cx,-(z-cz)) for x,z in building['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def place(obj,a,b):
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
 for polygon in obj.data.polygons:polygon.flip()
 return obj
def facade(name,pos,size,mat,a,b):return place(box(name,pos,size,mat),a,b)
H=90;body=87.5;base=10.8
# ponytail: CVU25floors/NPS3-floor altered base; interval, bay spacing and crown carving photo-fit.
prism('LaSalle100 exact concave six vertex buried foundation',plan,-8,0,brick)
prism('LaSalle100 recessed opaque L shaped core',[(x*.92,y*.92) for x,y in plan],0,body-.4,roof)
prism('LaSalle100 retained L shaped flat roof',plan,body-.4,body,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b);count=max(1,round(width/2.7));pitch=width/count
 east=a[0]>13 and b[0]>13;south=a[1]<-14 and b[1]<-14
 public=east or south
 for row in range(25):
  lo=row*base/3 if row<3 else base+(row-3)*(body-base)/22
  hi=(row+1)*base/3 if row<3 else lo+(body-base)/22
  window_h=hi-lo-1.12;mid=lo+.18+window_h/2
  if east and row<2:
   for sign in (-1,1):
    length=width/2-2.8
    facade('Base band outside pointed entrance',(width/2+sign*(2.8+length/2),-.12,hi-.40),(length,.64,.80),tile,a,b)
  else:facade('Masonry horizontal window spandrel',(width/2,-.12,hi-.40),(width,.64,.80),tile if row<3 else brick,a,b)
  for j in range(count):
   u=(j+.5)*pitch
   if east and abs(u-width/2)<3.1 and row<3:continue
   facade('Separate recessed sash pane',(u,-.58,mid),(pitch-1.05,.07,window_h),night if (row*13+j*17)%61==5 else glass,a,b)
   for x in (u-(pitch-1.05)/2,u+(pitch-1.05)/2):facade('Physical sash upright',(x,-.46,mid),(.065,.20,window_h),frame,a,b)
   facade('Physical sash meeting rail',(u,-.44,mid-.05),(pitch-1.05,.20,.075),frame,a,b)
   facade('Raised window sill',(u,-.22,lo+.10),(pitch-.90,.64,.15),terra,a,b)
 for j in range(count+1):
  u=j*pitch
  bottom=base if east and abs(u-width/2)<3.1 else 0
  facade('Continuous narrow vertical masonry pier',(u,-.10,(bottom+body)/2),(.68,.62,body-bottom),tile if not public else terra,a,b)
  if public:
   # Stepped physical cap and fluted vertical ribs echo the photographed Gothic crown.
   facade('Raised crown pier',(u,.02,body-.8),(.78,.70,5.4),terra,a,b)
   for dx in (-.22,0,.22):facade('Crown projecting vertical rib',(u+dx,.40,body-.65),(.055,.12,4.8),terra,a,b)
   facade('Stepped crown pier head',(u,.02,H-.15),(.62,.70,.30),terra,a,b)
 facade('Third floor base projecting band',(width/2,.02,base),(width,.90,.35),terra,a,b)
 if east:
  # NPS documents black granite at original two-story arch; location/proportions provisional.
  u=width/2
  for sign in (-1,1):facade('Black granite portal jamb',(u+sign*2.45,.06,1.3),(.65,.90,2.6),granite,a,b)
  vertices=[]
  for i in range(33):
   t=-1+2*i/32
   for depth in (-.39,.51):
    for radius in (2.2,2.7):vertices.append((u+t*radius,depth,2.6+radius*math.sqrt(max(0,4-(abs(t)+1)**2))))
  faces=[]
  for i in range(32):
   k=i*4;n=k+4;faces.extend([(k,n,n+1,k+1),(k+2,k+3,n+3,n+2),(k,k+2,n+2,n),(k+1,n+1,n+3,k+3)])
  faces.extend([(0,1,3,2),(128,130,131,129)])
  place(mesh('Physical pointed black granite portal arch',vertices,faces,granite),a,b)
  facade('Recessed entrance glass',(u,-.55,3.10),(4.15,.08,6.2),glass,a,b)
  for dx in (-2.05,0,2.05):facade('Entrance metal upright',(u+dx,-.36,3.1),(.09,.20,6.2),frame,a,b)
for o in bpy.context.scene.objects:
 if o.type=='MESH':assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
finish('lasalle_100',OUT)
