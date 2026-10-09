"""Millennium Park Plaza exterior study; Blender +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box, mesh as make_mesh, line, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Millennium pale concrete piers', (.62,.59,.51), roughness=.86)
office = material('Millennium brown ribbed office panels', (.28,.23,.18), roughness=.86)
spandrel = material('Millennium fluted residential spandrels', (.43,.42,.36), roughness=.82)
glass = material('Millennium recessed residential glass', (.13,.18,.19), roughness=.48)
night = material('Night Millennium occupied panes', (.13,.18,.19), roughness=.48, glow=.2)
frame = material('Millennium dark sash and deck railing', (.08,.085,.08), metallic=.2)
roof = material('Millennium light roof membrane', (.64,.64,.59), roughness=.95)
deck = material('Millennium brown terrace pavers', (.35,.29,.23), roughness=.96)
cx,cz = 21.1,-49.4
building = next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w127107026')
plan = [(x-cx,-(z-cz)) for x,z in building['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0: plan.reverse()

# Build repeated facade panels directly into material meshes instead of thousands of Blender objects.
panels = {}
def mesh(name, vertices, faces, mat):
 verts,polys = panels.setdefault(mat, ([],[]))
 offset=len(verts)
 verts.extend(vertices)
 polys.extend(tuple(offset+i for i in face) for face in faces)

def prism(name, points, bottom, top, mat):
 n=len(points)
 return mesh(name, [(x,y,z) for z in (bottom,top) for x,y in points], [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)], mat)

def facade(name, pos, size, mat, a, b):
 tx,ty=b[0]-a[0],b[1]-a[1];d=math.hypot(tx,ty);tx/=d;ty/=d
 vertices=[]
 for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
  x,y,z=(pos[i]+v*size[i]/2 for i,v in enumerate((dx,dy,dz)))
  vertices.append((a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z))
 faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
 mesh(name,vertices,[tuple(reversed(face)) for face in faces],mat)

# ponytail: published tip is fixed; office/residential split, bays and roof levels are photo-fit pending measured plans.
H=121.9; arcade=5; base=30; roof_level=118.8
prism('Exact mapped buried foundation',plan,-8,0,stone)
prism('Inset opaque wall core',[(x*.84,y*.97) for x,y in plan],0,roof_level-.3,office)
prism('Flat pale roof',plan,roof_level-.3,roof_level,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
 width=math.dist(a,b)
 if width<3:
  facade('Chamfered opaque end pier',(width/2,-.2,roof_level/2),(width,.65,roof_level),stone,a,b)
  continue
 long=width>40
 count=36 if long else 4
 margin=.8 if long else width*.22
 pitch=(width-2*margin)/count
 pane_w=pitch*.83 if long else pitch*.66
 facade('Continuous backing behind deeply recessed panes',(width/2,-1.05,roof_level/2),(width,.2,roof_level),office,a,b)
 # Separate office base: densely spaced ribs on the long face, broader glass at the short end.
 office_count=max(1,round(width/.60)) if long else 6
 for j in range(office_count+1):
  facade('Office base projecting metal fin',(j*width/office_count,-.10,(arcade+base)/2),(.10,.65,base-arcade),office,a,b)
 for row in range(8):
  lo=arcade+row*(base-arcade)/8;hi=arcade+(row+1)*(base-arcade)/8
  facade('Office base recessed continuous glazing',(width/2,-.60,(lo+hi)/2),(width,.08,hi-lo-.85),glass,a,b)
  facade('Office base dark horizontal spandrel',(width/2,-.22,hi-.36),(width,.45,.72),office,a,b)
 for j in range(max(2,round(width/10))+1):
  facade('Ground arcade pale structural pier',(j*width/max(2,round(width/10)),-.05,arcade/2),(.65,1.7,arcade),stone,a,b)
 facade('Recessed ground storefront glass',(width/2,-.85,arcade/2),(width,.08,arcade-.3),glass,a,b)
 facade('Pale office residential transition belt',(width/2,.02,base),(width,.8,.9),stone,a,b)
 # Thirty-one upper rows are a provisional split within the published forty-floor envelope.
 interval=(roof_level-base)/31
 for row in range(31):
  lo=base+row*interval;hi=lo+interval
  for j in range(count):
   u=margin+(j+.5)*pitch
   facade('Physical recessed residential pane',(u,-.53,lo+interval*.56),(pane_w,.08,interval*.60),night if (row*17+j*13)%61==7 else glass,a,b)
   facade('Separate fluted spandrel',(u,-.24,lo+interval*.14),(pane_w,.42,interval*.26),spandrel,a,b)
   for dx in (-pane_w*.28,0,pane_w*.28):
    facade('Raised spandrel flute',(u+dx,-.005,lo+interval*.14),(.055,.055,interval*.25),roof,a,b)
   facade('Physical window sill',(u,-.28,lo+interval*.27),(pane_w+.12,.55,.09),stone,a,b)
 for j in range(count+1):
  u=margin+j*pitch
  pier_w=(1.05 if j%4==0 else .30) if long else pitch-pane_w
  facade('Continuous pale vertical residential pier',(u,-.10,(base+roof_level)/2),(pier_w,.82,roof_level-base),stone,a,b)
 for j in range(count):
  for dx in (-pane_w/2,pane_w/2):
   facade('Continuous dark residential sash stile',(margin+(j+.5)*pitch+dx,-.38,(base+roof_level)/2),(.055,.24,roof_level-base),frame,a,b)
 # Blank end shoulders observed in the current short-end aerial view.
 for u in (margin/2,width-margin/2):
  facade('Broad pale end shoulder',(u,-.07,(base+roof_level)/2),(margin,.85,roof_level-base),stone,a,b)
 facade('Pale roof fascia',(width/2,.06,roof_level-.25),(width,1.0,.5),stone,a,b)

# South end pool dome. Radial ribs and actual glass facets replace a painted roof detail.
dome_x,dome_y,radius=0,-33,7.4
segments=64
vertices=[]
for r,z in [(radius,roof_level+.12),(.45,121.45)]:
 vertices += [(dome_x+r*math.cos(i*math.tau/segments),dome_y+r*math.sin(i*math.tau/segments),z) for i in range(segments)]
mesh('Conical pool glass roof',vertices,[(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)],glass)
for i in range(0,segments,2):
 angle=i*math.tau/segments
 line('Pale radial dome rib',[(dome_x+radius*math.cos(angle),dome_y+radius*math.sin(angle),roof_level+.19),(dome_x+.45*math.cos(angle),dome_y+.45*math.sin(angle),121.50)],.045,stone)
ring=[(dome_x+radius*math.cos(i*math.tau/segments),dome_y+radius*math.sin(i*math.tau/segments),roof_level+.17) for i in range(segments+1)]
line('Pool dome perimeter curb',ring,.12,stone)
box('Small pale dome cap',(dome_x,dome_y,121.7),(1,1,.4),stone)
box('Roof terrace brown paver surface',(0,-16,roof_level+.04),(15,17,.08),deck)
for a,b in [((-7.5,-24.5),(7.5,-24.5)),((7.5,-24.5),(7.5,-7.5)),((7.5,-7.5),(-7.5,-7.5)),((-7.5,-7.5),(-7.5,-24.5))]:
 line('Dark deck top railing',[(a[0],a[1],120.05),(b[0],b[1],120.05)],.035,frame)
 for j in range(round(math.dist(a,b)/.35)+1):
  t=j/round(math.dist(a,b)/.35)
  box('Physical deck baluster',(a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1]),119.45),(.045,.045,1.2),frame)
box('Provisional small north roof service enclosure',(0,26,120.1),(9,12,2.2),stone)

# Current broker photos show a low stepped glass addition, not the mapped118m southern block.
annex_building=next(b for b in json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())['buildings'] if b.get('o')=='w228971614')
annex=[(x-cx,-(z-cz)) for x,z in annex_building['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(annex,annex[1:]+annex[:1]))<0: annex.reverse()
prism('Exact mapped retail addition foundation',annex,-8,0,roof)
annex_cy=sum(y for x,y in annex)/len(annex)
prism('Retail opaque inset core',[(x*.84,annex_cy+(y-annex_cy)*.90) for x,y in annex],0,9.8,office)
prism('Lower retail terrace roof',annex,9.8,10,roof)
upper=[(-3,-69.1),(11.1,-69.1),(11.1,-44.2),(-3,-44.2)]
prism('Setback upper retail opaque core',[(x+(1 if x<0 else -1),y+(1 if y<-56 else -1)) for x,y in upper],10,14.1,office)
prism('Upper retail pale flat roof',upper,14.1,14.3,roof)
for perimeter,bottom,top in [(annex,0,9.8),(upper,10,14.1)]:
 for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):
  width=math.dist(a,b)
  if width<3: continue
  count=max(1,round(width/2.5));pitch=width/count
  facade('Opaque retail backing behind glazing',(width/2,-.95,(bottom+top)/2),(width,.2,top-bottom),office,a,b)
  facade('Retail glazed curtain wall',(width/2,-.55,(bottom+top)/2),(width-.6,.08,top-bottom-.35),glass,a,b)
  for j in range(count+1):
   facade('Retail curtain wall vertical frame',(j*pitch,-.30,(bottom+top)/2),(.09,.40,top-bottom),roof,a,b)
  for height in ([bottom+.15,bottom+4.5,top-.15] if bottom==0 else [bottom+.15,top-.15]):
   facade('Retail physical horizontal glazing rail',(width/2,-.30,height),(width,.40,.12),roof,a,b)
  for u in (.25,width-.25):
   facade('Broad metal clad retail corner pier',(u,.0,(bottom+top)/2),(.5,.9,top-bottom),roof,a,b)
  facade('Retail projecting pale roof fascia',(width/2,.1,top),(width,1.05,.55),roof,a,b)
box('Retail roof service screen',(3,-48,15.2),(7,7,1.8),roof)
for y in (-68,-66,-64,-62,-60,-58,-56,-54,-52,-50,-48,-46):
 box('Lower terrace physical railing baluster',(-8.8,y,10.6),(.05,.05,1.2),frame)
line('Lower terrace dark top rail',[(-8.8,-68,11.2),(-8.8,-46,11.2)],.04,frame)
for mat,(vertices,faces) in panels.items(): make_mesh(mat.name,vertices,faces,mat)
for obj in bpy.context.scene.objects:
 if obj.type=='MESH': assert all(math.isfinite(v) for vertex in obj.data.vertices for v in vertex.co),obj.name
assert max(v.co.z for obj in bpy.context.scene.objects if obj.type=='MESH' for v in obj.data.vertices)<=H+.0001
finish('millennium_plaza',OUT)
