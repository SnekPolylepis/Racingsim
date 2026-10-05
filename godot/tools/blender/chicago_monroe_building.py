"""Original Monroe Building exterior. Blender +Y north, +Z up; photo-derived detail."""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, arch, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Warm pale terracotta wall piers',(.61,.52,.41),roughness=.88)
trim=material('Carved pale terracotta surrounds',(.71,.61,.49),roughness=.88)
granite=material('Granite street base',(.31,.29,.26),roughness=.82)
dark=material('Dark recessed sash and backing',(.055,.048,.038),roughness=.8)
glass=material('Individual office glazing',(.15,.20,.22),roughness=.5)
night=material('Night occupied office glazing',(.22,.19,.13),roughness=.5,glow=.3)
iron=material('Dark cast iron entry and sash',(.095,.085,.065),roughness=.6)
tile=material('Green glazed Spanish roof tiles',(.12,.21,.17),roughness=.9)
W,D,EAVE,TOP=54.4,27.4,64.0,74.0

def box(name,p,size,mat):
 o=baked_box(name,(0,0,0),size,mat);o.location=p;return o

def orient(objects,p,angle):
 c,s=math.cos(angle),math.sin(angle)
 for o in objects:
  x,y,z=o.location;o.location=(p[0]+x*c-y*s,p[1]+x*s+y*c,z);o.rotation_euler.z+=angle

box('Inset tower backing',(0,0,(EAVE+7)/2),(W-.5,D-.5,EAVE-7),dark)
box('Mapped foundation',(0,0,-3.9),(W,D,8.2),granite)
street_base=box('Solid street base',(0,0,3.5),(W-.15,D-.15,7),granite)
box('Roof cornice deck',(0,0,EAVE-.15),(W+.4,D+.4,.3),trim)
# Physical pitched roof, gable at both short ends, ridge along east/west.
v=[(x,y,z) for x in [-W/2,W/2] for y,z in [(-D/2,EAVE),(D/2,EAVE),(0,TOP)]]
mesh('Solid pitched tiled roof',v,[(0,1,4,3),(0,3,5,2),(2,5,4,1)],tile)

for n in range(55):
 x=-W/2+n*W/54
 for side in [-1,1]:
  line('Raised roof tile course',[(x,0,TOP+.03),(x,side*D/2,EAVE+.03)],.055,tile)

# Each frontage has actual separate paired panes, stone piers and carved spandrels.
def facade(width,p,angle,pairs,entry=False):
 before=set(bpy.context.scene.objects)
 pitch=width/pairs
 for n in range(pairs):
  x=-width/2+(n+.5)*pitch
  for row in range(14):
   lo=7+row*(EAVE-7)/14;hi=7+(row+1)*(EAVE-7)/14;h=hi-lo
   pane_w=pitch*.30
   for side in [-1,1]:
    at=x+side*pitch*.18
    box('Separate recessed pane',(at,-.15,(lo+hi)/2+.05),(pane_w,.045,h*.69),night if (n*7+row*3)%13==0 else glass)
    box('Window cross rail',(at,-.025,(lo+hi)/2+.05),(pane_w,.12,.06),iron)
    for edge in [-1,1]:
     box('Stone pane jamb',(at+edge*pane_w/2,0,(lo+hi)/2+.05),(.10,.4,h*.76),trim)
   box('Raised pair centre pier',(x,0,(lo+hi)/2),(pitch*.06,.44,h),stone)
   box('Carved horizontal spandrel',(x,.0,lo+.05),(pitch,.34,h*.31),stone)
   # Small physical diamonds stand proud of the spandrel; detailed relief remains approximate.
   o=box('Spandrel relief lozenge',(x,-.24,lo+.35),(.25,.10,.25),trim);o.rotation_euler.y=math.pi/4
  if not entry or abs(x)>2.4+pitch*.335:
   box('Ground recessed paired glazing',(x,-.18,3.0),(pitch*.67,.045,4.9),glass)
  if not entry or abs(x-pitch/2)>2.4:
   box('Granite ground pier',(x-pitch/2,0,3.5),(.55,.65,7),granite)
  if not entry or abs(x)>2.4+pitch*.335:
   box('Ground transom rail',(x,-.05,4.7),(pitch*.68,.13,.10),iron)
 for edge in range(pairs+1):
  x=-width/2+edge*pitch;w=pitch*.34
  if edge==0:x+=w/4;w/=2
  elif edge==pairs:x-=w/4;w/=2
  box('Continuous bounded bay pilaster',(x,0,(7+EAVE)/2),(w,.48,EAVE-7),stone)
 for h in [7,52,60,63.7]:
  box('Projecting terracotta cornice',(0,-.1,h),(width+.35,.7,.24),trim)
 for n in range(round(width/.48)):
  box('Cornice dentil',(-width/2+(n+.5)*.48,-.36,63.35),(.21,.30,.35),trim)
 orient(set(bpy.context.scene.objects)-before,p,angle)
