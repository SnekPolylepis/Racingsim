"""Original Monadnock exterior, Blender +Y north. See asset SOURCES.md."""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, text, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
brick = material('Dark brown molded brick', (.28,.19,.135), roughness=.85)
trim = material('Southern brown terra cotta', (.36,.25,.17), roughness=.72)
stone = material('Entrance limestone blocks', (.45,.41,.32), roughness=.78)
sash = material('Dark wood double hung sash', (.09,.085,.065), roughness=.58)
glass = material('Unoccupied office glass', (.12,.17,.18), metallic=.25, roughness=.27)
lit = material('Night occupied office glass', (.12,.17,.18), metallic=.25, roughness=.27, glow=.3)
gold = material('Ochre retail door frames', (.51,.34,.09), metallic=.25, roughness=.45)
roof = material('Flat roof and skylight frames', (.13,.125,.11), roughness=.85)
W,D,TOP = 19.8,122.0,65.532


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


def loft(name,levels,mat):
    # Chamfer increases with height, northern mass flares at base and cornice.
    verts=[]
    for z,w,d,cy,ch in levels:
        a,b=w/2,d/2
        verts += [(x,y+cy,z) for x,y in [(-a+ch,-b),(a-ch,-b),(a,-b+ch),
                  (a,b-ch),(a-ch,b),(-a+ch,b),(-a,b-ch),(-a,-b+ch)]]
    faces=[tuple(range(7,-1,-1))]
    for i in range(len(levels)-1):
        for j in range(8):faces.append((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j))
    faces.append(tuple((len(levels)-1)*8+j for j in range(8)))
    return mesh(name,verts,faces,mat)


north_mass=loft('Northern flared chamfered masonry',[(0,W,61,30.5,.08),(4.5,W,61,30.5,.15),
     (7.7,W-.65,60.7,30.5,.25),(9,W-.85,60.5,30.5,.35),
     (61.8,W-.85,60.5,30.5,.9),(63,W-.75,60.6,30.5,1.0),
     (64.2,W,61.0,30.5,1.05),(TOP,W+.35,61.25,30.5,1.1)],brick)
north_mass.data.materials.append(roof)
north_mass.data.polygons[-1].material_index=1
box('Southern steel framed masonry',(0,-30.5,31.6),(W-.5,61,63.2),brick)


def window(x,y,z,width=1.1,height=2.55,index=0):
    box('Glass single light sash',(x,y,z),(width,.045,height),lit if index%7 in (0,2) else glass)
    for sx in (-1,1):box('Wood window jamb',(x+sx*(width/2+.045),y+.035,z),(.09,.09,height+.18),sash)
    for dz in (-height/2,0,height/2):box('Double hung rail',(x,y+.04,z+dz),(width+.18,.09,.09),sash)
    box('Thin iron sill',(x,y+.095,z-height/2-.10),(width+.28,.22,.075),sash)


def bay(center,y0,z0,z1,south=False):
    # Rounded north bay section; south uses broad paired polygonal oriels.
    if south:profile=[(-2.05,0),(-1.4,1.05),(1.4,1.05),(2.05,0)]
    else:profile=[(-2.15,0),(-1.8,.43),(-1.2,.83),(-.6,1.04),(.6,1.04),(1.2,.83),(1.8,.43),(2.15,0)]
    levels=[(z0,0),(z0+.65,1),(z1,1)]
    verts=[(center+x,y0+y*scale,z) for z,scale in levels for x,y in profile]
    n=len(profile);faces=[]
    for layer in range(2):
        for j in range(n-1):faces.append((layer*n+j,layer*n+j+1,(layer+1)*n+j+1,(layer+1)*n+j))
    faces += [tuple(range(n-1,-1,-1)),tuple(2*n+j for j in range(n))]
    mesh('Cantilevered molded oriel',verts,faces,trim if south else brick)
    # Windows align to actual bay tangents, giving glazing a changing normal.
    spans=[(0,1),(1,2),(2,3)] if south else [(1,2),(3,4),(5,6)]
    for floor in range(2,15):
        z=5.0+floor*3.72
        for part,(a,b) in enumerate(spans):
            x1,y1=profile[a];x2,y2=profile[b]
            length=math.hypot(x2-x1,y2-y1)
            before=set(bpy.context.scene.objects)
            # Wide south front is two sash windows; north has three light faces.
            count=2 if south and part==1 else 1
            for j in range(count):window((j-(count-1)/2)*length/count,0,z,length/count-.18,2.65,floor+part+j)
            orient(set(bpy.context.scene.objects)-before,math.atan2(y2-y1,x2-x1),
                   (center+(x1+x2)/2,y0+(y1+y2)/2+.055))


