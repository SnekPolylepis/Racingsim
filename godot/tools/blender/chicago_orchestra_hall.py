"""Blender-authored Orchestra Hall Georgian exterior, original mesh geometry.
blender -b --python tools/blender/chicago_orchestra_hall.py -- <output dir>
Reference: CSO Rosenthal Archives; credited sym_east.jpg; mapped footprint/roof.
"""
import bpy,json,math,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,mesh,box,line,text,arch,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
b=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w145493030')
a,c=b['f'][1],b['f'][0];width=math.dist(a,c)
along=((a[0]-c[0])/width,(a[1]-c[1])/width);normal=(-along[1],along[0]);origin=((a[0]+c[0])/2,(a[1]+c[1])/2)
def local(p):
 dx,dz=p[0]-origin[0],p[1]-origin[1]
 return dx*along[0]+dz*along[1],-dx*normal[0]-dz*normal[1]
ring=[local(p) for p in b['f']];lo,hi=-width/2,width/2
brick=material('Deep pink Georgian brick',(.43,.22,.20),roughness=.85)
stone=material('White limestone dressings',(.78,.77,.69),roughness=.7)
glass=material('Deep blue green glazing',(.06,.12,.13),metallic=.2,roughness=.23)
bronze=material('Patinated bronze windows',(.15,.22,.18),metallic=.6,roughness=.4)
roof=material('Flat dark roof membrane',(.19,.20,.19),roughness=.9)
shadow=material('Carved lettering and joints',(.39,.38,.33))
n=len(ring);H=33.5
v=[(x,y,z) for z in [0,H] for x,y in ring]
mesh('Mapped auditorium annex volume',v,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],brick)
mesh('Mapped annex roof',[(x,y,H+.02) for x,y in ring],[tuple(range(n))],roof)
box('Michigan frontage upper floors',(0,6,21),(width,12,42),brick)
box('Frontage flat roof',(0,6,42.02),(width,12,.15),roof)
def sash(x,z,w,h):
 box('Recessed sash glass',(x,-.28,z),(w,.14,h),glass)
 for dx in [-w/2,0,w/2]:
  box('Bronze sash stile',(x+dx,-.43,z),(.055,.18,h),bronze)
 for dz in [-h/2,0,h/2]:
  box('Bronze meeting rail',(x,-.43,z+dz),(w,.18,.065),bronze)
 for dz in [-h/2-.10,h/2+.10]:
  box('Limestone sash sill lintel',(x,-.48,z+dz),(w+.35,.75,.22),stone)
 # Prominent Georgian keystone above each opening.
 box('Raised window keystone',(x,-.62,z+h/2+.17),(.35,.35,.45),stone)
# Eight vertical columns of regular upper windows, with a separate top frieze row.
for i in range(8):
 x=lo+width*(i+.5)/8
 for z in [20.5,24.6,28.7,32.8,36.9]:
  sash(x,z,2.3,2.8)
 sash(x,40.0,2.3,1.35)
 if i in [1,3,4,6]:
  box('Upper window balcony sill',(x,-.72,18.9),(2.7,1.1,.25),stone)
  for j in range(7):
   line('Upper balcony iron upright',[(x-1.25+j*2.5/6,-1.12,19),(x-1.25+j*2.5/6,-1.12,19.7)],.025,bronze)
  line('Upper balcony iron rail',[(x-1.35,-1.12,19.7),(x+1.35,-1.12,19.7)],.035,bronze)
