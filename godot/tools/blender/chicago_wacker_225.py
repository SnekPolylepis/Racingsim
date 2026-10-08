"""Original 225 West Wacker exterior, photo-fit; +Y north, +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Pale granite piers and coursed spandrels',(.53,.54,.51),roughness=.88)
glass=material('Blue grey recessed vision glass',(.12,.20,.25),roughness=.48)
occupied=material('Night occupied vision glass',(.12,.20,.25),roughness=.48,glow=.2)
metal=material('Grey window frames and crown metal',(.31,.35,.36),metallic=.25,roughness=.65)
dark=material('Roof and mechanical recesses',(.07,.09,.10),roughness=.85)
clear=material('Clear renovated lobby glazing',(.36,.43,.44),roughness=.42)
wood=material('Night warm lobby wood screens',(.39,.26,.14),roughness=.8,glow=.12)
light=material('Night lobby ceiling lights',(.74,.68,.52),roughness=.6,glow=.2)
cx,cz=-886.,-164.75
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
mapped=next(b for b in city['buildings'] if b.get('o')=='w64391366')
plan=[(x-cx,-(z-cz)) for x,z in mapped['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()

def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)

prism('Mapped foundation',plan,-8,.12,stone)
# ponytail: retain mapped 126.5m total; reconcile published 375/433ft before measured-height claim.
BASE,BODY,CROWN,TOP=10.,100.,116.,126.5
prism('Recessed opaque office backing',[(x*.96,y*.99) for x,y in plan],BASE,BODY,dark)
prism('Roof below barrel vault',plan,BODY-.3,BODY,dark)

def facade(a,b):
 x,y=a;u,v=b
 width=math.hypot(u-x,v-y)
 if width<1:return
 tx,ty=(u-x)/width,(v-y)/width
 nx,ny=ty,-tx
 def part(name,h,d,z,w,t,height,mat):
  ob=box(name,(0,0,0),(w,t,height),mat)
  # Baked boxes rotate through their vertices, matching mapped irregular edges.
  for vert in ob.data.vertices:
   px,py,pz=vert.co
   vert.co=(x+tx*(h+px)+nx*(d+py),y+ty*(h+px)+ny*(d+py),z+pz)
  for polygon in ob.data.polygons:polygon.flip()
  ob.data.update()
  return ob
 cols=max(1,round(width/2.6));pitch=width/cols
 for row in range(27):
  bottom=BASE+row*(BODY-BASE)/27
  for col in range(cols):
   h=(col+.5)*pitch
   channel=width*.06<abs(h-width/2)<width*.23
   depth=-.28 if channel else -.06
   mat=occupied if (row*7+col*11)%29 in (1,4,11) else glass
   part('Individual recessed office pane',h,depth,bottom+1.82,pitch-(.25 if channel else .8),.055,2.28,mat)
   part('Opaque spandrel between floors',h,.01,bottom+.38,pitch-.25,.22,.76,metal if channel else stone)
   part('Window sill',h,depth+.08,bottom+2.98,pitch-.26,.14,.09,metal)
  for col in range(cols+1):
   h=col*pitch
   channel=width*.06<abs(h-width/2)<width*.23
   part('Granite pier or channel mullion',h,.05 if channel else .16,bottom+1.67,.18 if channel else .75,.18 if channel else .4,3.34,metal if channel else stone)
 for z in (BASE,BODY-10,BODY):part('Projecting tier cornice',width/2,.25,z,width,.7,.45,stone)
 # Open ground floor with real recess behind granite structural piers.
 for col in range(cols+1):part('Street level structural pier',col*pitch,-.02,BASE/2,.64,.72,BASE,stone)
 for col in range(cols):
  if not (y>47 and v>47 and abs(x+tx*(col+.5)*pitch)<6):
   part('Recessed clear lobby pane',(col+.5)*pitch,-1.35,4.6,pitch-.10,.055,8.8,clear)
  part('Ground storefront transom',(col+.5)*pitch,-1.25,3.5,pitch,.12,.12,metal)
 for z in (6.5,7,7.5,8):part('Ground upper granite courses',width/2,.08,z,width,.25,.23,stone)
for a,b in zip(plan,plan[1:]+plan[:1]):facade(a,b)

# Four independent corner towers, visible longitudinal glazing and stepped metal caps.
for x in (-10.5,10.5):
 for y in (-40.,40.):
  box('Crown tower dark backing',(x,y,108),(10,16,16),dark)
  for side in (-1,1):
   for col in range(4):
    px=x+(col-1.5)*2.3
    box('Crown long vision pane',(px,y+side*8.05,108),(1.9,.055,15.1),glass)
    box('Crown vertical granite jamb',(px-1.08,y+side*8.18,108),(.26,.36,16),stone)
   box('Crown tower cap',(x,y+side*8.1,116),(10.4,.5,.5),stone)
  for side in (-1,1):
   for col in range(6):
    py=y+(col-2.5)*2.5
    box('Crown side vision pane',(x+side*5.05,py,108),(.055,2.12,15.1),glass)
    box('Crown side granite jamb',(x+side*5.18,py-1.17,108),(.36,.26,16),stone)
  box('Stepped turret square base',(x,y,118),(10,15,4),stone)
  for dx in (-4.7,4.7):
   box('Projecting turret buttress',(x+dx,y,120),(.7,6,5),metal)
   for yy in (-3,3):line('Raised turret metal ribs',[(x+dx,y+yy,117),(x+dx,y+yy,122)],.07,metal)
  for radius,z,depth in ((3.7,121,2),(2.7,122.7,1.4),(1.9,123.65,.5),(.42,125.,3)):
   bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=(x,y,z))
   bpy.context.object.name='Stepped circular turret cap' if radius>1 else 'Turret finial'
   bpy.context.object.data.materials.append(metal)
# Barrel roof between corner crowns; real curved surface, seams and end arch ribs.
verts=[]
for y in (-40,40):
 for i in range(33):
  a=i*math.pi/32
  verts.append((5.5*math.cos(a),y,110+6*math.sin(a)))
mesh('Long central barrel vault',verts,[(i,i+33,i+34,i+1) for i in range(32)],metal)
for y in range(-40,41,8):line('Barrel vault curved seam',[(5.53*math.cos(i*math.pi/32),y,110+6.03*math.sin(i*math.pi/32)) for i in range(33)],.055,stone)
for y in (-48.,48.):
 for x in [-5+i for i in range(11)]:
  top=110+6*math.sqrt(max(0,1-(x/5.5)**2))
  box('Central crown end glass',(x,y, (100+top)/2),(.93,.06,top-100),glass)
  box('Central crown end mullion',(x-.5,y+.12,(100+top)/2),(.1,.2,top-100),metal)
 line('Crown end arched truss',[(5.5*math.cos(i*math.pi/32),y,110+6*math.sin(i*math.pi/32)) for i in range(33)],.14,stone)
 for z in range(102,111,2):box('Crown end transom',(0,y+.12,z),(11,.2,.10),metal)
# North Wacker half-rotunda glazing retained within the mapped foundation.
for i in range(24):
 a=i*math.pi/24;b=(i+1)*math.pi/24
 x,y=6*math.cos(a),41+6*math.sin(a)
 u,v=6*math.cos(b),41+6*math.sin(b)
 mesh('Half rotunda clear curved frontage',[(x,y,.2),(u,v,.2),(u,v,9.4),(x,y,9.4)],[(0,1,2,3)],clear)
 if i%3==0:line('Rotunda vertical frame',[(x,y,.2),(x,y,9.4)],.065,metal)
for z in (3.5,9.4):line('Rotunda curved transom',[(6*math.cos(i*math.pi/48),41+6*math.sin(i*math.pi/48),z) for i in range(49)],.07,metal)
# Renovated lobby uses the architect's white columns, wood screens and exposed lights.
box('Lobby floor',(0,0,.16),(28,93,.08),stone)
box('Lobby ceiling',(0,0,9.6),(28,93,.22),stone)
for y in range(-36,37,12):
 for x in (-8,8):
  bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.65,depth=9.5,location=(x,y,4.85))
  bpy.context.object.name='Round pale lobby column';bpy.context.object.data.materials.append(stone)
  box('Wood screen behind lobby',(x*.6,y,2.2),(.18,5.2,4),wood)
  for xx in (-9,0,9):box('Lobby ceiling linear light',(xx,y,9.44),(4,.08,.025),light)
box('Interior elevator core',(0,0,4.9),(9,45,9.5),stone)
text('North entry address','225 WEST WACKER',(0,47.05,5.6),.55,metal,rotate=(math.pi/2,0,math.pi))
# Numeric checks catch inverted geometry and crown overshoot before export.
assert len(plan)==7 and all(math.isfinite(v) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.data.vertices for v in p.co)
assert max(p.co.z+o.location.z for o in bpy.context.scene.objects if o.type=='MESH' for p in o.data.vertices)<=TOP+.01
finish('wacker_225',OUT)
