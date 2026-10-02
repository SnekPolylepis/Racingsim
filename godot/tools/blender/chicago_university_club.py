"""Blender-authored University Club Gothic exterior; photo is reference only.
blender -b --python tools/blender/chicago_university_club.py -- <output dir>
"""
import bpy,json,math,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,mesh,box,line,arch,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
b=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w126982632')
a,c=b['f'][0],b['f'][1];width=math.dist(a,c)
along=((a[0]-c[0])/width,(a[1]-c[1])/width);normal=(-along[1],along[0]);origin=((a[0]+c[0])/2,(a[1]+c[1])/2)
def local(p):
 dx,dz=p[0]-origin[0],p[1]-origin[1]
 return dx*along[0]+dz*along[1],-dx*normal[0]-dz*normal[1]
ring=[local(p) for p in b['f']];lo,hi=-width/2,width/2;depth=max(y for x,y in ring)
stone=material('Gothic limestone',(.67,.66,.60),roughness=.8)
carved=material('Raised pale stonework',(.78,.77,.70),roughness=.7)
glass=material('Recessed blue glazing',(.065,.12,.15),metallic=.2,roughness=.23)
metal=material('Bronze mullions',(.17,.15,.12),metallic=.7,roughness=.4)
roof=material('Slate pitched roof',(.21,.23,.24),roughness=.8)
shadow=material('Recessed stone joints',(.35,.34,.30))
# Main cornice 52 m, top gallery/eaves 58 m, measured gable ridge 69 m.
H=58.0;n=len(ring)
v=[(x,y,z) for z in [0,H] for x,y in ring]
mesh('Mapped limestone body',v,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],stone)
# The long pitched roof runs back from the visible eastern triangular gable.
mesh('Steep slate roof',[(lo,0,H),(0,0,69),(hi,0,H),(lo,depth,H),(0,depth,69),(hi,depth,H)],[(0,3,4,1),(1,4,5,2)],roof)
for y in [-.1,depth]:
 mesh('Stone triangular gable',[(lo,y,H),(hi,y,H),(0,y,69)],[(0,1,2)],stone)
 line('Gable coping',[(lo,y-.16,H),(0,y-.16,69),(hi,y-.16,H)],.16,carved)
def sash(x,z,w,h,y=-.28):
 box('Recessed window',(x,y,z),(w,.14,h),glass)
 for dx in [-w/2,0,w/2]:
  box('Bronze vertical mullion',(x+dx,y-.12,z),(.06,.17,h),metal)
 for dz in [-h/2,0,h/2]:
  box('Bronze meeting rail',(x,y-.12,z+dz),(w,.17,.065),metal)
 for dz in [-h/2-.10,h/2+.10]:
  box('Carved window lintel sill',(x,y-.18,z+dz),(w+.35,.65,.20),carved)
 for dx in [-w/2-.10,w/2+.10]:
  box('Deep limestone reveal',(x+dx,y-.14,z),(.18,.60,h+.30),carved)
def pointed(x,z,r,h,y=-.65):
 branches=[]
 for side in [-1,1]:
  pts=[]
  for i in range(17):
   t=i/16;pts.append((x+side*r*(1-t*t),y,z+h*(2*t-t*t)))
  line('Pointed stone tracery',pts,.065,carved);branches.append(pts)
 pane=[(px,-.25,pz) for px,py,pz in branches[0]+list(reversed(branches[1][:-1]))]
 mesh('Pointed glazing crown',pane,[tuple(range(len(pane)))],glass)
# Four main vertical bays, including projecting lower oriels on the end bays.
centers=[lo+width*(i+.5)/4 for i in range(4)]
for i,x in enumerate(centers):
 w=width*.155
 for z in [13.5,18.0,22.5,27.0,31.5,36.0]:
  projected=i in [0,3] and z<30
  y=-.85 if projected else -.28
  if projected:
   box('Oriel occupied projection',(x,-.40,z),(w+.45,.80,3.9),stone)
  sash(x,z,w,3.1,y=y-.15 if projected else y)
  if projected:
   for dz in [-2.1,2.1]:
    box('Oriel stone cornice',(x,-.45,z+dz),(w+.85,1.05,.24),carved)
   for j in range(5):
    box('Oriel small baluster',(x-w/2+j*w/4,-1.02,z-1.8),(.10,.18,.45),carved)
 # Tall Cathedral Hall windows have three lancets and two tiers of tracery.
 sash(x,44.3,w+1.0,7.8)
 r=(w+1.0)/2
 pointed(x,48.2,r,1.8)
 for dx in [-r*.65,0,r*.65]:
  box('Cathedral stone mullion',(x+dx,-.57,44.4),(.10,.40,7.9),carved)
  for z in [43.5,47.0]:
   pointed(x+dx,z,r*.32,.72)
 # Projecting balconies have real rails and baluster silhouettes.
 box('Cathedral balcony slab',(x,-.75,40.0),(w+1.35,1.55,.30),carved)
 for j in range(10):
  box('Cathedral balcony baluster',(x-(w+1.0)/2+j*(w+1.0)/9,-1.45,40.45),(.10,.14,.80),carved)
 box('Cathedral balcony rail',(x,-1.45,40.9),(w+1.4,.23,.20),carved)
 # Rectangular top gallery sash, below the gable and crenellation.
 sash(x,55.6,w+1.0,2.8)
 for dx in [-w*.40,0,w*.40]:
  pointed(x+dx,56.8,w*.20,.70)
 sash(x,8.0,w+1.0,4.4)
