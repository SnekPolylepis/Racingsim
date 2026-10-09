"""309 West Washington exterior study, Blender +Y north/+Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Washington309 buff masonry', (.58,.53,.43), roughness=.9)
inset = material('Washington309 recessed masonry', (.43,.39,.31), roughness=.95)
trim = material('Washington309 pale carved trim', (.68,.63,.52), roughness=.88)
glass = material('Washington309 recessed glass', (.12,.17,.18), roughness=.5)
night = material('Night Washington309 occupied windows', (.12,.17,.18), roughness=.5, glow=.2)
frame = material('Washington309 dark physical sash', (.08,.085,.08), metallic=.2)
roof = material('Washington309 opaque roof', (.30,.30,.28), roughness=.98)
cx, cz = -934.55, 201.05
data = json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
plan = [(x-cx, -(z-cz)) for x,z in next(b for b in data['buildings'] if b['o']=='w147013356')['f']]
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1])) < 0: plan.reverse()

def prism(name, points, lo, hi, mat):
    n=len(points)
    return mesh(name, [(x,y,z) for z in (lo,hi) for x,y in points],
                [tuple(reversed(range(n))), tuple(range(n,2*n))]+
                [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)], mat)

def orient(obj, a, b):
    tx,ty=b[0]-a[0],b[1]-a[1]; d=math.hypot(tx,ty);tx/=d;ty/=d
    for v in obj.data.vertices:
        x,y,z=v.co;v.co=(a[0]+x*tx+y*ty,a[1]+x*ty-y*tx,z)
    for polygon in obj.data.polygons: polygon.flip()
    return obj

def facade(name, pos, size, mat, a, b):
    return orient(box(name,pos,size,mat),a,b)

def segmental_head(name,u,z,width,rise,depth,mat,a,b):
    # Solid shallow curved band, not a photographic arch on a quad.
    vertices=[]
    for i in range(17):
        x=-width/2+width*i/16
        h=rise*math.sqrt(max(0,1-(2*x/width)**2))
        for y in (depth-.12,depth+.12):
            for dz in (0,.18): vertices.append((u+x,y,z+h+dz))
    faces=[]
    for i in range(16):
        p,q=i*4,(i+1)*4
        faces += [(p,q,q+1,p+1),(p+2,p+3,q+3,q+2),
                  (p,p+2,q+2,q),(p+1,q+1,q+3,p+3)]
    faces += [(0,1,3,2),(64,66,67,65)]
    return orient(mesh(name,vertices,faces,mat),a,b)

# ponytail: 13 stories and street photo establish form; 56m draft height and intervals are photo-fit, not surveyed.
H=56.; base=5.; pitch_z=4.1; body_top=base+12*pitch_z
prism('Exact mapped buried foundation',plan,-8,0,stone)
prism('Opaque recessed masonry core',[(x*.94,y*.94) for x,y in plan],0,H-.3,inset)
prism('Flat opaque roof membrane',plan,H-.3,H,roof)
for a,b in zip(plan,plan[1:]+plan[:1]):
    width=math.dist(a,b)
    # North and east street faces carry paired bays; hidden returns are a provisional continuation.
    count=12 if width>27 else 10
    pitch=width/count; pane_w=pitch-.65
    facade('Continuous backing behind ground glass',(width/2,-1.15,base/2),(width,.2,base),inset,a,b)
    for j in range(count+1):
        pier_top=base+10*pitch_z if j%2 else body_top
        facade('Continuous narrow masonry pier',(j*pitch,-.05,pier_top/2),(.38,.70,pier_top),stone,a,b)
        if j%2==0:
            facade('Paired bay projecting pilaster',(j*pitch,.07,(base+body_top)/2),(.40,.82,body_top-base),trim,a,b)
            facade('Ground storefront pier',(j*pitch,-.12,base/2),(.60,1.0,base),stone,a,b)
    for row in range(10):
        lo=base+row*pitch_z; ph=2.75; mid=lo+.35+ph/2
        facade('Recessed full floor spandrel',(width/2,-.24,lo+pitch_z-.45),(width,.42,.90),inset,a,b)
        for j in range(count):
            u=(j+.5)*pitch
            facade('Separate recessed window pane',(u,-.58,mid),(pane_w,.08,ph),night if (row*17+j*7)%29==4 else glass,a,b)
            for dx in (-pane_w/2,0,pane_w/2):
                facade('Physical sash upright',(u+dx,-.46,mid),(.055,.17,ph),frame,a,b)
            for z in (lo+.35,mid-.35,lo+.35+ph):
                facade('Physical sash rail',(u,-.45,z),(pane_w,.18,.055),frame,a,b)
            facade('Projecting pale stone sill',(u,-.04,lo+.25),(pane_w+.15,.65,.16),trim,a,b)
            if row==9:
                segmental_head('Shallow curved upper window surround',u,lo+.35+ph,pane_w,.35,.10,trim,a,b)
            if row in (0,9,10):
                facade('Relief spandrel panel',(u,.015,lo+pitch_z-.50),(pane_w*.68,.12,.38),stone,a,b)
                facade('Relief panel centre boss',(u,.10,lo+pitch_z-.50),(.20,.13,.23),trim,a,b)
    top_lo=base+10*pitch_z
    for j in range(count//2):
        u=(j+.5)*2*pitch; w=2*pitch-.65
        for row in range(2):
            lo=top_lo+row*pitch_z; ph=3.35
            facade('Grouped upper two floor glazing',(u,-.58,lo+.2+ph/2),(w,.08,ph),glass,a,b)
            for dx in (-w/2,0,w/2):
                facade('Upper paired sash mullion',(u+dx,-.45,lo+.2+ph/2),(.07,.20,ph),frame,a,b)
            for z in (lo+.2,lo+1.2,lo+.2+ph):
                facade('Upper paired sash horizontal rail',(u,-.45,z),(w,.20,.07),frame,a,b)
        facade('Recessed upper bay middle spandrel',(u,-.29,top_lo+pitch_z-.2),(w,.40,.60),inset,a,b)
        segmental_head('Wide grouped upper segmental surround',u,body_top-.55,w,.38,.10,trim,a,b)
        for dx in (-w/2,w/2):
            facade('Upper grouped surround upright',(u+dx,.08,(top_lo+body_top)/2),(.16,.24,body_top-top_lo-.4),trim,a,b)
    for j in range(count//2):
        u=(j+.5)*2*pitch; w=2*pitch-.72
        facade('Recessed storefront glass',(u,-.90,1.85),(w,.08,3.7),glass,a,b)
        for dx in (-w/2,0,w/2):
            facade('Storefront frame and door stile',(u+dx,-.77,1.85),(.085,.22,3.7),frame,a,b)
        segmental_head('Shaped ground storefront lintel',u,3.75,w,.42,.03,stone,a,b)
    for z,depth,height in [(base,.85,.42),(base+10*pitch_z,1.0,.30),(body_top,.95,.32),(H-.30,1.15,.30)]:
        facade('Continuous projecting masonry belt',(width/2,.05,z),(width,depth,height),trim,a,b)
    facade('Solid upper parapet',(width/2,-.03,(body_top+H)/2),(width,.70,H-body_top),stone,a,b)
    for j in range(count//2+1):
        facade('Raised parapet block',(j*2*pitch,.06,H-.18),(.65,.90,.70),trim,a,b)
for obj in bpy.context.scene.objects:
    if obj.type=='MESH': assert all(math.isfinite(v) for vertex in obj.data.vertices for v in vertex.co),obj.name
finish('washington_309',OUT)
