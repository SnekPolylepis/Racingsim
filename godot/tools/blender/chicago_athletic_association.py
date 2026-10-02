"""Author Chicago Athletic Association's Venetian Gothic exterior in Blender.
blender -b --python tools/blender/chicago_athletic_association.py -- <output dir>
References: HABS IL-1226 / Chicago Architecture Center / credited caa_east.jpg.
"""
import bpy, json, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,mesh,box,line,text,arch,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
b=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w147476152')
a,c=b['f'][7],b['f'][8];width=math.dist(a,c)
along=((a[0]-c[0])/width,(a[1]-c[1])/width);normal=(-along[1],along[0])
origin=((a[0]+c[0])/2,(a[1]+c[1])/2)
def local(p):
 dx,dz=p[0]-origin[0],p[1]-origin[1]
 return dx*along[0]+dz*along[1],-dx*normal[0]-dz*normal[1]
ring=[local(p) for p in b['f']];lo,hi=-width/2,width/2;H=52.0
brick=material('Venetian red brick',(.40,.19,.16),roughness=.9)
stone=material('Carved pale limestone',(.72,.72,.65),roughness=.7)
light=material('Raised limestone tracery',(.84,.84,.75),roughness=.6)
glass=material('Deep blue glazing',(.065,.105,.14),metallic=.2,roughness=.23)
metal=material('Dark bronze window sashes',(.10,.12,.13),metallic=.7,roughness=.4)
roof=material('Roof membrane and joints',(.22,.22,.20),roughness=.9)
n=len(ring);v=[(x,y,z) for z in [0,H] for x,y in ring]
mesh('Mapped brick volume',v,[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],brick)
mesh('Flat mapped roof',[(x,y,H+.02) for x,y in ring],[tuple(range(n))],roof)
box('Limestone street base',(0,.20,6.5),(width,.45,13),stone)
# Front composition: three bays with a wide central gallery and narrow side galleries.
galleries=[(-width*.365,width*.19,2),(0,width*.50,8),(width*.365,width*.19,2)]
def sash(x,z,w,h):
 box('Recessed sash glazing',(x,-.35,z),(w,.13,h),glass)
 for dx in [-w/2,w/2]:
  box('Bronze vertical sash',(x+dx,-.46,z),(.06,.16,h),metal)
 for dz in [-h/2,0,h/2]:
  box('Bronze horizontal sash',(x,-.46,z+dz),(w,.16,.07),metal)
def pointed(x,z,r,height,y=-.61,radius=.08):
 # Two curved stone branches meeting at a real pointed crown.
 for side in [-1,1]:
  points=[]
  for i in range(25):
   t=i/24
   px=side*r*(1-t*t)
   pz=z+height*(2*t-t*t)
   points.append((x+px,y,pz))
  line('Pointed Gothic archivolt',points,radius,light)
def column(x,z,h,r=.095,y=-.57):
 line('Carved stone column',[(x,y,z-h/2),(x,y,z+h/2)],r,light)
 for dz in [-h/2,h/2]:
  box('Column capital base',(x,y,z+dz),(.42,.42,.24),light,.025)
 for dx in [-.14,.14]:
  arch('Capital scroll',.08,.12,(x+dx,z+h/2),y-.13,.10,light,end=math.tau,segments=12)
