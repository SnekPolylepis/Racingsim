"""100 South Wacker/Hartford Plaza North: original coffered exterior draft."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
frame=material('Wacker100 pale sculpted facade grid',(.66,.65,.59),roughness=.86)
metal=material('Wacker100 dark bronze window frames',(.10,.13,.12),metallic=.3,roughness=.65)
glass=material('Wacker100 recessed green grey panes',(.13,.21,.20),roughness=.35)
night=material('Night occupied Wacker100 panes',(.13,.21,.20),roughness=.35,glow=.24)
roof=material('Wacker100 opaque interior and roof',(.09,.10,.10),roughness=.95)
louver=material('Wacker100 rooftop louver blades',(.20,.22,.19),metallic=.2,roughness=.85)
cx,cz=-1084.45,500
b=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w124865451')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def facade(name,pos,size,mat,a,b,bevel=0):
 obj=box(name,pos,size,mat,bevel)
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
 for p in obj.data.polygons:p.flip()
 return obj
# CVU74.4m architectural height. Owner21stories vsCVU20: provisional19office rows+ground+mechanical.
H=74.4;office_top=70.9;base=6.0;pitch_z=(office_top-base)/19
prism('Wacker100 exact mapped buried foundation',plan,-8,0,frame)
prism('Wacker100 recessed opaque core',[(x*.87,y*.85) for x,y in plan],0,H-.5,roof)
prism('Wacker100 exact roof slab',plan,H-.5,H,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b);bays=8 if width>50 else 6;bay=width/bays
 # ponytail: photo-fit eight/six bay rhythm and reveal depths; replace with measured facade sections when available.
 for j in range(bays+1):
  facade('Continuous broad sculpted coffer pier',(j*bay,-.25,office_top/2),(.85,1.05,office_top),frame,a,b,.12)
 for row in range(20):
  bottom=0 if row==0 else base+(row-1)*pitch_z
  top=base if row==0 else bottom+pitch_z
  mid=(bottom+top)/2
  aperture=bay-1.10;height=top-bottom-.85
  facade('Sculpted horizontal coffer beam',(width/2,-.25,top-.31),(width,1.05,.62),frame,a,b,.12)
  for j in range(bays):
   x=(j+.5)*bay
   for k in range(4):
    facade('Four separate physically recessed office panes',(x+(k-1.5)*aperture/4,-.88,mid),(aperture/4-.075,.05,height),night if (row*11+j*3+k)%53==4 else glass,a,b)
   for dx in (-.5,-.25,0,.25,.5):
    facade('Thin bronze window upright',(x+dx*aperture,-.74,mid),(.065,.20,height+.10),metal,a,b)
   for z in (mid-height/2,mid+height/2):
    facade('Recessed bronze window head and sill',(x,-.74,z),(aperture+.08,.20,.09),metal,a,b)
 # Rooftop mechanical bands visible in owner aerial, with physical blades and larger bays.
 facade('Top mechanical opaque backing',(width/2,-.8,(H+office_top)/2),(width,.15,H-office_top),roof,a,b)
 for j in range(bays+1):facade('Mechanical bay broad pier',(j*bay,-.25,(H+office_top)/2),(.85,1.05,H-office_top),frame,a,b)
 for j in range(bays):
  for i in range(18):facade('Separate roof mechanical louver blade',((j+.5)*bay,-.45,office_top+.18+i*.17),(bay-1.1,.25,.065),louver,a,b)
 facade('Thin flat roof coping',(width/2,-.18,H-.15),(width,1.1,.30),frame,a,b)
# ponytail: three roof cabinets follow the owner aerial; sizes/positions are photo-fit, not equipment specifications.
for x,width in [(4,2.8),(8,3.5),(12.5,3.6)]:
 box('Physical roof cabinet support plinth',(x,-3,H+.10),(width+.3,3.2,.20),roof)
 box('Pale rooftop mechanical cabinet',(x,-3,H+1.05),(width,2.8,1.70),frame)
 box('Separate rooftop cabinet cap',(x,-3,H+1.95),(width+.12,2.95,.10),frame)
 for side in (-1,1):
  box('Roof cabinet dark grille backing',(x,-3+side*1.415,H+1.05),(width-.30,.035,1.40),roof)
  for i in range(14):box('Physical cabinet horizontal grille blade',(x,-3+side*1.45,H+.40+i*.10),(width-.30,.085,.04),louver)
for o in bpy.context.scene.objects:
 if o.type=='MESH':assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
finish('wacker_100',OUT)