def long_face(side):
    before=set(bpy.context.scene.objects)
    # Local horizontal coordinate follows north-south block length.
    for north in (True,False):
        centers=[6.1+j*12.1 for j in range(5)] if north else [-55.0+j*12.1 for j in range(5)]
        for center in centers:bay(center,W/2-.38,8.9,60.8,not north)
        for i in range(16):
            x=(2+i*3.65) if north else (-59+i*3.65)
            # Flat panes in the gaps, between the oriels.
            if min(abs(x-c) for c in centers)<2.65:continue
            for f in range(1,17):window(x,W/2-.10,5+f*3.55,1.25,2.55,i+f)
        if not north:
            for z in (7.4,11.4,57.9,61.6,63.0):box('Southern terra cotta belt',( -30.5,W/2+.05,z),(61,.38,.24),trim)
            for i in range(20):box('Southern cornice brackets',(-59+i*3,W/2+.28,63.2),(.35,.8,.7),trim)
            for z,depth in [(63.3,.7),(63.8,1.0),(64.2,1.35),(64.65,1.65)]:
                box('Southern projecting cornice',(-30.5,W/2+depth/2-.2,z),(61,depth,.28),trim)
    for i in range(30):
        x=-58+i*4
        box('Retail glazing',(x,W/2+.015,2.05),(3.25,.08,3.35),glass)
        for sx in (-1,1):box('Retail ochre jamb',(x+sx*1.62,W/2+.08,2.05),(.12,.14,3.55),gold)
        for z in (.38,3.75):box('Retail lintel',(x,W/2+.08,z),(3.4,.14,.13),sash)
    for x,label in [(45.5,'MONADNOCK'),(15,'KEARSARGE'),(-15,'KATAHDIN'),(-45.5,'WACHUSETT')]:
        for sx in (-1,1):
            for j in range(5):box('Entrance stone blocks',(x+sx*1.25,W/2+.22,.4+j*.67),(.5,.46,.62),stone)
        box('Entrance stone name lintel',(x,W/2+.24,3.75),(3.1,.48,.75),stone)
        text('Mountain name',label,(x,W/2+.51,3.75),.34,gold,rotate=(math.pi/2,0,math.pi),depth=.035)
    objects=set(bpy.context.scene.objects)-before
    if side==1:
        for obj in objects:
            obj.location.x *= -1
            if obj.type != 'FONT': obj.scale.x *= -1
    orient(objects,-math.pi/2 if side==1 else math.pi/2,(0,0))


long_face(1);long_face(-1)
# North five-axis face: two curved bays plus plain end/centre windows.
before=set(bpy.context.scene.objects)
for x in (-4.6,4.6):bay(x,D/2-.2,8.9,60.8)
for x in (-8.1,0,8.1):
    for f in range(1,17):window(x,D/2+.02,5+f*3.55,1.25,2.55,f)
box('Jackson entry lintel',(0,D/2+.14,3.7),(3.5,.4,.75),stone)
for x in (-1.5,1.5):box('Jackson entry pier',(x,D/2+.14,1.8),(.5,.4,3.6),stone)
text('North building name','MONADNOCK',(0,D/2+.38,3.7),.35,gold,rotate=(math.pi/2,0,math.pi),depth=.04)
box('Jackson doorway',(0,D/2+.05,1.7),(2.4,.08,3.25),glass)
for x in (-5.4,5.4):
    box('Jackson shop window',(x,D/2+.06,2.0),(4.0,.08,3.3),glass)
    for sx in (-1,1):box('Jackson shop jamb',(x+sx*2,D/2+.13,2.0),(.12,.14,3.5),gold)
    for z in (.35,3.65):box('Jackson shop rail',(x,D/2+.13,z),(4.15,.14,.12),sash)
# Southern end has narrow piers and decorated top rather than northern flare.
for f in range(1,17):
    for i,x in enumerate((-7.5,-3.75,0,3.75,7.5)):
        before=set(bpy.context.scene.objects);window(x,0,5+f*3.55,2.5,2.55,i+f)
        orient(set(bpy.context.scene.objects)-before,math.pi,(0,-D/2))
for z,depth in [(7.4,.3),(61.6,.45),(63.5,.8),(64.65,1.2)]:
    box('Van Buren cornice',(0,-D/2-depth/2+.1,z),(W+.6,depth,.3),trim)
box('Roof deck',(0,0,63.35),(W-1.6,D-1.2,.25),roof)
for cy in (45.5,15.25,-15.25,-45.5):
    z=TOP if cy>0 else 63.5
    box('Central skylight curb',(0,cy,z+.25),(3.0,7.0,.5),roof)
    box('Central skylight glass',(0,cy,z+.53),(2.8,6.8,.08),glass)
    for y in (-2,0,2):box('Skylight glazing bar',(0,cy+y,z+.58),(2.9,.08,.08),sash)
bpy.context.view_layer.update()
tops=[(o.matrix_world@__import__('mathutils').Vector(v)).z for o in bpy.context.scene.objects for v in o.bound_box]
assert abs(max(tops)-(TOP+.62))<.01, max(tops)
OUT.mkdir(parents=True,exist_ok=True)
finish('monadnock_building',OUT)
