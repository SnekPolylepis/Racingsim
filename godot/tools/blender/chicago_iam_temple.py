"""I AM Temple: physical south frontage from owner/photographer references."""
import bpy,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,text,line,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
brick=material('Red brick facade',(.36,.12,.08),roughness=.95)
stone=material('Pale projecting limestone surrounds',(.65,.62,.53),roughness=.9)
white=material('White temple entrance stone',(.82,.80,.74),roughness=.9)
glass=material('Separate recessed window panes',(.11,.16,.17),roughness=.6)
metal=material('Physical brass sash and balcony rails',(.34,.29,.18),metallic=.3)
back=material('Opaque recessed interior',(.045,.04,.035),roughness=.95)
rear=material('Plain party and rear masonry',(.30,.23,.18),roughness=.95)
W,D,H=12.8,32.8,56 # Height is a photo-proportion estimate; mapped66m unverified.
box('Foundation',(0,0,-4),(W,D,8),brick)
box('Interior backing',(0,.65,H/2),(W-.8,D-1.8,H),back)
box('Rear wall',(0,D/2-.15,H/2),(W,.3,H),rear)
for x in [-W/2+.15,W/2-.15]:box('Party wall',(x,0,H/2),(.3,D,H),rear)
def part(name,x,z,w,h,depth,t,mat):return box(name,(x,-D/2+depth,z),(w,t,h),mat)
def pane(x,z,w,h):
 part('Recessed opaque glazing',x,z,w,h,.43,.04,glass)
 for dx in [-w/2,0,w/2]:part('Sash stile',x+dx,z,.04,h,.28,.1,metal)
 for dz in [-h/2,0,h/2]:part('Sash rail',x,z+dz,w,.045,.28,.1,metal)
 for dx in [-w/2-.09,w/2+.09]:part('Stone jamb',x+dx,z,.15,h+.3,-.02,.32,stone)
 for dz in [-h/2-.1,h/2+.1]:part('Stone head and sill',x,z+dz,w+.3,.16,-.06,.4,stone)
centres=[-4.8,-2.4,0,2.4,4.8]
for edge in range(6):part('Solid brick pier',-6+edge*2.4,30,.68,52,0,.6,brick)
for row in range(8):
 z=26.5+row*3.75
 part('Solid upper spandrel',0,z-1.65,W,1.1,0,.6,brick)
 for x in centres:pane(x,z,1.6,2.55)
# Lower tall grouped sashes and projecting decorative balcony bases.
for x in centres:
 pane(x,8.05,1.6,2.65)
 pane(x,15.7,1.65,8.15)
 for z in [11.0,21.1]:
  pts=[(x+.96*math.cos(a),-D/2-.28-.63*math.sin(a),z) for a in [i*math.pi/12 for i in range(13)]]
  line('Curved projecting balcony rim',pts,.10,stone)
  for i in range(13):
   a=i*math.pi/12
   xx=x+.92*math.cos(a); yy=-D/2-.28-.6*math.sin(a)
   line('Separate balcony baluster',[(xx,yy,z+.13),(xx,yy,z+1.05)],.023,metal)
  line('Curved balcony handrail',[(xx,yy,zz+1.05) for xx,yy,zz in pts],.032,metal)
  part('Balcony supporting corbel',x,z-.38,.7,.65,-.25,.9,stone)
 part('Tall bay decorative sill',x,20.2,1.95,.25,-.1,.65,stone)
for z,h in [(6.2,1.0),(10.1,1.0),(22.85,2.55),(54.2,1.2)]:part("Solid lower brick spandrel",0,z,W,h,0,.6,brick)
for z,h in [(4.6,1.8),(.4,.8)]:part("Solid white base spandrel",0,z,W,h,0,.7,white)
for z in [5.6,9.8,24.6,55.5]:part('Continuous stone band',0,z,W+.15,.26,-.1,.8,stone)
part('Roof parapet',0,55.1,W,1.8,0,.6,brick)
box('Roof',(0,0,55.8),(W,D,.3),rear)
# White base with physically inset doors/storefront panes.
for x in [-6.15,-2.1,2.1,6.15]:part('White ground pier',x,2.75,.5,5.5,0,.7,white)
for z in [.2,4.55,5.2]:part('White base band',0,z,W,.4,0,.75,white)
for x in [-4.1,4.1]:
 pane(x,2.65,3.35,3.35)
 for dx in [-1.1,-.55,.55,1.1]:part('Storefront grid stile',x+dx,2.65,.045,3.35,.28,.1,metal)
part('Deep entrance backing',0,2,3.45,4,1.8,.12,back)
for x in [-1.05,0,1.05]:
 part('Inset door pane',x,1.75,.85,3.1,1.1,.04,glass)
 for dx in [-.46,.46]:part('Door stile',x+dx,1.75,.08,3.2,.98,.14,white)
 part('Brass door rail',x,1.6,.9,.07,.90,.13,metal)
for z,w in [(3.5,3.4),(3.75,3.65),(4.0,3.9)]:part('Stepped projecting entrance lintel',0,z,w,.2,-.25,.95,white)
part('Temple sign tablet',0,4.7,3.2,1.0,-.15,.55,white)
text('Temple lettering','I AM TEMPLE',(0,-D/2-.46,4.7),.30,metal)
finish('iam_temple',OUT)
