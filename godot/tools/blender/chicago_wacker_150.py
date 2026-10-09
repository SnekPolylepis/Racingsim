"""150 South Wacker exterior study; mapped plan, Blender +Y north / +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
metal=material('Wacker150 dark bronze grey structural grid',(.19,.20,.19),metallic=.35,roughness=.75)
frame=material('Wacker150 fine black glazing frames',(.06,.08,.09),metallic=.2,roughness=.7)
glass=material('Wacker150 blue grey recessed paired panes',(.12,.19,.22),roughness=.42)
night=material('Night Wacker150 occupied paired panes',(.12,.19,.22),roughness=.42,glow=.2)
roof=material('Wacker150 opaque interior and flat roof',(.08,.09,.09),roughness=.95)
sill=material('Wacker150 metal sill and coping',(.28,.29,.27),metallic=.4,roughness=.7)
cx,cz=-1083.35,572.65
building=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w147350199')
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
H=126.5;base=7.5
# ponytail: one ground interval plus 32 upper rows is a CVU/photo-fit working interpretation,
# not an as-built floor/entrance/roof survey. Ground/base proportions and historic height discrepancies remain open.
prism('Wacker150 buried exact six vertex foundation',plan,-8,0,metal)
prism('Wacker150 recessed opaque core',[(x*.92,y*.92) for x,y in plan],0,H-.4,roof)
prism('Wacker150 exact mapped flat roof slab',plan,H-.4,H,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b)
 count=max(1,round(width/3.4));pitch=width/count
 for row in range(33):
  lo=0 if row==0 else base+(row-1)*(H-base)/32
  hi=base if row==0 else lo+(H-base)/32
  pane_h=hi-lo-1.02;mid=lo+.10+pane_h/2
  facade('Continuous bronze floor spandrel',(width/2,-.04,hi-.44),(width,.34,.88),metal,a,b)
  for j in range(count):
   u=(j+.5)*pitch
   for side in (-1,1):
    facade('Separate recessed paired glazing',(u+side*(pitch-.30)/4,-.29,mid),((pitch-.30)/2-.04,.055,pane_h),night if (row*17+j*11)%71==3 else glass,a,b)
   facade('Fine paired pane divider',(u,-.19,mid),(.045,.20,pane_h),frame,a,b)
   for z in (lo+.075,hi-.96):facade('Continuous paired glazing sill',(u,-.14,z),(pitch-.24,.24,.08),sill,a,b)
 for j in range(count+1):
  facade('Full height projecting structural mullion',(j*pitch,-.08,H/2),(.24,.34,H),metal,a,b)
 # Owner river-side photograph shows larger dark piers at the glazed ground interval.
 # Their width/alternating bay rhythm and transom height are photo-fit, not a base survey.
 for j in range(0,count+1,2):
  facade('Broad ground floor dark structural pier',(j*pitch,-.04,base/2),(.95,.65,base),metal,a,b)
 facade('Ground glazing transom',(width/2,-.12,2.8),(width,.25,.12),frame,a,b)
 facade('Flat parapet coping',(width/2,-.02,H-.075),(width,.44,.15),sill,a,b)
for o in bpy.context.scene.objects:
 if o.type=='MESH':assert all(math.isfinite(v) for vertex in o.data.vertices for v in vertex.co),o.name
finish('wacker_150',OUT)
