"""Equitable Building: authored physical south facade from owner photos."""
import bpy,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,mesh,line,arch,text,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Pale limestone facade and surrounds',(.56,.54,.48),roughness=.92)
trim=material('Carved projecting stone trim',(.63,.61,.54),roughness=.88)
metal=material('Dark bronze sashes and bank facade',(.105,.10,.085),metallic=.22)
glass=material('Separate recessed window panes',(.13,.19,.21),roughness=.55)
back=material('Opaque recessed interior',(.04,.035,.028),roughness=.95)
base=material('Dark ground level stone',(.18,.18,.17),roughness=.85)
roof=material('Roof and party masonry',(.34,.31,.27),roughness=.95)
W,D,H=12.5,30.8,50.5 # Photo-proportion estimate; mapped53m not surveyed.
F=-D/2
box('Foundation',(0,0,-4),(W,D,8),base)
box('Inset interior backing',(0,.6,24),(W-1.0,D-1.8,48),back)
for x in [-W/2+.15,W/2-.15]:box('Plain party wall',(x,0,24),(.3,D,48),roof)
box('Rear masonry',(0,D/2-.15,24),(W,.3,48),roof)
box('Roof',(0,0,47.5),(W,D,.3),roof)
def part(name,x,z,w,h,depth,t,mat):return box(name,(x,F+depth,z),(w,t,h),mat)
def sash(x,z,w,h):
 part('Separate recessed glazing',x,z,w,h,.46,.035,glass)
 for dx in [-w/2,w/2]:part('Bronze sash stile',x+dx,z,.07,h,.29,.13,metal)
 for dz in [-h/2,.12,h/2]:part('Bronze sash rail',x,z+dz,w,.07,.29,.13,metal)
 for dx in [-w/2-.08,w/2+.08]:part('Stone window jamb',x+dx,z,.13,h+.2,0,.4,trim)
 part('Projecting pane sill',x,z-h/2-.1,w+.24,.18,-.08,.55,trim)
# Three structural groups: pairs at sides, three narrow central panes.
windows=[-4.66,-3.21,-1.46,0,1.46,3.21,4.66]
piers=[(-5.85,.8),(-2.33,.65),(2.33,.65),(5.85,.8)]
for x,w in piers:part('Full height stone pier',x,28,w,39,0,.65,stone)
for x in [-.73,.73,-3.935,3.935]:part('Narrow stone mullion',x,28,.18,39,0,.55,stone)
for row in range(9):
 z=11.8+row*3.75
 part('Solid office spandrel',0,z-1.75,W,1.05,0,.65,stone)
 for x in windows:
  sash(x,z,1.18,2.55)
  part('Relief spandrel tablet',x,z-1.75,1.0,.65,-.13,.25,trim)
  for dx in [-.42,.42]:part('Tablet raised edge',x+dx,z-1.75,.04,.55,-.29,.06,stone)
# Spiral ribs wrapped round the three primary facade column shafts.
for x in [-5.60,-2.33,2.33,5.60]:
 line('Round column shaft',[(x,F-.32,9.8),(x,F-.32,28.0)],.20,trim)
 for offset in [0,math.pi]:
  pts=[]
  for i in range(241):
   z=9.8+i*18.2/240; a=i*math.pi*2*12/240+offset
   pts.append((x+.22*math.cos(a),F-.32+.22*math.sin(a),z))
  line('Physical spiral column rib',pts,.045,stone)
 for z in [9.8,28.0]:part('Column capital and foot',x,z,.64,.3,-.3,.9,trim)
part("Solid crown-level spandrel",0,44.25,W,2.7,0,.65,stone)
# Last row under three arched pediments; opaque masonry assembled around apertures.
for x,r in [(-3.935,1.45),(0,2.12),(3.935,1.45)]:
 z=46.8
 width=2*r-.25
 # rectangular bank of panes under a smaller arched transom.
 count=3 if x==0 else 2
 for i in range(count):sash(x+(i-(count-1)/2)*1.43,z,1.18,2.65)
 arch('Upper semicircular stone window head',r-.16,r+.12,(x,48.0),F-.12,.5,trim,segments=24)
 # Semicircular transom pane with opaque solid backing farther in.
 verts=[(x,F+.43,48.0)]+[(x+(r-.23)*math.cos(i*math.pi/24),F+.43,48+(r-.23)*math.sin(i*math.pi/24)) for i in range(25)]
 mesh('Inset arched transom',verts,[(0,i+1,i+2) for i in range(24)],glass)
 part('Upper transom horizontal bar',x,48,width,.08,.24,.13,metal)
 part('Upper transom centre bar',x,48.5,.07,1.0,.24,.13,metal)
# Curved ornamental crown silhouette follows the three pediments.
for x,r in [(-3.935,1.55),(0,2.3),(3.935,1.55)]:
 arch('Projecting curved roof crown',r,r+.20,(x,47.9),F-.38,.8,trim,segments=24)
 for i in range(9):
  a=i*math.pi/8
  part('Crown dentil',x+(r+.2)*math.cos(a),47.9+(r+.2)*math.sin(a),.16,.25,-.28,.75,stone)
arch('Central roof medallion frame',.38,.62,(0,50.0),F-.45,.55,trim,end=2*math.pi,segments=24)
part('Central medallion inset',0,50.0,.7,.7,-.15,.3,stone)
# Tall second-floor bank glazing; dark surround with three separately inset groups.
for x in [-6,-2.2,2.2,6]:part('Bank dark pier',x,6.55,.42,5.2,0,.75,base)
part('Bank roof fascia',0,9.2,W,1.4,-.10,.85,base)
part('Bank lower decorative band',0,4.1,W,.6,-.10,.9,base)
for x,w in [(-4.1,3.35),(0,3.8),(4.1,3.35)]:
 sash(x,6.6,w,4.25)
 for dx in [-w/4,0,w/4]:part('Bank physical mullion',x+dx,6.6,.08,4.25,.26,.18,metal)
 part('Bank transom',x,8.15,w,.12,.26,.18,metal)
for x in [i*.38-6 for i in range(33)]:
 arch('Small bank frieze ring',.10,.16,(x,4.05),F-.55,.15,metal,end=2*math.pi,segments=12)
part("Solid dark retail head",0,3.75,W,1.25,0,.65,base)
# Ground retail openings and actual recessed central doors.
for x in [-6,-1.2,1.2,6]:part('Ground dark stone pier',x,1.9,.5,3.8,0,.8,base)
for x in [-3.7,3.7]:
 sash(x,1.8,4.1,3.1)
 for dx in [-1.36,0,1.36]:part('Retail metal divider',x+dx,1.8,.06,3.1,.26,.14,metal)
for x in [-.53,.53]:
 part('Deep inset entrance door',x,1.6,.95,3.1,1.1,.04,glass)
 for dx in [-.48,.48]:part('Entrance door stile',x+dx,1.6,.065,3.2,.94,.13,metal)
 part('Door handle',x+.32,1.4,.045,.5,.78,.09,metal)
part('Entrance head',0,3.6,2.5,.4,-.1,.85,base)
part('Entrance back',0,1.8,2.3,3.6,1.8,.1,back)
part('Ground threshold',0,.15,W,.3,0,.8,base)
text('Street number','180',(0,F-.55,3.7),.30,trim)
finish('equitable',OUT)
