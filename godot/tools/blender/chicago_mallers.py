"""Mallers draft: original geometry from historical perspective and sign photograph."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, text, line, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('White enamel terra cotta',(.65,.64,.57),roughness=.82)
trim=material('Projecting pale mouldings',(.76,.74,.65),roughness=.78)
glass=material('Separate recessed opaque windows',(.13,.20,.21),roughness=.55)
sash=material('Dark window sash',(.10,.12,.11),roughness=.7)
back=material('Opaque interior and unsurveyed rear',(.26,.25,.22),roughness=1)
red=material('Red sign cabinet',(.23,.025,.02),roughness=.7)
neon=material('Red neon outline',(.95,.06,.025),glow=2)
gold=material('Raised sign letters',(.92,.61,.12),glow=.35)
blue=material('Blue diamond cap',(.06,.35,.55),glow=.35)
H=87
# Exact mapped ring translated to local origin(-106.6,327); Blender Y points north.
ring=[(x+106.6,327-z) for x,z in [(-132,342.3),(-104.7,341.5),(-99.6,337.2),(-80.5,336.7),(-81.1,312),(-132.7,313.3),(-132.1,338.5)]]
def prism(name,z,h,mat,scale=1):
 r=[(x*scale,y*scale) for x,y in ring];n=len(r)
 return mesh(name,[(x,y,z-h/2) for x,y in r]+[(x,y,z+h/2) for x,y in r],[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
prism('Mapped foundation',-4,8,back)
prism('Inset interior preserving south notch',43,86,back,.91)
prism('Roof slab',86.7,.6,back)
for edge in range(len(ring)):
 a,b=ring[edge],ring[(edge+1)%len(ring)]
 length=math.dist(a,b);origin=((a[0]+b[0])/2,(a[1]+b[1])/2,0)
 angle=math.atan2(b[1]-a[1],b[0]-a[0])
 def placed(obj):
  obj.location=Vector(origin)+Matrix.Rotation(angle,3,'Z')@obj.location
  obj.rotation_euler.z+=angle
  return obj
 def part(name,x,z,w,h,d,t,mat):return placed(box(name,(x,d,z),(w,t,h),mat))
 public=origin[0]<-24 or origin[1]>12
 if not public:
  part('Unsurveyed rear wall',0,43,length,86,0,.35,back)
  continue
 # ponytail: bay counts are historical-image estimates; refine against a modern full-height photo.
 cols=max(1,round(length/2.65));pitch=length/cols
 for row in range(20):
  low=4+row*4.05;wh=2.65 if row>2 else 2.8
  part('Solid spandrel',0,low+3.42,length,1.25,0,.42,stone)
  for c in range(cols):
   x=(c-(cols-1)/2)*pitch
   part('Recessed separate pane',x,low+1.7,pitch-.65,wh,.47,.04,glass)
   part('Sill projecting beyond pane',x,low+.3,pitch-.35,.16,-.12,.65,trim)
   part('Sash centre rail',x,low+1.7,pitch-.65,.065,.35,.12,sash)
  for c in range(cols+1):
   part('Continuous facade pier',-length/2+c*pitch,low+2.025,.58,4.05,0,.52,stone)
 for z,w,h in [(4,.75,.35),(16.1,.8,.5),(76.9,.85,.55),(84.8,1.1,.45),(86.25,1.5,.5),(86.8,1.7,.4)]:
  part('Projecting facade belt and cornice',0,z,length+w,h,-.15,w,trim)
 for c in range(cols):
  x=(c-(cols-1)/2)*pitch
  part('Cornice bracket',x,85.6,.25,1.15,-.28,1.2,trim)
  part('Inset ground retail glazing',x,1.9,pitch-.5,3.5,.8,.05,glass)
  part('Ground door stile',x,1.9,.08,3.5,.65,.15,sash)
 for c in range(cols+1):part('Ground masonry pier',-length/2+c*pitch,2,.45,4,0,.7,stone)
 # Wabash public west wall only; source photo fixes sign side, dimensions estimated.
 if origin[0]<-24 and length>10:
  part('Projecting sign cabinet',0,12,1.65,11,-1.5,.30,red)
  for x in [-.77,.77]:placed(line('Neon outline',[(x,-1.69,6.6),(x,-1.69,17.4)],.045,neon))
  for z in [6.6,17.4]:placed(line('Neon outline',[(-.77,-1.69,z),(.77,-1.69,z)],.045,neon))
  for i,ch in enumerate('JEWELERSCENTER'):
   placed(text('Physical sign letter',ch,(0,-1.73,17-i*.75),.70,gold))
  for z in [8,15]:part('Sign mounting bracket',0,z,.16,.2,-.70,1.6,sash)
  diamond=[(-.80,18.6),(-.43,19.15),(.43,19.15),(.80,18.6),(0,17.75)]
  verts=[(x,y,z) for y in [-1.65,-1.35] for x,z in diamond]
  placed(mesh('Physical pentagonal diamond cap',verts,[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],blue))
  for a,b in [(0,1),(1,2),(2,3),(3,4),(4,0),(0,3),(1,4),(2,4)]:
   placed(line('Diamond facet outline',[(diamond[a][0],-1.68,diamond[a][1]),(diamond[b][0],-1.68,diamond[b][1])],.025,trim))
finish('mallers',OUT)