# Three monumental round-arched windows; each has recessed curved glazing.
for x in [-width*.20,0,width*.20]:
 r=2.5;spring=12.8
 box('Arched window stem',(x,-.28,9.7),(r*2,.14,6.2),glass)
 v=[(x,-.35,spring)]+[(x+r*math.cos(j*math.pi/32),-.35,spring+r*math.sin(j*math.pi/32)) for j in range(33)]
 mesh('Round window crown',v,[(0,j+1,j+2) for j in range(32)],glass)
 arch('Deep stone archivolt',r,r+.40,(x,spring),-.62,.65,stone,segments=32)
 arch('Raised arch moulding',r+.48,r+.58,(x,spring),-.74,.20,stone,segments=32)
 for dx in [-r-.2,r+.2]:
  box('Monumental stone jamb',(x+dx,-.40,9.7),(.40,.85,6.4),stone)
 for dx in [-1.65,-.83,0,.83,1.65]:
  box('Tall bronze mullion',(x+dx,-.49,9.7),(.09,.22,6.3),bronze)
 for z in [8.0,10.3,12.5]:
  box('Arched window transom',(x,-.49,z),(r*2,.22,.09),bronze)
 for j in range(1,6):
  a=j*math.pi/6
  line('Fanlight radial bronze bar',[(x,-.49,spring),(x+r*math.cos(a),-.49,spring+r*math.sin(a))],.04,bronze)
 box('Arched gallery balcony',(x,-.72,6.6),(r*2+.65,1.35,.28),stone)
 for j in range(13):
  box('Gallery stone baluster',(x-r+j*r*2/12,-1.19,7.0),(.12,.16,.65),stone)
 box('Gallery balcony handrail',(x,-1.19,7.4),(r*2+.6,.25,.20),stone)
 box('Arch keystone',(x,-.78,15.65),(.45,.5,.75),stone)
# Side gallery doors with true triangular Georgian pediments.
for x in [-width*.385,width*.385]:
 sash(x,9.6,2.4,5.2)
 mesh('Door triangular pediment',[(x-1.65,-.55,12.7),(x+1.65,-.55,12.7),(x,-.55,13.7)],[(0,1,2)],stone)
 line('Pediment moulding',[(x-1.75,-.71,12.65),(x,-.71,13.85),(x+1.75,-.71,12.65)],.10,stone)
# Storefront doors and canopy, with lettering carved into projecting stone tablets.
for x in [-width*.30,0,width*.30]:
 sash(x,2.1,4.3,3.8)
box('Entrance limestone lintel',(0,-.40,4.4),(width,.80,.50),stone)
for z,d,h in [(5.3,.85,.35),(17.4,.85,.55),(18.0,.70,.28),(38.5,.8,.3),(41.3,.95,.4),(41.8,1.0,.45)]:
 box('Wrapping frontage cornice',(0,-d/2,z),(width+.2,d,h),stone)
text('Composer frieze','BACH   MOZART   BEETHOVEN   SCHUBERT   WAGNER',(0,-.92,17.55),.54,shadow,depth=.015)
text('Hall entrance name','ORCHESTRA HALL',(0,-.84,4.4),.75,shadow,depth=.02)
# Alternating corner quoins, carved frieze swags and dentils.
for x in [lo+.3,hi-.3]:
 for i in range(62):
  box('Alternating corner quoin',(x,-.35,.8+i*.65),(.65 if i%2 else .95,.60,.30),stone)
for i in range(62):
 box('Cornice dentil',(lo+(i+.5)*width/62,-.82,41.2),(.25,.45,.20),stone)
for x in [lo+1.5,hi-1.5]:
 line('Carved limestone swag',[(x-1.05,-.60,40.6),(x-.6,-.67,40.15),(x,-.67,39.95),(x+.6,-.67,40.15),(x+1.05,-.60,40.6)],.09,stone)
# Roof balustrade sits behind the cornice rather than extending into the road.
for j in range(46):
 x=lo+(j+.5)*width/46
 box('Roof stone baluster',(x,.2,42.55),(.12,.2,.85),stone)
box('Roof parapet handrail',(0,.2,43.1),(width,.45,.24),stone)
# Secondary mapped street elevations get inset glass and stone sills.
for i in range(n):
 if i==0:continue
 a,c=ring[i],ring[(i+1)%n];span=math.dist(a,c)
 if span<6:continue
 angle=math.atan2(c[1]-a[1],c[0]-a[0]);tx,ty=math.cos(angle),math.sin(angle);nx,ny=-ty,tx
 count=max(1,int(span/3.6))
 for j in range(count):
  u=(j+.5)*span/count
  for f in range(7):
   z=3.5+f*4.2
   for name,sx,sy,sz,dz,offset,mat in [('Annex recessed glazing',1.8,.13,2.5,0,.20,glass),('Annex sill lintel',2.1,.45,.20,-1.4,.30,stone),('Annex sill lintel',2.1,.45,.20,1.4,.30,stone)]:
    obj=box(name,(0,0,0),(sx,sy,sz),mat);obj.location=(a[0]+tx*u+nx*offset,a[1]+ty*u+ny*offset,z+dz);obj.rotation_euler.z=angle
finish('orchestra_hall',OUT)