for gx,gw,count in galleries:
 left=gx-gw/2;pitch=gw/count
 box('Middle tracery recessed glazing',(gx,-.22,29.0),(gw,.12,6.4),glass)
 box('Top tracery recessed glazing',(gx,-.22,45.0),(gw,.12,6.4),glass)
 # Two rectangular storeys beneath the broad traceried middle gallery.
 for i in range(count):
  x=left+pitch*(i+.5)
  sash(x,17.0,pitch*.70,3.6)
  sash(x,22.4,pitch*.70,4.9)
  column(x-pitch/2,21.2,11.0)
  box('Mid gallery carved spandrel',(x,-.62,19.9),(pitch*.8,.6,.8),stone)
  pointed(x,25.0,pitch*.48,3.4,radius=.095)
  # Lozenge/cusp tracery above each pointed opening.
  line('Ogee tracery diamond',[(x,-.67,27.9),(x-pitch*.45,-.67,30.7),(x,-.67,32.4),(x+pitch*.45,-.67,30.7),(x,-.67,27.9)],.10,light)
 # Rectangular upper gallery framed by columns and recessed stone relief panels.
 for i in range(count):
  x=left+pitch*(i+.5)
  for z in [35.2,39.0]:
   sash(x,z,pitch*.71,2.9)
  column(x-pitch/2,37.0,7.2)
  box('Upper gallery carved tablet',(x,-.57,37.1),(pitch*.72,.42,.62),stone)
 # Top Venetian gallery: slender shafts, circles and three-lobed crowns.
 for i in range(count):
  x=left+pitch*(i+.5)
  sash(x,44.3,pitch*.68,3.4)
  column(x-pitch/2,44.2,4.4)
  arch('Top circular tracery',pitch*.28,pitch*.28+.08,(x,46.8),-.70,.2,light,end=math.tau,segments=24)
  for dx,dz in [(0,.54),(-.48,0),(.48,0)]:
   arch('Trefoil cusp',pitch*.16,pitch*.16+.065,(x+dx*pitch,46.9+dz*pitch),-.64,.15,light,segments=16)
 # Gallery outlines and projecting lintels.
 for z in [13.2,25.0,32.8,41.5,48.3]:
  box('Gallery projecting stone lintel',(gx,-.55,z),(gw+.35,.8,.30),light,.025)
 for x in [left-.18,left+gw+.18]:
  box('Gallery stone border',(x,-.45,30.6),(.30,.65,35.5),stone)
 # Street lancets (the central bay has eight, the side bays each two).
 for i in range(count):
  x=left+pitch*(i+.5)
  sash(x,10.9,pitch*.66,2.6)
  pointed(x,12.2,pitch*.35,1.3,radius=.075)
  column(x-pitch/2,10.7,3.1,r=.08)
# Alternating quoin blocks on the three large bay boundaries.
for x in [lo+.25,-width*.265,width*.265,hi-.25]:
 for i in range(40):
  box('Alternating limestone quoin',(x,-.38,13.8+i*.86),(.48 if i%2 else .72,.60,.37),stone)
# Real central arched portal; glazing sits behind the deep limestone surround.
sash(0,3.0,3.6,5.4)
arch('Central entrance archivolt',1.8,2.25,(0,5.7),-.78,.65,light,segments=32)
for x in [-2.02,2.02]:
 column(x,3.0,5.4,r=.16,y=-.72)
for x in [-width*.36,width*.36]:
 sash(x,3.3,2.0,4.2)
# Raised lettering, frieze medallions and geometric parapet relief.
box('Club name stone tablet',(0,-.65,33.0),(width*.52,.65,.95),stone)
text('Raised club name','CHICAGO ATHLETIC ASSOCIATION',(0,-1.0,33.0),.49,light,depth=.025)
for z in [7.7,13.5,48.8,50.5,51.7]:
 box('Continuous limestone cornice',(0,-.48,z),(width+.30,.9,.32),stone,.025)
for i in range(40):
 x=lo+(i+.5)*width/40
 box('Cornice dentil',(x,-.83,51.5),(.22,.40,.25),light)
for gx,gw,count in galleries:
 for dx in [-gw*.18,gw*.18]:
  arch('Frieze athletic medallion',.40,.54,(gx+dx,49.75),-.75,.20,light,end=math.tau,segments=24)
 for i in range(max(2,int(gw/.85))):
  x=gx-gw/2+(i+.5)*gw/max(2,int(gw/.85))
  line('Parapet diaper diamond',[(x,-.45,51.0),(x-.35,-.45,51.45),(x,-.45,51.9),(x+.35,-.45,51.45),(x,-.45,51.0)],.045,light)
# Rear/side street walls follow the actual concave footprint, with physical sash details.
for i in range(n):
 if i==7: continue
 a,c=ring[i],ring[(i+1)%n];span=math.dist(a,c)
 if span<6: continue
 angle=math.atan2(c[1]-a[1],c[0]-a[0]);tx,ty=math.cos(angle),math.sin(angle)
 nx,ny=-ty,tx
 for j in range(int(span/3.3)):
  u=(j+.5)*span/max(1,int(span/3.3))
  for f in range(11):
   z=3+f*4.4
   obj=box('Side recessed sash',(0,0,0),(1.7,.14,2.8),glass)
   obj.location=(a[0]+tx*u+nx*.16,a[1]+ty*u+ny*.16,z);obj.rotation_euler.z=angle
   for dz in [-1.5,1.5]:
    obj=box('Side stone lintel sill',(0,0,0),(2.05,.48,.18),stone)
    obj.location=(a[0]+tx*u+nx*.30,a[1]+ty*u+ny*.30,z+dz);obj.rotation_euler.z=angle
finish('athletic_association',OUT)


