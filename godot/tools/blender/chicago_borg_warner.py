"""Borg-Warner/200 South Michigan: authored curtain-wall exterior from owner photos."""
import bpy,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,text,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
glass=material('Separate pale blue opaque panes',(.27,.43,.49),roughness=.48)
blue=material('Blue porcelain enamel spandrels',(.065,.15,.28),roughness=.55)
metal=material('Projecting pale aluminum mullions',(.66,.69,.68),metallic=.55,roughness=.48)
black=material('Black polished ground piers',(.035,.045,.045),roughness=.5)
back=material('Opaque recessed interior',(.035,.045,.05),roughness=1)
roof=material('Roof and unsurveyed rear masonry',(.34,.35,.33),roughness=.95)
W,D,H=51.7,31.5,83.5
box('Foundation',(0,0,-4),(W,D,8),roof)
box('Inset opaque interior',(0,0,41),(W-4.0,D-4.0,82),back)
box('Roof slab',(0,0,83.2),(W,D,.6),roof)
# Photo shows repeated narrow modules; exact bay widths are footprint-fit estimates.
for side,length,origin,angle,cols in [('north',W,(0,D/2,0),math.pi,40),('east',D,(W/2,0,0),math.pi/2,24)]:
 def placed(obj):obj.rotation_euler.z=angle;obj.location=origin;return obj
 def part(name,x,z,w,h,depth,t,mat):return placed(box(name,(x,depth,z),(w,t,h),mat))
 pitch=length/cols
 for col in range(cols+1):part('Continuous projecting aluminum mullion',-length/2+col*pitch,45,.065,76,-.05,.28,metal)
 step=76/20
 for row in range(20):
  bottom=7+row*step
  part('Solid blue spandrel',0,bottom+.55,length,1.10,.08,.15,blue)
  for z in [bottom,bottom+1.10,bottom+step]:part('Horizontal aluminum rail',0,z,length,.065,-.04,.22,metal)
  for col in range(cols):
   x=(col-(cols-1)/2)*pitch
   part('Physically recessed glazing',x,bottom+2.45,pitch-.08,2.62,.28,.035,glass)
   part('Narrow operable transom rail',x,bottom+step-.40,pitch-.06,.045,.12,.12,metal)
 for col in range(0,cols+1,4):
  x=-length/2+col*pitch
  if side!='east' or abs(x)>3.3:part('Black structural base pier',x,3.5,.48,7,-.03,.75,black)
 for z in [.25,3.15,6.85]:part('Ground aluminum fascia',0,z,length,.20,-.08,.6,metal)
 for col in range(cols):
  x=(col-(cols-1)/2)*pitch
  inset=1.15 if side=='east' and abs(x)<3.3 else .38
  for z,h in [(1.7,2.75),(4.95,3.15)]:part('Ground storefront and lobby pane',x,z,pitch-.10,h,inset,.04,glass)
  part('Ground glazing stile',x+pitch/2,3.5,.07,6.7,inset-.12,.15,metal)
 if side=='east':
  part('Main entry canopy fascia',0,3.25,10,.32,-.38,1.35,metal)
  part('Deep entry soffit',0,3.35,8,.10,.5,2.0,black)
  for x in [-2.55,-.85,.85,2.55]:
   part('Inset entrance door rail',x,1.45,1.65,.07,1.0,.14,metal)
   part('Door handle',x+.45,1.65,.055,.5,.94,.10,metal)
  # Text is actual raised geometry; preserve its local transform before placing the face.
  label=text('Raised entrance address','200 SOUTH MICHIGAN',(0,-.78,3.3),.38,metal)
  label.location=(W/2+1.10,0,3.3);label.rotation_euler.z=math.pi/2
for x in [-W/2+.15]:box('Unsurveyed rear wall',(x,0,41.5),(.3,D,83),roof)
box('Unsurveyed south wall',(0,-D/2+.15,41.5),(W,.3,83),roof)
# ponytail: measured curtain-wall profiles/roof equipment unavailable; replace estimated modules when surveyed.
finish('borg_warner',OUT)