# Central pointed window inside the gable, and carved coping/pinnacles.
sash(0,62.0,3.6,3.2)
for x in [-1.2,0,1.2]:
 pointed(x,63.3,.55,.9)
for x in [lo+.28,hi-.28]:
 box('Corner Gothic buttress',(x,-.30,28.5),(.65,.65,57),carved)
 box('Pinnacle square shaft',(x,-.25,59.6),(.7,.7,3.4),carved)
 mesh('Pinnacle spire',[(x-.48,-.72,61),(x+.48,-.72,61),(x+.48,.22,61),(x-.48,.22,61),(x,-.25,65)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],carved)
 for z in [61.5,62.2,62.9,63.6]:
  for dx in [-.34,.34]:
   box('Pinnacle carved crocket',(x+dx,-.25,z),(.24,.32,.16),carved)
# Owl atop the eastern gable, a simplified sculptural silhouette.
box('Gable owl pedestal',(0,-.17,69.1),(.45,.5,.4),carved)
box('Carved owl body',(0,-.17,69.65),(.40,.40,.65),carved,.12)
for dx in [-.10,.10]:
 arch('Owl eye',.045,.075,(dx,69.83),-.40,.04,shadow,end=math.tau,segments=12)
# Physical belt courses, crenellated parapet and shallow stone relief panels.
for z in [4.8,10.8,38.2,51.7,52.2,58.0]:
 box('Front carved belt cornice',(0,-.40,z),(width+.25,.80,.26),carved)
for j in range(16):
 x=lo+(j+.5)*width/16
 box('Crenellated parapet merlon',(x,-.22,53.6),(.72,.50,1.0),carved)
 box('Gothic frieze recessed tablet',(x,-.20,50.3),(.82,.30,1.0),shadow)
 box('Gothic frieze relief centre',(x,-.38,50.3),(.65,.24,.80),stone)
# Arched street entrances and rusticated ground storey.
for x in [centers[0],centers[-1]]:
 sash(x,2.1,3.0,3.8)
 arch('Entrance stone arch',1.5,1.8,(x,3.8),-.7,.55,carved,segments=24)
for z in [1,2,3,4]:
 box('Ground rustication bed joint',(0,-.012,z),(width,.025,.03),shadow)
# Side elevations: repeated sashes and a cornice along the full mapped edge.
for i in range(n):
 if i==0:continue
 a,c=ring[i],ring[(i+1)%n];span=math.dist(a,c)
 if span<5:continue
 angle=math.atan2(c[1]-a[1],c[0]-a[0]);tx,ty=math.cos(angle),math.sin(angle);nx,ny=-ty,tx
 count=max(1,int(span/3.2))
 for j in range(count):
  u=(j+.5)*span/count
  for f in range(11):
   z=3.4+f*4.8
   for name,sx,sy,sz,dz,offset,mat in [('Side glazing',1.7,.13,2.7,0,.22,glass),('Side sill',2.05,.50,.20,-1.5,.34,carved),('Side lintel',2.05,.50,.20,1.5,.34,carved)]:
    obj=box(name,(0,0,0),(sx,sy,sz),mat);obj.location=(a[0]+tx*u+nx*offset,a[1]+ty*u+ny*offset,z+dz);obj.rotation_euler.z=angle
 for z in [10.8,38.2,52.2,58]:
  obj=box('Side cornice',(0,0,0),(span,.6,.24),carved);obj.location=((a[0]+c[0])/2+nx*.2,(a[1]+c[1])/2+ny*.2,z);obj.rotation_euler.z=angle
finish('university_club',OUT)
