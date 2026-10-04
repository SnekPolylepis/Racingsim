"""Original London Guarantee / LondonHouse historic exterior, Blender +Y north."""
import bpy, math, json, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, arch, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Warm Indiana limestone piers',(.66,.62,.54),roughness=.88)
trim=material('Pale limestone carved cornices',(.77,.73,.65),roughness=.88)
dark=material('Dark window sash and recessed backing',(.045,.045,.043),roughness=.75)
glass=material('Individual blue grey hotel panes',(.12,.17,.20),roughness=.48)
occupied=material('Night occupied hotel panes',(.21,.19,.14),roughness=.48,glow=.35)
bronze=material('Bronze entrance frames and railings',(.13,.105,.075),roughness=.65)
clear=material('Clear rooftop wind screens',(.27,.36,.40),roughness=.48)
cupolalight=material('Night cupola limestone columns and interior strips',(.77,.73,.65),roughness=.88,glow=.35)
canvas=material('White cafe awning stripes',(.8,.78,.7),roughness=.95)
roof=material('Weathered grey cupola dome',(.43,.45,.43),roughness=.85)
leaves=material('Olive terrace planting',(.13,.19,.075),roughness=.95)
CX,CZ=-57.85,-351.3
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text(encoding='utf-8'))
b=next(b for b in city['buildings'] if b.get('o')=='w147399567')
raw=[(x-CX,-(z-CZ)) for x,z in b['f']]
A,B=raw[0],raw[1];dx,dy=B[0]-A[0],B[1]-A[1];length=math.hypot(dx,dy)
inward=(dy/length,-dx/length)
def front(t):return (A[0]+dx*t+inward[0]*3.5*4*t*(1-t),A[1]+dy*t+inward[1]*3.5*4*t*(1-t))
plan=[front(i/24) for i in range(25)]+raw[2:]
def box(name,p,size,mat):
 o=baked_box(name,(0,0,0),size,mat);o.location=p;return o
