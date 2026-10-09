"""311 West Monroe authored exterior study; Blender +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
granite=material('Monroe311 grey brown granite piers',(.32,.30,.27),roughness=.86)
inset=material('Monroe311 recessed granite spandrels',(.27,.255,.23),roughness=.88)
glass=material('Monroe311 recessed tinted glass',(.13,.18,.17),roughness=.48)
night=material('Night Monroe311 occupied windows',(.13,.18,.17),roughness=.48,glow=.2)
frame=material('Monroe311 dark sash frames',(.065,.075,.07),metallic=.25,roughness=.65)
silver=material('Monroe311 renovated top floor metal frames',(.44,.47,.46),metallic=.35,roughness=.65)
roof=material('Monroe311 opaque core and light roof membrane',(.58,.58,.54),roughness=.96)
cx,cz=-938.85,499.1
building=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w147350188')
plan=[(x-cx,-(z-cz)) for x,z in building['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
def prism(name,points,bottom,top,mat):
 n=len(points)
 return mesh(name,[(x,y,z) for z in (bottom,top) for x,y in points],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def facade(name,pos,size,mat,a,b):
 obj=box(name,pos,size,mat)
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 for v in obj.data.vertices:
  x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
 for polygon in obj.data.polygons:polygon.flip()
 return obj
H=62.5;base=6;top_floor=51.6;top_band=56.9
# ponytail: CVU height/floors and architect photos fix the broad form; intervals, bays and entrance are photo-fit.
prism('Monroe311 buried exact eight vertex foundation',plan,-8,0,granite)
prism('Monroe311 recessed opaque core',[(x*.94,y*.94) for x,y in plan],0,H-.4,inset)
prism('Monroe311 flat high albedo roof membrane',plan,H-.4,H,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b);count=max(1,round(width/2.4));pitch=width/count
 north=a[1]>25 and b[1]>25
 for row in range(14):
  lo=0 if row==0 else base+(row-1)*(top_floor-base)/13
  hi=base if row==0 else base+row*(top_floor-base)/13
  pane_h=hi-lo-1.05;mid=lo+.1+pane_h/2
  recess=-1.10 if row==0 else -.62
  facade('Recessed granite floor spandrel',(width/2,-.28,hi-.45),(width,.44,.90),inset,a,b)
  for j in range(count):
   u=(j+.5)*pitch;pane_w=max(.25,pitch-.65)
   facade('Separate recessed tinted sash',(u,recess,mid),(pane_w,.07,pane_h),night if (row*17+j*11)%53==7 else glass,a,b)
   for dx in (-pane_w/2,pane_w/2):facade('Physical sash upright',(u+dx,recess+.11,mid),(.06,.16,pane_h),frame,a,b)
   facade('Lower window meeting rail',(u,recess+.12,lo+.1+pane_h*.25),(pane_w,.18,.07),frame,a,b)
 for j in range(count+1):
  u=j*pitch;bottom=base if j%4 and j!=count else 0
  facade('Continuous projecting narrow granite pier',(u,.01,(bottom+top_floor)/2),(.45,.90,top_floor-bottom),granite,a,b)
  if j%4==0 or j==count:facade('Broad ground arcade pier',(u,-.40,base/2),(.85,1.80,base),granite,a,b)
 facade('Ground arcade lintel',(width/2,.01,base),(width,.95,.50),granite,a,b)
 groups=max(1,round(width/8));group_pitch=width/groups
 for j in range(groups):
  u=(j+.5)*group_pitch;glazed_w=group_pitch-.25
  facade('Renovated large format top floor glass',(u,-.39,(top_floor+top_band)/2),(glazed_w,.08,top_band-top_floor-.25),glass,a,b)
  for dx in (-group_pitch/2,group_pitch/2):facade('Renovated top floor structural frame',(u+dx,.08,(top_floor+top_band)/2),(.24,.70,top_band-top_floor),silver,a,b)
  for dx in (-glazed_w/3,0,glazed_w/3):facade('Top floor operable window mullion',(u+dx,-.20,(top_floor+top_band)/2),(.06,.24,top_band-top_floor-.25),frame,a,b)
  for z in (top_floor+.11,top_floor+1.6,top_band-.11):facade('Top floor horizontal glazing rail',(u,-.20,z),(glazed_w,.25,.08),silver,a,b)
 facade('Renovated top floor lower metal sill',(width/2,.05,top_floor),(width,.72,.22),silver,a,b)
 facade('Blank upper granite roof band',(width/2,-.03,(top_band+H)/2),(width,.72,H-top_band),granite,a,b)
 for j in range(count+1):facade('Upper granite band panel joint',(j*pitch,.38,(top_band+H)/2),(.08,.12,H-top_band),inset,a,b)
 if north:
  facade('Provisional north entrance canopy',(width/2,.55,4.8),(9,2.2,.22),silver,a,b)
  for dx in (-1.7,0,1.7):facade('Recessed north entrance door stile',(width/2+dx,-.98,1.5),(.075,.20,3),frame,a,b)
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':assert all(math.isfinite(v) for vertex in obj.data.vertices for v in vertex.co),obj.name
finish('monroe_311',OUT)
