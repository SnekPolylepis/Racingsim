"""Original 300 South Wacker exterior; mapped footprint, +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bronze=material('Bronze aluminum curtain wall',(.17,.15,.13),metallic=.25,roughness=.68)
glass=material('Recessed bronze tinted office glass',(.13,.17,.18),roughness=.52)
occupied=material('Night occupied office glass',(.13,.17,.18),roughness=.52,glow=.2)
dark=material('Dark mechanical and roof recesses',(.045,.055,.055),roughness=.85)
granite=material('Cold grey granite plaza and columns',(.42,.43,.42),roughness=.9)
clear=material('Recessed renovated lobby glazing',(.25,.31,.31),roughness=.5)
light=material('Night warm lobby ceiling fixtures',(.75,.68,.49),roughness=.7,glow=.2)
white=material('Pale lobby ceiling and entrance portal',(.68,.69,.65),roughness=.82)
wall=material('River elevator core map wall',(.31,.34,.33),roughness=.9)
streets=material('Pale original map linework',(.60,.62,.60),roughness=.85)
river=material('Grey river map channels',(.42,.47,.47),roughness=.85)
marker=material('Night red map locator',(.48,.025,.018),roughness=.7,glow=.2)
cx,cz=-1055.4,793.45
city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
b=next(b for b in city['buildings'] if b.get('o')=='w147350178')
plan=[(x-cx,-(z-cz)) for x,z in b['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def orient(obj,a,b):
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d;nx,ny=ty,-tx
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*nx,a[1]+x*ty+y*ny,z)
 for p in obj.data.polygons:p.flip()
 return obj
def part(name,pos,size,mat,a,b):return orient(box(name,pos,size,mat),a,b)
# ponytail: retain mapped133m height; measured elevations and detailed mural survey will supersede photo-fit proportions.
BASE,ROOF,TOP=6.,130.,133.
PITCH=(ROOF-BASE)/34
prism('Retained nine vertex foundation',plan,-8,.1,granite)
prism('Raised lobby floor',plan,.7,.8,granite)
prism('Recessed office backing',[(x*.94,y*.98) for x,y in plan],BASE,ROOF,dark)
prism('Recessed flat service roof',[(x*.99,y*.997) for x,y in plan],130,130.2,dark)
for a,b in zip(plan,plan[1:]+plan[:1]):
 length=math.dist(a,b)
 if length<3:continue
 core=(a[0]+b[0])/2<-10 and 24<length<28
 if core:
  part('Solid river elevator core',(length/2,0,(TOP+.8)/2),(length,.24,TOP-.8),wall,a,b)
  # Original physical map interpretation: layered street grid and branching river, no photo plane.
  def stroke(name,points,width,mat,depth=.155):
   for (x,z),(u,v) in zip(points,points[1:]):
    dx,dz=u-x,v-z;d=math.hypot(dx,dz);nx,nz=-dz/d*width/2,dx/d*width/2
    o=mesh(name,[(x+nx,depth,z+nz),(x-nx,depth,z-nz),(u-nx,depth,v-nz),(u+nx,depth,v+nz)],[(3,2,1,0)],mat)
    orient(o,a,b)
  for h in (2,6,10,14,19,23):
   stroke('Upper north south map street',[(h,58),(h,131)],.22,streets)
  for h in (2,5,8):stroke('Lower north south map street',[(h,8),(h,70)],.22,streets)
  for z in range(58,130,7):stroke('Upper cross town map street',[(.6,z),(length-.6,z)],.22,streets)
  for z in (12,28,44):stroke('Lower cross town map street',[(.6,z),(10,z)],.22,streets)
  path=[(14,2),(14,18),(12,28),(13,38),(15,48),(15,61),(12,69),(12,78),(9,88),(5,96),(3,108),(2,126)]
  stroke('Broad branching river channel',path,1.3,river,.17)
  stroke('East west river map arm',[(12,78),(16,83),(20,88),(24,93)],1.3,river,.17)
  for h in (7,19):stroke('Diagonal map avenue',[(h,38),(h+4,55),(h+3,72),(h-3,89),(h-4,108)],.22,streets,.19)
  part('Red you are here locator',(15.0,.30,61),(1.0,.18,2.3),marker,a,b)
  part('Pale locator border',(15.0,.22,61),(1.4,.08,2.7),white,a,b)
  continue
 cols=max(1,round(length/2.05));pitch=length/cols
 for row in range(34):
  z=BASE+row*PITCH;mechanical=row in (18,19)
  part('Continuous bronze floor spandrel',(length/2,.035,z+.63),(length,.22,1.26),bronze,a,b)
  part('Floor sill rail',(length/2,.06,z+1.31),(length,.26,.10),bronze,a,b)
  for col in range(cols):
   h=(col+.5)*pitch
   mat=dark if mechanical else occupied if (row*13+col*7)%31 in (2,9,17) else glass
   part('Separate recessed vision pane',(h,-.20,z+2.49),(pitch-.15,.055,2.24),mat,a,b)
   if mechanical:
    for k in range(8):part('Recessed mechanical louver',(h,-.07,z+1.47+k*.28),(pitch-.16,.12,.045),bronze,a,b)
  for col in range(cols+1):
   part('Projecting bronze vertical mullion',(col*pitch,.12,z+PITCH/2),(.13,.36,PITCH),bronze,a,b)
 part('Flat metal rooftop fascia',(length/2,.04,131.6),(length,.30,2.8),bronze,a,b)
 for col in range(cols+1):
  structural=col%5==0 or col==cols
  part('Granite street level column' if structural else 'Thin bronze lobby mullion',(col*pitch,-.05 if structural else -.83,3.0),(.48,.65,6) if structural else (.09,.18,6),granite if structural else bronze,a,b)
 east=(a[0]+b[0])/2>5 and length>60
 for col in range(cols):
  h=(col+.5)*pitch;entry=east and abs(h-length/2)<3.2
  depth=-1.75 if entry else -.95
  part('Separate recessed lobby glass',(h,depth,3.22),(pitch-.20,.065,4.78),clear,a,b)
  for zz in (1.,5.57):part('Lobby transom',(h,depth+.1,zz),(pitch-.15,.12,.10),bronze,a,b)
  if entry:
   part('Entry door pull',(h,depth+.2,2.25),(.04,.10,.65),bronze,a,b)
 part('Lobby head beam',(length/2,.02,5.8),(length,.7,.4),bronze,a,b)
 if east:
  h=length/2
  for step in range(4):part('Physical entry stair',(h,.20+step*.35,.10+step*.10),(8.0,2.1-step*.35,.20+step*.20),granite,a,b)
  part('Entry portal canopy',(h,-.55,5.67),(8.0,2.7,.16),white,a,b)
  for side in (-1,1):part('Pale entry portal jamb',(h+side*4,-.4,3.2),(.30,2.2,4.9),white,a,b)
  part('Recessed lobby luminous ceiling',(h,-2.5,5.5),(9.0,4.4,.05),light,a,b)
  part('Pale interior lobby rear wall',(h,-7.0,3.2),(length,.20,4.8),white,a,b)
  part('Pale lobby ceiling',(h,-3.5,5.65),(length,7,.15),white,a,b)
  part('Entrance number granite pedestal',(h-8,.55,.95),(3.6,1.4,.5),granite,a,b)
  address=text('Physical entrance number','300',(h-8,1.28,1.75),1.1,light,rotate=(math.pi/2,0,0))
  bpy.ops.object.select_all(action='DESELECT');address.select_set(True);bpy.context.view_layer.objects.active=address
  bpy.ops.object.convert(target='MESH');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  orient(bpy.context.object,a,b)
  for col in range(-2,3):part('Lobby interior granite column',(h+col*6,-3.6,3.1),(.55,.55,4.6),granite,a,b)
# Roof equipment stays low behind the parapet, physically modeled rather than a flat rooftop image.
for y in (-20,-8,4,16,28):
 box('Service roof cabinet',(0,y,131.1),(3.6,4.5,1.8),bronze)
 box('Recessed service cabinet grille',(1.83,y,131.1),(.055,4.1,1.4),dark)
 for k in range(8):box('Roof cabinet grille slat',(1.89,y,130.49+k*.17),(.12,4.1,.04),bronze)
assert len(plan)==9 and abs(BASE+34*PITCH-ROOF)<.001
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
  assert all(-8.01<=v.co.z<=TOP+.01 for v in o.data.vertices),o.name
finish('wacker_300',OUT)