def prism(name,p,lo,hi,mat):
 p=list(reversed(p));n=len(p)
 return mesh(name,[(x,y,z) for z in [lo,hi] for x,y in p],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def transform(o,p,angle):
 x,y,z=o.location;c,s=math.cos(angle),math.sin(angle);o.location=(p[0]+x*c-y*s,p[1]+x*s+y*c,z);o.rotation_euler.z+=angle
# Footprint is irregular; the curve sag is photo-derived, not a surveyed plan.
prism('Mapped foundation',plan,-8,.12,stone)
prism('Inset tower core',[(x*.95,y*.95) for x,y in plan],0,82.8,dark)
prism('Solid roof terrace',plan,82.6,83.2,stone)
def bay(p,angle,pitch,index,curved=False):
 before=set(bpy.context.scene.objects)
 # Genuine recesses: jambs and spandrels stand in front of the separate sash/panes.
 rows=[(0,5.0),(5.0,13.6)]+[(13.6+i*9.2/3,13.6+(i+1)*9.2/3) for i in range(3)]+[(22.8+i*49.2/14,22.8+(i+1)*49.2/14) for i in range(14)]+[(72+i*3.4,72+(i+1)*3.4) for i in range(3)]
 for row,(lo,hi) in enumerate(rows):
  if curved and index in [4,5] and row in [0,1]:continue
  if curved and row>=19:
   if row>19:continue
   lo,hi=72,82.2
  h=hi-lo;w=pitch*.58
  attic=curved and row==19
  box('Deep limestone jamb',(-pitch/2,.02,(lo+hi)/2),(pitch-w,.48,h),stone)
  box('Stone opaque spandrel',(0,.02,lo+(.23 if attic else .18*h)),(w+.12,.48,.46 if attic else .36*h),stone)
  pane=occupied if (row*11+index*7)%19 in [1,5,8] else glass
  box('Separate recessed window',(0,-.19,lo+(.54*h if attic else .66*h)),(w-.18,.035,h*.88 if attic else h*.60),pane)
  box('Black centre sash',(0,-.10,lo+(.54*h if attic else .66*h)),(.07,.11,h*.88 if attic else h*.60),dark)
  for side in [-1,1]:box('Window side sash',(side*(w-.10)/2,-.10,lo+(.54*h if attic else .66*h)),(.08,.11,h*.9 if attic else h*.63),dark)
  box('Projecting limestone sill',(0,.18,lo+(.055*h if attic else .36*h)),(w+.28,.48,.12),trim)
  for fraction in ([.36,.68] if attic else [.66]):box('Sash crossbar',(0,-.10,lo+fraction*h),(w-.10,.11,.075),dark)
  if row in [1,19]:
   # Low-relief arched lintels and keystones over the tall base/attic windows.
   o=arch('Moulded round window lintel',w*.36,w*.36+.13,(0,hi-.42),-.17,.38,trim,segments=16)
   box('Lintel keystone',(0,.10,hi-.10),(.3,.3,.45),trim)
 if curved:
  box('Attic giant pilaster',(-pitch/2,.40,77.3),(.65,.78,9.8),stone)
  box('Attic pilaster capital',(-pitch/2,.50,81.8),(1.05,.98,.40),trim)
  box('Attic pilaster base',(-pitch/2,.47,72.4),(.98,.92,.35),trim)
 # Rustication on tall base, broad band below central shaft and attic.
 for z in [5,13.6,22.8,72,82.4,83.05]:
  if curved and index in [4,5] and z==5:continue
  box('Projecting course',(0,.25,z),(pitch+.10,.85,.25 if z not in [22.8,72,83.05] else .50),trim)
 for z in [i*.6 for i in range(1,23)]:
  if curved and index in [4,5]:continue
  box('Rusticated limestone pier joint',(-pitch/2,.265,z),(pitch-pitch*.58,.035,.035),trim)
 for z in [22.1,71.4,82.55]:
  for x in [-pitch*.32,0,pitch*.32]:box('Cornice dentil',(x,.60,z),(.19,.29,.25),trim)
 if index%2==0:
  # Black and white striped cafe canopies, pitched clear of the pavement.
  for i in range(10):
   o=box('Cafe canopy stripe',(-w/2+(i+.5)*w/10,.85,3.1),(w/10+.015,1.45,.09),canvas if i%2==0 else dark);o.rotation_euler.x=-.24
 for o in set(bpy.context.scene.objects)-before:transform(o,p,angle)
# Curved Wacker corner; ten true recesses, continuous curved cornices.
for i in range(10):
 t=(i+.5)/10;p=front(t);l=front(max(0,t-.0001));r=front(min(1,t+.0001));a=math.atan2(r[1]-l[1],r[0]-l[0]);bay(p,a,length/10,i,True)
# Remaining mapped walls: separate rectangular windows, not a tiled photograph.
for edge in range(1,len(raw)):
 a,b=raw[edge],raw[(edge+1)%len(raw)];d=(b[0]-a[0],b[1]-a[1]);ln=math.hypot(*d);count=max(1,round(ln/3.4))
 for i in range(count):bay((a[0]+d[0]*(i+.5)/count,a[1]+d[1]*(i+.5)/count),math.atan2(d[1],d[0]),ln/count,edge*20+i)
# Smooth moulding ribbons along the concave front, beyond the faceted individual bays.
for z,width,depth in [(22.8,.6,.6),(72,.6,.8),(82.5,.35,.8),(83.05,.4,1.05)]:
 for i in range(24):
  a,b=front(i/24),front((i+1)/24);d=(b[0]-a[0],b[1]-a[1]);o=box('Curved limestone cornice',(0,depth*.3,z),(math.hypot(*d)+.05,depth,width),trim);transform(o,((a[0]+b[0])/2,(a[1]+b[1])/2),math.atan2(d[1],d[0]))
# Monumental arched entrance centered on the curved facade.
p=front(.5);p=(p[0]+inward[0]*.2,p[1]+inward[1]*.2);angle=math.atan2(dy,dx)
before=set(bpy.context.scene.objects)
box('Recessed entrance doors',(0,-.38,3.1),(3.4,.08,5.5),glass)
box('Arched entrance fanlight',(0,-.30,7.2),(3.8,.06,2.1),glass)
for side in [-1,1]:box('Portal limestone side infill',(side*3.13,.015,6.8),(1.18,.48,13.6),stone)
# Solid stone above the curved arch, preserving the actual curved opening below it.
profile=[(2.55*math.cos(math.pi-i*math.pi/32),6.2+2.55*math.sin(math.pi-i*math.pi/32)) for i in range(33)]+[(2.55,13.6),(-2.55,13.6)]
n=len(profile)
mesh('Carved arch stone spandrel',[(x,y,z) for y in [.12,-.18] for x,z in profile],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],stone)

for x in [-2.6,2.6]:
 box('Entrance Corinthian pier',(x,.58,5.3),(.7,.9,9.8),trim)
 box('Entrance capital',(x,.62,9.9),(1.2,1.15,.6),trim)