facade(D,(W/2,0),math.pi/2,5,True)
facade(D,(-W/2,0),-math.pi/2,5)
facade(W,(0,D/2),math.pi,10,True)
facade(W,(0,-D/2),0,10)
# Short-end gables: paired round-head windows and raised raking cornices.
for x,angle in [(W/2,math.pi/2),(-W/2,-math.pi/2)]:
 before=set(bpy.context.scene.objects)
 triangle=[(-D/2,EAVE),(D/2,EAVE),(0,TOP)]
 gable=mesh('Solid terracotta gable with window openings',[(a,y,z) for y in [0,.4] for a,z in triangle],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],stone)
 for a,b in [((-D/2,-.12,EAVE),(0,-.12,TOP)),((0,-.12,TOP),(D/2,-.12,EAVE))]:
  line('Raking carved gable cornice',[a,b],.17,trim)
 for centre,base in [(-5.3,64.6),(0,68.0),(5.3,64.6)]:
  for side in [-1,1]:
   at=centre+side*.63
   profile=[(at-.58,base),(at+.58,base)]+[(at+.58*math.cos(t*math.pi/20),base+1.7+.58*math.sin(t*math.pi/20)) for t in range(21)]
   n=len(profile)
   cutter=mesh('Temporary round-head opening cutter',[(a,y,z) for y in [-1,1] for a,z in profile],[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n)],dark)
   bpy.context.view_layer.objects.active=gable
   mod=gable.modifiers.new('Actual recessed round-head window','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
   bpy.ops.object.modifier_apply(modifier=mod.name)
   bpy.data.objects.remove(cutter,do_unlink=True)
   mesh('Separate recessed round-head gable glazing',[(a,.19,z) for a,z in profile],[tuple(range(n))],glass)
   box('Gable window transom',(at,.12,base+1.7),(1.1,.08,.07),iron)
   arch('Round-head gable surround',.58,.73,(at,base+1.7),-.12,.3,trim)
   for edge in [-1,1]:box('Gable window upright',(at+edge*.56,-.04,base+.85),(.14,.3,1.7),trim)
 orient(set(bpy.context.scene.objects)-before,(x,0),angle)
# Dormers along each roof slope retain separate physical projecting roof forms.
for side in [-1,1]:
 for n in range(6):
  x=-W/2+(n+1)*W/7;y=side*D*.28;z=TOP-abs(y)*(TOP-EAVE)/(D/2)
  box('Roof dormer cheek',(x,y,z+.3),(1.8,1.2,1.1),stone)
  box('Dormer dark pane',(x,y+side*.63,z+.4),(1.1,.05,.8),glass)
  box('Dormer tiled cap',(x,y,z+.95),(2.1,1.5,.18),tile)
# Photo-derived cast-iron entries; turquoise Rookwood surround follows the 77 E Monroe reference.
blue=material('Turquoise glazed Rookwood entry tiles',(.035,.27,.28),roughness=.34)
bronze=material('Aged bronze door kickplates and lettering',(.34,.24,.10),metallic=.65,roughness=.5)
interior=material('Warm tiled entry vestibule',(.39,.29,.15),roughness=.8)
clear=material('Clear recessed entrance glazing',(.27,.34,.32),roughness=.45)
clear.diffuse_color=(.27,.34,.32,.18)
clear.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.18
for origin,angle,address in [((0,D/2),math.pi,'77 EAST MONROE'),((W/2,0),math.pi/2,'104 SOUTH MICHIGAN')]:
 before=set(bpy.context.scene.objects)
 profile=[(-2,0),(2,0)]+[(2*math.cos(t*math.pi/32),3.9+2*math.sin(t*math.pi/32)) for t in range(33)]
 n=len(profile)
 cutter=mesh('Temporary entry opening',[(a,y,z) for y in [-2,2] for a,z in profile],[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n)],dark)
 orient([cutter],origin,angle)
 bpy.context.view_layer.objects.active=street_base
 mod=street_base.modifiers.new('Open entry vestibule','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.data.objects.remove(cutter,do_unlink=True)
 box('Vestibule rear tiled wall',(0,1.6,2.6),(4,.12,5.2),interior)
 box('Vestibule tiled floor',(0,.8,.06),(4,1.8,.12),interior)
 arch('Entry grout backing',2.0,2.43,(0,3.9),-.25,.4,trim)
 for i in range(24):
  arch('Separate glazed arch tile',2.02,2.40,(0,3.9),-.28,.40,blue,start=i*math.pi/24+.008,end=(i+1)*math.pi/24-.008,segments=2)
 for side in [-1,1]:
  for row in range(13):box('Glazed tile jamb',(side*2.22,-.08,(row+.5)*.3),(.4,.40,.285),blue)
  box('Cast iron door jamb',(side*1.95,.05,1.9),(.13,.18,3.8),iron)
  box('Separate clear door pane',(side*.98,.20,1.9),(1.78,.045,2.55),clear)
  box('Bronze door kickplate',(side*.98,.1,.40),(1.78,.14,.7),bronze)
  box('Door pull handle',(side*.16,-.01,1.65),(.06,.16,.55),iron)
 box('Cast iron centre stile',(0,.05,1.95),(.12,.18,3.9),iron)
 for h in [.78,3.25,3.88]:box('Cast iron entry transom',(0,.04,h),(4,.18,.12),iron)
 box('Clear lettered transom',(0,.20,3.56),(3.8,.045,.53),clear)
 fan=[(0,.2,3.9)]+[(1.98*math.cos(i*math.pi/32),.2,3.9+1.98*math.sin(i*math.pi/32)) for i in range(33)]
 mesh('Clear semicircular entrance fanlight',fan,[tuple(range(len(fan)))],clear)
 for i in range(13):
  a=i*math.pi/12
  line('Physical fanlight radial ironwork',[(0,.02,3.9),(1.95*math.cos(a),.02,3.9+1.95*math.sin(a))],.025,iron)
 text('Raised entrance lettering','MONROE BUILDING',(0,-.035,3.68),.23,bronze,depth=.014)
 text('Raised entrance address',address,(0,-.035,3.43),.16,bronze,depth=.014)
 orient(set(bpy.context.scene.objects)-before,origin,angle)
finish('monroe_building',OUT)
