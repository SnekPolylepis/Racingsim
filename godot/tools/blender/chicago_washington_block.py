"""Washington Block: authored limestone frontage and chamfer from city photos."""
import bpy,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,arch,text,line,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Limestone facade',(.61,.58,.50),roughness=.94)
trim=material('Projecting carved limestone surrounds',(.70,.66,.56),roughness=.9)
glass=material('Separate recessed opaque panes',(.12,.19,.20),roughness=.6)
metal=material('Dark sash and cornice',(.065,.085,.075),metallic=.2)
back=material('Opaque interior backing',(.035,.04,.035),roughness=1)
rear=material('Unsurveyed party masonry and roof',(.34,.31,.26),roughness=.96)
# Mapped height retained, not independently surveyed. Coordinates fit the mapped chamfer.
H=24
ring=[(-6.7,15.35),(2.8,15.55),(6.4,12.15),(6.7,-15.25),(-6.2,-15.55),(-6.7,14.35)]
for z,h,mat in [(-4,8,stone),(11.5,23,back),(23.1,.25,rear)]:
 pts=[(x,y,z-h/2) for x,y in ring]+[(x,y,z+h/2) for x,y in ring]
 mesh('Chamfered foundation interior and roof',pts,[tuple(range(5,-1,-1)),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],mat)
# Interior core is inset; public walls below have actual apertures.
core=bpy.context.scene.objects.get('Chamfered foundation interior and roof.001')
if core:core.scale.x=.88;core.scale.y=.95
for edge in range(5):
 a,b=ring[edge],ring[(edge+1)%6]
 length=math.dist(a,b);angle=math.atan2(b[1]-a[1],b[0]-a[0])+math.pi
 origin=((a[0]+b[0])/2,(a[1]+b[1])/2,0)
 def placed(obj):obj.rotation_euler.z=angle;obj.location=origin;return obj
 def part(name,x,z,w,h,depth,t,mat):return placed(box(name,(x,depth,z),(w,t,h),mat))
 if edge not in [0,1,2]:
  part('Plain party wall',0,H/2,length,H,0,.35,rear);continue
 cols=3 if edge==0 else (2 if edge==1 else 9)
 pitch=length/cols;w=min(1.55,pitch-.58)
 for i in range(cols+1):part('Full limestone pier',-length/2+i*pitch,12,pitch-w,24,0,.55,stone)
 for z,h in [(.3,.6),(4.35,1.3),(9.5,1.0),(14.0,1.0),(18.5,1.0),(23.25,.55)]:part('Solid limestone spandrel',0,z,length,h,0,.55,stone)
 for row,z in enumerate([6.85,11.75,16.25,20.4]):
  for col in range(cols):
   x=(col-(cols-1)/2)*pitch
   wh=3.3 if row==0 else 3.35
   part('Inset opaque pane',x,z,w,wh,.42,.035,glass)
   for dx in [-w/2,w/2]:
    part('Separate stone jamb',x+dx,z,.13,wh+.2,-.05,.45,trim)
    part('Dark sash stile',x+dx,z,.06,wh,.27,.10,metal)
   part('Dark sash crossrail',x,z,w,.06,.27,.10,metal)
   part('Projecting sill',x,z-wh/2-.1,w+.35,.19,-.15,.75,trim)
   if row==3:
    placed(arch('Arched top surround',w/2,w/2+.18,(x,z+wh/2),-.28,.45,trim))
    points=[(x,.40,z+wh/2)]+[(x+w/2*math.cos(i*math.pi/24),.40,z+wh/2+w/2*math.sin(i*math.pi/24)) for i in range(25)]
    placed(mesh('Physical arched transom',points,[(0,i,i+1) for i in range(1,25)],glass))
   else:
    for dz,ww in [(wh/2+.12,w+.3),(wh/2+.30,w+.55)]:part('Stepped window hood',x,z+dz,ww,.18,-.16,.60,trim)
   part('Central projecting hood tablet',x,z+wh/2+.42,.4,.36,-.3,.72,trim)
   for dx in [-w/2-.18,w/2+.18]:part('Hood side corbel',x+dx,z+wh/2,.22,.45,-.2,.6,trim)
 for z,widen,t in [(23.2,.2,.8),(23.5,.55,1.0),(23.9,.9,1.25)]:part('Projecting cornice tier',0,z,length+widen,.22,-.15,t,metal)
 for x in [(-length/2+.3+i*.65) for i in range(int(length/.65))]:
  part('Cornice bracket',x,23.25,.20,.55,-.30,.8,metal)
 for col in range(cols):
  x=(col-(cols-1)/2)*pitch
  part('Ground storefront pane',x,2.15,pitch-.5,3.2,.55,.04,glass)
  for dx in [-(pitch-.5)/2,0,(pitch-.5)/2]:part('Storefront frame',x+dx,2.15,.08,3.3,.35,.15,metal)
 if edge==1:
  placed(text('Raised Washington Block lettering','WASHINGTON BLOCK',(0,-.35,18.3),.27,trim))
  placed(arch('Second floor corner entrance arch',1.4,1.65,(0,7.3),-.45,.65,trim))
  for x in [-1.55,1.55]:part('Corner entrance column',x,6.0,.25,2.6,-.35,.70,trim)
# ponytail: relief profiles approximate; surveyed carving and fire escape routing need better references.
finish('washington_block',OUT)