arch('Deep entrance stone arch',1.9,2.55,(0,6.2),-.20,.9,trim,segments=32)
for x in [-2.225,2.225]:box('Entry arch upright',(x,.25,3.2),(.65,.9,6.0),trim)
box('Door bronze centre',(0,-.25,3),(.12,.18,5.5),bronze)
for z in [2.2,4.2,6.1]:box('Bronze door transom',(0,-.25,z),(3.7,.18,.10),bronze)
box('Carved entry relief panel',(0,.48,10.5),(4.8,.42,1.4),trim)
# Sculptural relief is intentionally simplified to scroll/shell geometry; no invented portrait.
for side in [-1,1]:line('Relief scroll',[(side*.3,.73,10.8),(side*1.1,.75,10.4),(side*1.8,.74,10.7)],.1,stone)
text('Historic name letters','LONDON GUARANTEE',(0,.85,12.4),.48,bronze,rotate=(math.pi/2,0,math.pi))
for o in set(bpy.context.scene.objects)-before:transform(o,p,angle)
def ring(name,c,ro,ri,lo,hi,mat,n=64):
 v=[]
 for z in [lo,hi]:
  for r in [ro,ri]:v.extend((c[0]+r*math.cos(i*math.tau/n),c[1]+r*math.sin(i*math.tau/n),z) for i in range(n))
 f=[]
 for i in range(n):
  j=(i+1)%n;f.extend([(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),(2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)])
 return mesh(name,v,f,mat)
def cylinder(name,p,r,h,mat,n=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=h,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(mat);return o
cp=front(.5);cp=(cp[0]+inward[0]*5,cp[1]+inward[1]*5)
ring('Cupola stepped open terrace',cp,5.8,0.01,83.2,84.2,trim)
ring('Cupola upper step',cp,5.4,.01,84.2,85.2,trim)
ring('Cupola continuous pedestal',cp,5.1,4.0,85.2,86.0,stone)
for i in range(8):
 a=(i+.5)*math.tau/8;x,y=cp[0]+4.6*math.cos(a),cp[1]+4.6*math.sin(a)
 cylinder('Freestanding cupola column',(x,y,90),.36,8.0,cupolalight)
 for z,r,h in [(86.1,.52,.3),(93.7,.60,.45)]:cylinder('Cupola capital base',(x,y,z),r,h,trim)
ring('Clear cupola enclosure',cp,4.08,4.04,86,94,clear)
ring('Ringed cupola entablature',cp,5.3,3.95,94,95.4,trim)
ring('Dome drum',cp,4.75,3.95,95.4,96.0,stone)
v=[];n=64
for row in range(13):
 theta=row*math.pi/24;r=4.65*math.cos(theta);z=96+4.6*math.sin(theta)
 v.extend((cp[0]+r*math.cos(i*math.tau/n),cp[1]+r*math.sin(i*math.tau/n),z) for i in range(n))
mesh('Physical cupola dome',v,[(row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i) for row in range(12) for i in range(n)],roof)
cylinder('Cupola finial pedestal',(*cp,100.8),.58,.4,trim)
cylinder('Cupola finial',(*cp,101.8),.38,2.2,trim)
for i in range(8):
 a=i*math.tau/8;x,y=cp[0]+3.98*math.cos(a),cp[1]+3.98*math.sin(a)
 box('Cupola interior luminous strip',(x,y,86.05),(.08,.08,.10),cupolalight)
# Rooftop glass safety screen is set back from the historic cornice, as architect describes.
for edge in range(len(plan)):
 a,b=plan[edge],plan[(edge+1)%len(plan)];a=(a[0]*.90,a[1]*.90);b=(b[0]*.90,b[1]*.90);d=(b[0]-a[0],b[1]-a[1]);ln=math.hypot(*d)
 for name,z,thick,h,mat in [('Setback transparent windscreen',84,.035,1.4,clear),('Slim terrace handrail',84.7,.06,.06,bronze)]:
  o=box(name,(0,0,z),(ln,thick,h),mat);transform(o,((a[0]+b[0])/2,(a[1]+b[1])/2),math.atan2(d[1],d[0]))
for x,y in [(11,-8),(18,-5),(11,7)]:
 box('Terrace planter',(x,y,83.55),(1.8,1.2,.7),dark)
 for i in range(5):cylinder('Terrace shrub',(x+(i%3-.8)*.45,y+(i//3-.5)*.4,84.15),.35,.7,leaves,12)
 box('Terrace lounge seat',(x-2,y,83.6),(1.6,.85,.5),dark)
finish('london_guarantee',OUT)
