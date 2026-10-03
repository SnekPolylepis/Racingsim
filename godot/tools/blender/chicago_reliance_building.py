"""Original modeled Reliance Building exterior. +Y north, +Z up in Blender.
HABS dimensions/window sections and CAC current exterior; see SOURCES.md.
"""
import bpy,math,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box as baked_box,mesh,arch,text,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
cream=material('Glazed cream terra cotta',(.64,.60,.49),roughness=.38)
trim=material('Raised Gothic terra cotta',(.75,.70,.57),roughness=.43)
granite=material('Polished Scotch granite podium',(.14,.11,.095),metallic=.12,roughness=.24)
bronze=material('Bronze Chicago window sash',(.23,.20,.14),metallic=.5,roughness=.36)
glass=material('Unoccupied Chicago window glass',(.14,.20,.21),metallic=.3,roughness=.22)
lit=material('Night occupied Chicago window glass',(.14,.20,.21),metallic=.3,roughness=.22,glow=.3)
brick=material('Rear glazed brick party walls',(.37,.36,.31),roughness=.75)
roof=material('Flat roof membrane',(.12,.13,.12),roughness=.85)
W,D=25.8572,17.018
TOP=60.96


def box(name,pos,size,mat):
 obj=baked_box(name,(0,0,0),size,mat)
 obj.location=pos
 return obj


def orient(objects,angle,offset):
 c,s=math.cos(angle),math.sin(angle)
 for obj in objects:
  x,y,z=obj.location
  obj.location=(offset[0]+x*c-y*s,offset[1]+x*s+y*c,z)
  obj.rotation_euler.z+=angle


def quatrefoil(x,y,z):
 for dx,dz in [(0,.15),(.15,0),(0,-.15),(-.15,0)]:
  obj=arch('Molded quatrefoil',.12,.17,(0,0),0,.065,trim,start=0,end=math.tau,segments=12)
  obj.location=(x+dx,y,z+dz)


def span(a,b,bottom,top,rows,kind):
 before=set(bpy.context.scene.objects)
 dx,dy=b[0]-a[0],b[1]-a[1]
 width=math.hypot(dx,dy)
 step=(top-bottom)/rows
 for row in range(rows):
  z=bottom+(row+.5)*step
  height=step-.65
  occupied=(row*5+round(a[0]*3+a[1]*7))%11<4
  pane=lit if occupied else glass
  if kind=='flat':
   # Chicago window: broad fixed centre, narrow operable sash at both sides.
   sizes=[width*.18,width*.56,width*.18]
   centers=[-width*.37,0,width*.37]
  else:
   sizes=[width-.22];centers=[0]
  for center,size in zip(centers,sizes):
   box('Inset plate glass',(center,.015,z+.15),(size,.075,height),pane)
   for side in [-1,1]:
    box('Slender window jamb',(center+side*size/2,.08,z+.15),(.065,.14,height),bronze)
   for off in [-height/2,height/2]:
    box('Window head and lower sash',(center,.08,z+.15+off),(size,.14,.07),bronze)
   box('Upper transom',(center,.08,z+height*.30),(size,.14,.07),bronze)
   if kind!='fixed':box('Operable sash meeting rail',(center,.08,z+.10),(size,.14,.055),bronze)
  for side in [-1,1]:
   x=side*width/2
   box('Terra cotta colonette',(x,.13,z),(.16,.28,step),cream)
   box('Clustered colonette rib',(x,.29,z),(.07,.08,step-.15),trim)
  box('Panelled terra cotta spandrel',(0,.09,z-step/2+.22),(width,.24,.44),cream)
  box('Raised bay sill',(0,.20,z-step/2+.48),(width+.09,.46,.14),trim)
  if width>2:
   for x in [-width*.28,0,width*.28]:quatrefoil(x,.225,z-step/2+.22)
  else:quatrefoil(0,.225,z-step/2+.22)
 # Projecting roof cornice follows each facet of the real bay profile.
 for z,depth,height in [(58.7,.65,.30),(59.1,1.0,.45),(59.65,1.25,.38),(60.4,1.4,.45)]:
  box('Reconstructed projecting cornice',(0,.15+(z-58.7)*.2-depth/2,z),(width+.16,depth,height),trim)
 for i in range(max(1,round(width/.75))):
  x=-width/2+(i+.5)*width/max(1,round(width/.75))
  box('Cornice bracket',(x,.1,59.5),(.16,.6,.75),cream)
 orient(set(bpy.context.scene.objects)-before,math.atan2(dy,dx),((a[0]+b[0])/2,(a[1]+b[1])/2))


