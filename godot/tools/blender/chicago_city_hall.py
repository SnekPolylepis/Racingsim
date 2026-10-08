"""City Hall / County paired halves: original geometry from HABS dimensions and municipal photos."""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, arch, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Woodbury grey granite',(.57,.57,.53),roughness=.9)
trim=material('Pale granite and terra cotta relief',(.67,.66,.60),roughness=.85)
dark=material('Dark terra cotta spandrels and sashes',(.13,.14,.13),roughness=.78)
glass=material('Separate recessed blue grey sash panes',(.17,.24,.27),roughness=.55)
back=material('Opaque recessed backing and unsurveyed courts',(.26,.25,.23),roughness=.95)
roof=material('Roof slab and coping',(.31,.32,.30),roughness=.95)
H=62.484 # HABS205ft coping; WJE rounded200ft differs. See reference limits.
county='--county' in sys.argv
bronze=material('LaSalle bronze door and transom frames',(.37,.27,.13),metallic=.45,roughness=.55) if not county else dark
cx,cz=(-579.65,106.8) if county else (-626,106.35)
data=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text(encoding='utf-8'))
foot=next(b['f'] for b in data['buildings'] if b.get('o')==('w108240968' if county else 'w108240964'))
ring=[(x-cx,cz-z) for x,z in foot]
def prism(name,z,h,mat,scale=1):
 r=[(x*scale,y*scale) for x,y in ring];n=len(r)
 return mesh(name,[(x,y,z-h/2) for x,y in r]+[(x,y,z+h/2) for x,y in r],
  [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
prism('Exact mapped foundation',-4,8,back)
prism('Inset irregular opaque backing',H/2,H-.6,back,.90)
prism('Mapped roof retaining eastern court notches',H-.25,.5,roof)
# Three continuous public elevations; eastern reentrant walls retain mapped geometry.
faces=([('south',foot[21],foot[0],7),('north',foot[1],foot[2],7),('east',foot[0],foot[1],18)]
 if county else [('south',foot[0],foot[2],7),('north',foot[19],foot[20],7),('west',foot[20],foot[0],18)])
for name,aa,bb,cols in faces:
 a=(aa[0]-cx,cz-aa[1]);b=(bb[0]-cx,cz-bb[1])
 length=math.dist(a,b);origin=((a[0]+b[0])/2,(a[1]+b[1])/2,0);angle=math.atan2(b[1]-a[1],b[0]-a[0])
 def placed(obj):
  obj.location=Vector(origin)+Matrix.Rotation(angle,3,'Z')@obj.location
  obj.rotation_euler.z+=angle
  return obj
 def part(label,x,z,w,h,d,t,mat):return placed(box(label,(x,d,z),(w,t,h),mat))
 def tube(label,x,d,lo,hi,r0,r1,mat,fluted=False):
  count=80 if fluted else 24
  verts=[]
  for z,r in [(lo,r0),(hi,r1)]:
   for i in range(count):
    theta=2*math.pi*i/count;radius=r*(1-.075*(1+math.cos(theta*20))/2 if fluted else 1)
    verts.append((x+radius*math.cos(theta),d+radius*math.sin(theta),z))
  return placed(mesh(label,verts,[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)],mat))
 pitch=length/cols;ww=pitch*.66
 # ponytail: public bay counts and horizontal spacing are photo-fit estimates, not measured elevations.
 for row in range(3):
  low=row*7.112
  entry_row=not county and name=='west' and row==0
  if entry_row:
   for sign in [-1,1]:part('Base band outside LaSalle entrances',sign*(length/4+pitch),low+.95,length/2-2*pitch,1.9,0,.6,stone)
  else:part('Rusticated base solid band',0,low+.95,length,1.9,0,.6,stone)
  for c in range(cols):
   x=(c-(cols-1)/2)*pitch
   if entry_row and abs(x)<2*pitch:continue
   for s in range(3):
    px=x+(s-1)*ww/3
    part('Individual base sash glazing',px,low+4.15,ww/3-.10,4.30,1.08,.035,glass)
    for z in [low+2,low+4.1,low+6.3]:part('Base sash transom and meeting rail',px,z,ww/3,.075,.87,.15,dark)
   for dx in [-ww/2,-ww/6,ww/6,ww/2]:part('Base window dark stile',x+dx,low+4.15,.085,4.3,.87,.15,dark)
   for dx in [-ww/2-.16,ww/2+.16]:part('Deep stone base window surround',x+dx,low+4.15,.32,4.8,.12,.55,trim)
   part('Base window stone lintel',x,low+6.55,ww+.64,.35,.12,.55,trim)
  for c in range(cols+1):
   x=-length/2+c*pitch
   if entry_row and abs(x)<2*pitch:continue
   part('Rusticated base pier',x,low+4.35,pitch-ww,4.9,0,.65,stone)
   for z in [low+2.2,low+3.4,low+4.6,low+5.8]:part('Physical shallow rustication joint',x,z,pitch-ww,.025,-.34,.025,dark)
 if not county and name=='west':
  # LaSalle photo by Ajay Suresh (2021): three portals, recessed bronze doors/transoms.
  # ponytail: portal sizes photo-fit; relief figures remain unmodeled pending sculpting.
  for sign in [-1,1]:part('Solid outer entrance masonry',sign*1.84*pitch,3.15,.32*pitch,6.3,0,.65,stone)
  for x in [-pitch,0,pitch]:
   opening=pitch*.64
   for dx in [-opening/2-.34,opening/2+.34]:
    part('LaSalle portal outer stone jamb',x+dx,3.15,.68,6.3,-.38,.95,trim)
    for offset in [0,.16]:part('Nested portal jamb moulding',x+dx+(.20-offset)*(1 if dx<0 else -1),3.1,.075,6.2,-.92-offset*.5,.12,trim)
   for z,w,h,d,t in [(6.35,opening+1.4,.5,-.38,.95),(6.73,opening+1.65,.25,-.54,1.20),(7.02,opening+1.8,.24,-.62,1.3)]:
    part('Layered portal lintel and projecting cornice',x,z,w,h,d,t,trim)
   for dx in [-opening/2+.12,opening/2-.12]:part('Recessed portal stone reveal',x+dx,3.15,.24,6.3,.63,1.5,stone)
   part('Deep portal ceiling',x,6.10,opening,.25,.63,1.5,stone)
   part('Portal threshold',x,.10,opening,.20,.63,1.5,stone)
   for c in range(4):
    px=x+(c-1.5)*opening/4
    part('Recessed bronze entry door glazing',px,1.65,opening/4-.09,3.1,1.40,.04,glass)
    part('Tall separate entrance transom glazing',px,4.62,opening/4-.09,2.4,1.40,.04,glass)
    part('Entrance transom vertical bronze bar',px+opening/8,4.62,.06,2.5,1.18,.14,bronze)
   for dx in [-opening/2,-opening/4,0,opening/4,opening/2]:part('Bronze entrance door stile',x+dx,1.65,.075,3.2,1.18,.16,bronze)
   for z in [.13,3.2,3.4,5.87]:part('Entrance bronze horizontal rail',x,z,opening,.12,1.18,.16,bronze)
   for dx in [-.15,.15]:part('Physical door pull',x+dx,1.55,.055,.65,1.03,.08,bronze)
   part('Portal central stone pendant',x,6.28,.52,1.25,-.94,.3,trim)
   for c in range(15):placed(arch('Portal lintel repeated circular ornament',.065,.10,(x+(c-7)*(opening+1.1)/15,6.74),-1.17,.04,trim,0,2*math.pi,12))
  for x in [-1.5*pitch,-.5*pitch,.5*pitch,1.5*pitch]:
   width=pitch*.36-.1
   part('Stone pier between LaSalle portals',x,3.15,width,6.3,0,.65,stone)
   for dx in [-width/2+.06,width/2-.06]:part('Relief panel outer border',x+dx,3.65,.12,3.9,-.36,.15,trim)
   for z in [1.70,5.60]:part('Relief panel horizontal border',x,z,width,.14,-.36,.15,trim)
 for z,w in [(20.9,.35),(21.336,.55),(22.5,.22)]:part('Base projecting continuous belt',0,z,length,w,-.14,.95,trim)
 for row in range(6):
  low=22.5+row*4.58
  part('Dark relief spandrel behind colonnade',0,low+.72,length,1.44,.82,.18,dark)
  for c in range(cols):
   x=(c-(cols-1)/2)*pitch
   for s in range(3):
    px=x+(s-1)*ww/3
    part('Separate upper sash pane',px,low+3.0,ww/3-.10,2.85,1.12,.035,glass)
    for z in [low+1.57,low+2.1,low+3.2,low+4.42]:part('Upper sash physical rail',px,z,ww/3,.075,.88,.15,dark)
    # Circular wreath relief from municipal closeup, simplified to physical rings.
    placed(arch('Spandrel wreath relief',.22,.30,(px,low+.70),.65,.1,trim,0,2*math.pi,16))
   for dx in [-ww/2,-ww/6,ww/6,ww/2]:part('Upper triple window stile',x+dx,low+3,.10,3.0,.88,.18,dark)
  for c in range(cols+1):
   part('Stone wall behind columns',-length/2+c*pitch,low+3,pitch-ww,3.2,.30,.5,stone)
 # HABS column base6ft, shaft75.5ft, capital12.5ft, diameter9ft.
 for c in range(1,cols):
  x=-length/2+c*pitch
  tube('Column moulded plinth',x,-.70,21.336,22.1,1.65,1.65,trim)
  tube('Column base torus profile',x,-.70,22.1,23.1648,1.50,1.3716,trim)
  tube('Tall tapered fluted granite shaft',x,-.70,23.1648,46.1772,1.3716,1.23,stone,True)
  tube('Corinthian capital basket',x,-.70,46.1772,49.35,1.23,1.65,trim)
  for tier in range(3):
   for leaf in range(8):
    theta=2*math.pi*(leaf+.5*(tier%2))/8
    r=1.3+tier*.15;z=46.6+tier*.8
    obj=mesh('Raised stylized acanthus leaf',[(x+(r+rr)*math.cos(theta+da),-.7+(r+rr)*math.sin(theta+da),z+dz) for rr,da,dz in [(0,-.16,0),(0,.16,0),(.35,.10,.65),(.45,0,.95),(.35,-.10,.65)]],[(0,1,2,3,4)],trim)
    placed(obj)
  part('Corinthian square abacus',x,49.66,3.7,.65,-.70,3.7,trim)
 for x in [-length/2+1,length/2-1]:part('Colonnade corner pilaster',x,35.65,2,28.65,-.10,.8,stone)
 part('Solid upper entablature',0,53.64,length,7.3152,0,.6,stone)
 for z in [50.1,51.15,56.9]:part('Upper projecting frieze band',0,z,length,.32,-.15,.9,trim)
 for c in range(cols*3):
  x=(c-(cols*3-1)/2)*length/(cols*3)
  placed(arch('Upper circular frieze relief',.22,.32,(x,54.8),-.39,.09,trim,0,2*math.pi,16))
 part('Attic lower masonry band',0,58.15,length,1.7,0,.5,stone)
 part('Attic upper parapet',0,61.55,length,1.6,0,.5,stone)
 for c in range(cols):
  x=(c-(cols-1)/2)*pitch
  for dx in [-.6,.6]:part('Small separate attic pane',x+dx,59.9,.75,1.6,.55,.035,glass)
 for c in range(cols+1):part('Attic pier',-length/2+c*pitch,59.9,pitch-2.1,1.9,0,.5,stone)
 part('Coping without removed historic cornice',0,62.25,length,.468,-.06,.7,trim)
for i in range(2,21 if county else 19):
 a,b=ring[i],ring[i+1];length=math.dist(a,b)
 obj=box('Unsurveyed mapped courtyard wall',(0,0,H/2),(length,.30,H),back)
 obj.rotation_euler.z=math.atan2(b[1]-a[1],b[0]-a[0]);obj.location=((a[0]+b[0])/2,(a[1]+b[1])/2,0)
finish('county_building' if county else 'city_hall',OUT)
