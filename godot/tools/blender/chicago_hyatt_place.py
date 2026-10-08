"""Hyatt Place Loop draft: physical curtain wall and punched-window wings."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, text, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
glass = material('Separate blue opaque glazing', (.055,.25,.34), roughness=.42)
spandrel = material('Blue curtain wall spandrels', (.035,.15,.22), roughness=.5)
metal = material('Slender projecting aluminum frames', (.43,.49,.49), metallic=.5, roughness=.48)
stone = material('Pale punched-window wings', (.64,.64,.58), roughness=.85)
dark = material('Dark recessed interior and window frames', (.025,.045,.055), roughness=.85)
white = material('Raised pale hotel lettering', (.82,.83,.76), roughness=.7)
H = 64.4
ring = [(x+932,230.4-z) for x,z in [(-919.4,216.8),(-918.9,243.7),(-946.3,244.1),(-946.5,233.1),(-944.7,233.1),(-945,217.2)]]
# Reverse to CCW so local positive depth points into each mapped facade.
if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1])) < 0:
 ring.reverse()
def prism(name,z,h,mat,scale=1):
 r=[(x*scale,y*scale) for x,y in ring]; n=len(r)
 return mesh(name,[(x,y,z-h/2) for x,y in r]+[(x,y,z+h/2) for x,y in r],
  [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
prism('Mapped foundation',-4,8,dark)
prism('Inset opaque wing interior',28.5,57,dark,.88)
prism('Lower wing roof slab',57.4,.6,stone)
box('Inset higher glass tower interior',(8,3,60),(9.3,19,8),dark)
box('Higher glass tower roof',(8,3,64.1),(10,20,.6),spandrel)
for a,b in zip(ring,ring[1:]+ring[:1]):
 length=math.dist(a,b); origin=((a[0]+b[0])/2,(a[1]+b[1])/2,0)
 angle=math.atan2(b[1]-a[1],b[0]-a[0])
 def placed(obj):
  obj.location=Vector(origin)+Matrix.Rotation(angle,3,'Z')@obj.location
  obj.rotation_euler.z+=angle
  return obj
 def part(name,x,z,w,h,d,t,mat):return placed(box(name,(x,d,z),(w,t,h),mat))
 east=origin[0]>12
 north=origin[1]>12
 if not east and not north:
  part('Unsurveyed party wall',0,28.85,length,57.7,0,.35,stone)
  continue
 # ponytail: profile, bay widths and wing setbacks are photo-fit estimates, not surveyed dimensions.
 wing=7.0 if east else 17.0
 tower=length-wing
 # Photo has the pale strip at the south end of Franklin and glass wrapping the north corner.
 wing_center=-length/2+wing/2 if east else length/2-wing/2
 tower_center=wing/2 if east else -wing/2
 wing_top=58.0
 for row in range(16):
  low=5.2+row*3.25
  part('Wing solid spandrel',wing_center,low+.65,wing,1.3,0,.40,stone)
  cols=2 if east else 5; pitch=wing/cols; ww=pitch*.65
  for c in range(cols):
   x=wing_center+(c-(cols-1)/2)*pitch
   part('Wing separate inset window',x,low+2.25,ww,1.85,.43,.035,glass)
   for dx in [-ww/2,0,ww/2]:part('Wing window stile',x+dx,low+2.25,.055,1.85,.30,.12,dark)
  for c in range(cols+1):
   part('Wing aperture pier',wing_center-wing/2+c*pitch,low+2.25,pitch-ww,1.9,0,.40,stone)
 part('Wing parapet',wing_center,57.4,wing,1.2,0,.4,stone)
 # Two tall ground levels followed by fine curtain-wall modules up to the higher glass crown.
 cols=max(3,round(tower/1.25)); pitch=tower/cols
 for c in range(cols+1):
  part('Continuous curtain wall mullion',tower_center-tower/2+c*pitch,H/2,.065,H,-.035,.23,metal)
 for row in range(18):
  low=row*H/18; step=H/18
  part('Blue opaque spandrel',tower_center,low+.45,tower,.9,.10,.12,spandrel)
  for z in [low,low+.9]:part('Curtain wall horizontal rail',tower_center,z,tower,.065,-.025,.2,metal)
  for c in range(cols):
   x=tower_center+(c-(cols-1)/2)*pitch
   part('Individual recessed curtain pane',x,low+.9+(step-.9)/2,pitch-.075,step-.96,.24,.035,glass)
 part('Ground wing lobby glazing',wing_center,2.6,wing-.2,5.0,.50,.04,glass)
 for x in [-wing/2,0,wing/2]:part('Ground wing pier',wing_center+x,2.6,.20,5.2,0,.45,stone)
 if east:
  # Raised lettering is visible in the architect photo; current entrance detail remains unverified.
  placed(text('Raised hotel name','HYATT\nPLACE',(tower_center+tower*.16,-.22,61.7),1.1,white))
finish('hyatt_place',OUT)