# Upper mass with the documented southwest light well; masonry party walls.
notch_x,notch_y=5.0292,7.7216
box('North main upper mass',(0,notch_y/2,31.6),(W,D-notch_y,53.8),brick)
box('Southeast upper mass',(notch_x/2,-(D-notch_y)/2,31.6),(W-notch_x,notch_y,53.8),brick)
box('Street podium',(0,0,2.35),(W,D,4.7),granite)
box('North roof terrace',(0,notch_y/2,58.52),(W,D-notch_y,.12),roof)
box('Southeast roof terrace',(notch_x/2,-(D-notch_y)/2,58.52),(W-notch_x,notch_y,.12),roof)
# North Washington elevation: two projecting bays; east State: one.
for width,face,centers,bay_width,angle in [(W,D/2,[-6.35,6.35],7.1628,0),(D,W/2,[0],7.9248,-math.pi/2)]:
 profile=[(-width/2,face)]
 kinds=[]
 for center in centers:
  lo,hi=center-bay_width/2,center+bay_width/2
  profile.extend([(lo,face),(lo+1,face+.9144),(hi-1,face+.9144),(hi,face)])
  kinds.extend(['flat','sash','fixed','sash'])
 profile.append((width/2,face));kinds.append('flat')
 before=set(bpy.context.scene.objects)
 for i in range(len(profile)-1):
  span(profile[i],profile[i+1],4.8,58.5,14,kinds[i])
 # Podium glazing and bronze framing, kept separate from the upper projecting bays.
 for i in range(round(width/3.6)):
  count=round(width/3.6);x=-width/2+(i+.5)*width/count;pane=width/count-.4
  box('Street shop glazing',(x,face+.025,2.7),(pane,.10,3.65),glass)
  for side in [-1,1]:box('Granite storefront pier',(x+side*pane/2,face+.18,2.35),(.24,.4,4.7),granite)
  box('Bronze shop transom',(x,face+.15,3.8),(pane,.16,.08),bronze)
 box('Podium bronze cornice',(0,face+.25,4.65),(width+.2,.6,.30),bronze)
 text('Historic Reliance name','RELIANCE BUILDING',(0,face+.40,4.2),.55,bronze,rotate=(math.pi/2,0,math.pi))
 orient(set(bpy.context.scene.objects)-before,angle,(0,0))
# Back/party-wall windows and exposed light-well glazing, dimensional but restrained.
for y in [-D/2,-D/2+notch_y]:
 for row in range(13):
  z=7+(row+.5)*3.9
  for x in [-6,-1,4,9]:
   if y>-D/2 and x>-W/2+notch_x:continue
   box('Rear light-well window',(x,y-.04,z),(1.8,.10,2.4),glass)
# The roof parapet fixes the documented total architectural height.
for y in [-D/2,D/2]:box('Upper parapet',(0,y,60.73),(W,.25,.46),cream)
for x in [-W/2,W/2]:box('Upper side parapet',(x,0,60.73),(.25,D,.46),cream)
bpy.context.view_layer.update()
from mathutils import Vector
points=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects for v in o.bound_box]
assert min(v.z for v in points)>-.01
assert abs(max(v.z for v in points)-TOP)<.01
assert max(abs(v.x) for v in points)<15
assert max(abs(v.y) for v in points)<10.5
finish('reliance_building',OUT)
