"""Blender-authored Railway Exchange exterior, referenced to CAC and rx_east.jpg.
blender -b --python tools/blender/chicago_railway_exchange.py -- <output directory>
"""
import bpy, json, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box, arch, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
b=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w124873931')
# The longest east-facing mapped edge, reversed to face left-to-right from outside.
a,c=b['f'][3],b['f'][4]
length=math.dist(a,c)
along=((a[0]-c[0])/length,(a[1]-c[1])/length)
outward=(-along[1],along[0]); origin=((a[0]+c[0])/2,(a[1]+c[1])/2)
def local(p):
 dx,dz=p[0]-origin[0],p[1]-origin[1]
 return dx*along[0]+dz*along[1],-dx*outward[0]-dz*outward[1]
ring=[local(p) for p in b['f']]
lo,hi=min(p[0] for p in ring),max(p[0] for p in ring)
depth=max(p[1] for p in ring); width=hi-lo; H=75.0
white=material('Glazed white terra cotta',(.84,.82,.75),roughness=.32)
ornament=material('Raised terra cotta ornament',(.93,.90,.82),roughness=.38)
glass=material('Recessed blue green glazing',(.055,.12,.13),metallic=.25,roughness=.2)
bronze=material('Dark bronze sashes',(.105,.12,.10),metallic=.65,roughness=.4)
stone=material('Granite entrance plinth',(.29,.29,.26),roughness=.7)
roof=material('Roof and sign steel',(.20,.21,.20),roughness=.7)
# Four occupied wings around the real central light well; no solid photo block.
box('East occupied wing',((lo+hi)/2,6,H/2),(width,12,H),white)
box('West occupied wing',((lo+hi)/2,depth-6,H/2),(width,12,H),white)
box('North occupied wing',(lo+6,depth/2,H/2),(12,depth-24,H),white)
box('South occupied wing',(hi-6,depth/2,H/2),(12,depth-24,H),white)
box('Atrium glass roof',((lo+hi)/2,depth/2,10),(width-24,depth-24,.25),glass)
# Each outside wall gets physical projecting bays, window reveals and top portholes.
def facade(start, tangent, normal, span, bays, label):
 def place(obj,u,v,z):
  obj.location=(start[0]+tangent[0]*u+normal[0]*v,start[1]+tangent[1]*u+normal[1]*v,z)
  obj.rotation_euler.z=math.atan2(tangent[1],tangent[0])
 def block(name,u,v,z,sx,sy,sz,mat):
  obj=box(label+' '+name,(0,0,0),(sx,sy,sz),mat)
  place(obj,u,v,z);return obj
 pitch=span/bays
 # Projected facing lies outside the wing; glazing sits behind its masonry reveals.
 for i in range(bays):
  u=pitch*(i+.5)
  for f in range(14):
   z=12+(f+.5)*4.05
   for dx in [-pitch*.23,pitch*.23]:
    block('office glazing',u+dx,-.30,z,pitch*.34,.12,2.75,glass)
    for dd in [-pitch*.19,pitch*.19]:
     block('deep window jamb',u+dx+dd,-.52,z,.18,.70,3.15,ornament)
    for h in [-1.52,1.52]:
     block('window lintel sill',u+dx,-.60,z+h,pitch*.40,.85,.22,ornament)
    block('window meeting rail',u+dx,-.42,z,pitch*.34,.14,.06,bronze)
    block('sash stile',u+dx,-.42,z,.055,.14,2.75,bronze)
   block('projecting bay pier',u+pitch*.48,-.35,z,pitch*.09,.7,4.05,white)
   block('relief spandrel',u,-.44,z-1.9,pitch*.82,.8,.42,white)
  # Circular glazing is a disc with an actual deep round moulded reveal.
  z=72.0;r=.915
  vertices=[(0,0,0)]+[(r*math.cos(j*math.tau/32),0,r*math.sin(j*math.tau/32)) for j in range(33)]
  obj=mesh(label+' circular porthole',vertices,[(0,j+1,j+2) for j in range(32)],glass)
  place(obj,u,-.35,z)
  obj=arch(label+' porthole reveal',r,r+.20,(0,0),-.68,.65,ornament,end=math.tau,segments=32)
  place(obj,u,0,z)
  block('porthole vertical sash',u,-.49,z,.07,.15,r*2,bronze)
  block('capital relief tablet',u,-.3,69.1,pitch*.65,.65,.4,ornament)
  # Two-storey street base has a broad display window and high transom.
  block('street display glazing',u,-.3,3.4,pitch*.73,.14,4.8,glass)
  block('base transom glazing',u,-.3,9.0,pitch*.73,.14,3.3,glass)
  block('rusticated base pier',u+pitch*.48,-.45,6,pitch*.12,.9,12,white)
  for z in [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0]:
   block('rusticated pier course',u+pitch*.48,-.94,z,pitch*.14,.08,.07,stone)
  for z in [1,5.9,7.2,10.8]:
   block('base lintel',u,-.55,z,pitch*.85,.8,.25,ornament)
 for z,d,h in [(0.35,.9,.7),(11.5,1.3,.55),(12.1,1.0,.4),(57.0,1.2,.45),(68.8,1.4,.45),(74.0,1.8,.4),(74.5,2.3,.45),(75.0,2.5,.35)]:
  d=min(d,.85)  # Keep the roof moulding inside the mapped street clearance.
  block('continuous projecting cornice',span/2,-d/2,z,span+.45,d,h,stone if z<1 else ornament)
 for i in range(int(span/.55)):
  block('cornice dentil',i*.55,-.55,74.4,.22,.7,.27,ornament)
facade((lo,0),(1,0),(0,1),width,12,'Michigan')
facade((hi,depth),(-1,0),(0,-1),width,12,'Rear')
facade((hi,0),(0,1),(-1,0),depth,12,'South')
facade((lo,depth),(0,-1),(1,0),depth,12,'North')
# Recessed central entrance, lettering and small historic rooftop office.
box('Central bronze entrance',((lo+hi)/2,-.48,3.0),(4.1,.25,5.4),bronze)
text('Entrance name','RAILWAY EXCHANGE',((lo+hi)/2,-1.02,7.0),.65,ornament,depth=.035)
box('Roof penthouse',((lo+hi)/2,depth-10,78.0),(13,8,6),white)
for x in [-4,0,4]:
 box('Penthouse sash',((lo+hi)/2+x,depth-14.1,78.0),(2.2,.12,3.2),glass)
finish('railway_exchange',OUT)

