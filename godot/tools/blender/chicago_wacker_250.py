"""250 South Wacker renovation exterior draft, mapped plan, +Y north, +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
white=material('Wacker250 opaque white glazed feature panels',(.76,.76,.72),roughness=.62)
metal=material('Wacker250 silver metal floor spandrels',(.49,.52,.52),metallic=.35,roughness=.75)
frame=material('Wacker250 thin dark curtainwall frames',(.10,.13,.14),metallic=.25,roughness=.7)
glass=material('Wacker250 recessed blue green glazing',(.13,.23,.27),roughness=.38)
night=material('Night occupied Wacker250 glazing',(.13,.23,.27),roughness=.38,glow=.2)
roof=material('Wacker250 dark roof and interior',(.08,.10,.10),roughness=.95)
seam=material('Wacker250 pale grey feature panel joints',(.48,.51,.50),roughness=.8)
cx,cz=-1070.15,712.55
b=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w147350207')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 if sum(x*v-y*u for (x,y),(u,v) in zip(points,points[1:]+points[:1]))<0:points=list(reversed(points))
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def facade(name,pos,size,mat,a,b):
 obj=box(name,pos,size,mat)
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
 for p in obj.data.polygons:p.flip()
 return obj
H=61.3;body=57.5;base=6.6
# ponytail: volumes/14 upper rows are photo-fit from architect elevations, not a measured floor/roof survey.
prism('Wacker250 exact seven vertex buried foundation',plan,-8,0,metal)
prism('Wacker250 recessed opaque office core',[(x*.88,y*.88) for x,y in plan],0,body-.4,roof)
prism('Wacker250 retained body roof slab',plan,body-.4,body,roof)
# Tall white feature at Wacker/Jackson corner follows the published renovation design.
corner=[(19.95,25.75),(10.45,25.625),(10.70,15.75),(20.21,15.75)]
prism('Wacker250 projecting white corner feature volume',corner,0,H,white)
# Photo-fit white flanks beside the higher feature; retained within the mapped plan.
north_flank=[(4.0,25.54),(10.45,25.625),(10.45,24.65),(4.0,24.65)]
east_flank=[(20.21,15.75),(20.39,9.0),(19.4,9.0),(19.4,15.75)]
prism('Wacker250 north white flank above glazed atrium',north_flank,base,body,white)
prism('Wacker250 east white flank',east_flank,0,body,white)
# Entrance glazing and paired doors beneath the north strip: proportions provisional.
a,b=(10.45,25.625),(4.0,25.54)
for j in range(4):
 u=(j+.5)*6.45/4
 facade('Double height atrium glazing',(u,-.18,base/2),(6.45/4-.09,.06,base-.14),glass,a,b)
 facade('Atrium upright',(j*6.45/4,-.03,base/2),(.09,.18,base),frame,a,b)
 facade('Atrium transom',(u,.015,2.65),(6.45/4,.12,.10),frame,a,b)
for u in (2.65,3.8):
 facade('Entry glazed door',(u,.075,1.30),(1.08,.08,2.5),glass,a,b)
 for x in (u-.55,u+.55):facade('Entry door jamb',(x,.15,1.30),(.08,.12,2.6),frame,a,b)
 facade('Entry pull handle',(u-.33,.24,1.18),(.035,.055,.52),metal,a,b)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b)
 if width<4:continue
 north=a[1]>24 and b[1]>24;east=a[0]>19 and b[0]>19
 count=max(1,round(width/2.15));pitch=width/count
 active=[]
 for j in range(count):
  u=(j+.5)*pitch
  gx=a[0]+u*(b[0]-a[0])/width;gy=a[1]+u*(b[1]-a[1])/width
  if (north and gx>4.0) or (east and gy>9.0):continue
  active.append(j)
  for row in range(15):
   lo=0 if row==0 else base+(row-1)*(body-base)/14
   hi=base if row==0 else lo+(body-base)/14
   height=hi-lo-.96;mid=lo+.10+height/2
   facade('Physical separate curtainwall pane',(u,-.28,mid),(pitch-.08,.05,height),night if (row*11+j*7)%47==3 else glass,a,b)
   facade('Separate curtainwall upright',(j*pitch,-.16,mid),(.07,.24,height),frame,a,b)
   for z in (mid-height/2,mid+height/2):facade('Thin glazing head and sill',(u,-.14,z),(pitch,.24,.08),frame,a,b)
 if active:
  left=min(active)*pitch;right=(max(active)+1)*pitch
  for row in range(15):
   hi=base if row==0 else base+row*(body-base)/14
   facade('Continuous metal floor spandrel',((left+right)/2,-.06,hi-.42),(right-left,.30,.84),metal,a,b)
 facade('Continuous flat body roof coping',(width/2,-.02,body-.08),(width,.45,.16),metal,a,b)
for a,b in zip(corner,corner[1:]+corner[:1]):
 width=math.dist(a,b)
 # Separate physical joints across the opaque white glass, no photograph texture.
 for i in range(1,max(2,round(width/1.8))):
  facade('Feature panel upright joint',(i*width/max(2,round(width/1.8)),.015,H/2),(.028,.05,H),seam,a,b)
 for i in range(1,18):facade('Feature panel horizontal joint',(width/2,.025,i*H/18),(width,.05,.028),seam,a,b)
 facade('White feature coping',(width/2,-.02,H-.08),(width,.30,.16),white,a,b)
for o in bpy.context.scene.objects:
 if o.type=='MESH':assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
finish('wacker_250',OUT)
