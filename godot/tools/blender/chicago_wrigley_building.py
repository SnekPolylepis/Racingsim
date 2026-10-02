"""Original Blender Wrigley Building exterior, using mapped OSM block outlines.
References: Chicago Architecture Center exterior; owner Zeller legacy/detail photos.
blender -b --python tools/blender/chicago_wrigley_building.py -- <output dir>
Local origin: Chicago world (-40, 8, -530); Blender +Y is world north.
"""
import bpy
import json
import math
import sys
from mathutils import Vector
from mathutils.geometry import tessellate_polygon, intersect_point_tri_2d
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box as baked_box, line, arch, text, finish

OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
tiles = [material('Night glazed terra cotta %d' % i,
         (.44+i*.025,.42+i*.026,.38+i*.029), roughness=.52, glow=.12) for i in range(6)]
stone = tiles[-1]
bronze = material('Dark bronze frames',(.13,.14,.12),metallic=.6,roughness=.4)
glass = material('Unlit blue recessed glass',(.035,.07,.09),metallic=.25,roughness=.23)
warm = material('Night occupied office glass',(.04,.07,.08),metallic=.25,roughness=.23,glow=.7)
warm.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(1,.64,.32,1)
clock = material('Night ivory clock dials',(.72,.70,.63),roughness=.8,glow=.5)
black = material('Black clock numerals and hands',(.025,.027,.025),roughness=.65)
roof = material('Roof membrane',(.18,.19,.17),roughness=.85)
doc = json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text())
blocks = sorted([b for b in doc['buildings'] if b.get('o')=='r17460539'],key=lambda b:-b['h'])
assert len(blocks)==2
cx,cy=-6,-12
roof_vertices=[Vector((p[0]+40,-(p[1]+530),0)) for p in blocks[0]['f']]
roof_triangles=tessellate_polygon([roof_vertices])
for x in [-8.5,8.5]:
    for y in [-8.5,8.5]:
        assert any(intersect_point_tri_2d(Vector((cx+x,cy+y)),
                   *(roof_vertices[i].to_2d() for i in tri)) for tri in roof_triangles), 'Clock shaft must sit on the mapped south roof'


def box(name, pos, size, mat):
    # Rotated elevations need their own centre as the object origin.
    obj = baked_box(name, (0,0,0), size, mat)
    obj.location = pos
    return obj


def prism(name, ring, bottom, top, mat):
    ring = list(ring)
    if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1]))<0:
        ring.reverse()
    n=len(ring)
    vertices=[(x,y,z) for z in [bottom,top] for x,y in ring]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vertices,faces,mat)


def finial(x,y,z,size=.4):
    box('Parapet finial foot',(x,y,z+.15),(size*1.6,size*1.6,.3),stone)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=size,location=(x,y,z+.65))
    bpy.context.object.data.materials.append(stone)
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=size*.7,radius2=.05,depth=.9,location=(x,y,z+1.45))
    bpy.context.object.data.materials.append(stone)


def facade(ring, top, floors):
    ring=list(ring)
    if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(ring,ring[1:]+ring[:1]))<0:ring.reverse()
    for edge,a in enumerate(ring):
        b=ring[(edge+1)%len(ring)]
        span=math.dist(a,b)
        if span<2:continue
        tx,ty=(b[0]-a[0])/span,(b[1]-a[1])/span
        nx,ny=ty,-tx
        mid=((a[0]+b[0])/2,(a[1]+b[1])/2)
        angle=math.atan2(ty,tx)
        bays=max(1,int(span/2.8))
        pitch=span/bays
        for row in range(floors):
            z=7+(row+.5)*(top-9)/floors
            tile=tiles[min(5,row*6//floors)]
            for i in range(bays):
                u=(i+.5)*pitch
                x,y=a[0]+tx*u,a[1]+ty*u
                for name,width,depth,height,dz,offset,mat in [
                    ('Recessed window',min(1.5,pitch-.7),.10,2.35,0,.055,warm if (i+row*3+edge)%5==0 else glass),
                    ('Raised window sill',min(1.85,pitch-.3),.48,.16,-1.3,.18,tile),
                    ('Window lintel',min(1.85,pitch-.3),.35,.22,1.32,.12,tile),
                    ('Bronze sash mullion',.075,.17,2.35,0,.14,bronze),
                    ('Bronze sash transom',min(1.5,pitch-.7),.17,.07,.1,.14,bronze)]:
                    obj=box(name,(x+nx*offset,y+ny*offset,z+dz),(width,depth,height),mat)
                    obj.rotation_euler.z=angle
        # Layered horizontal mouldings and regularly spaced real parapet urns.
        for z,depth,height in [(6,.35,.4),(top-3,.4,.35),(top-.5,.65,.6),(top+.1,.85,.25)]:
            obj=box('Terra cotta cornice',(mid[0]+nx*.15,mid[1]+ny*.15,z),(span,depth,height),stone)
            obj.rotation_euler.z=angle
        for i in range(max(1,int(span/4))):
            u=(i+.5)*span/max(1,int(span/4))
            finial(a[0]+tx*u,a[1]+ty*u,top+.3,.28)


for index,b in enumerate(blocks):
    ring=[(p[0]+40,-(p[1]+530)) for p in b['f']]
    top=61 if index==0 else 64
    for i in range(6):
        prism('Mapped terra cotta office block',ring,top*i/6,top*(i+1)/6,tiles[i])
    prism('Flat roof',ring,top,top+.08,roof)
    facade(ring,top,14 if index==0 else 15)

# South clock tower, on the mapped south block, above its trapezoidal main roof.
box('South clock tower shaft',(cx,cy,76),(17,17,30),tiles[4])
square=[(cx-8.5,cy-8.5),(cx+8.5,cy-8.5),(cx+8.5,cy+8.5),(cx-8.5,cy+8.5)]
# Upper narrow office bays have explicit stone piers and sash glazing.
for side in range(4):
    angle=side*math.pi/2
    for x in [-5,0,5]:
        for z in [65,70,75,80,85]:
            previous=set(bpy.context.scene.objects)
            box('Tower recessed window',(x,-8.56,z),(2.4,.12,3.5),glass)
            for dx in [-1.35,1.35]:box('Tower window pier',(x+dx,-8.75,z),(.32,.5,4.5),stone)
            for obj in set(bpy.context.scene.objects)-previous:
                ox,oy,oz=obj.location
                obj.location=(cx+ox*math.cos(angle)-oy*math.sin(angle),cy+ox*math.sin(angle)+oy*math.cos(angle),oz)
                obj.rotation_euler.z=angle
box('Four sided clock chamber',(cx,cy,99),(16,16,16),tiles[4])
box('Upper clock storey supporting the colonnade',(cx,cy,109.6),(12,12,5.2),tiles[4])
for z in [90.7,107.4,112]:box('Clock chamber cornice',(cx,cy,z),(18,18,.7),stone)

# Four 6.1 m dials with modeled rings, twelve hour marks and separate hands.
for side in range(4):
    previous=set(bpy.context.scene.objects)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=2.9845,depth=.12,location=(0,-8.08,99),rotation=(math.pi/2,0,0))
    bpy.context.object.name='Ivory clock dial'
    bpy.context.object.data.materials.append(clock)
    arch('Clock moulded circular rim',3.08,3.43,(0,99),-8.3,.3,stone,end=math.tau,segments=64)
    for i,value in enumerate(['XII','I','II','III','IIII','V','VI','VII','VIII','IX','X','XI']):
        a=i*math.tau/12
        text('Clock Roman numeral',value,(2.5*math.sin(a),-8.22,99+2.5*math.cos(a)),.37,black)
    line('Clock minute hand',[(0,-8.28,99),(1.95,-8.28,100.12)],.10,black)
    line('Clock hour hand',[(0,-8.31,99),(-1.35,-8.31,99.78)],.14,black)
    angle=side*math.pi/2
    for obj in set(bpy.context.scene.objects)-previous:
        x,y,z=obj.location
        obj.location=(cx+x*math.cos(angle)-y*math.sin(angle),cy+x*math.sin(angle)+y*math.cos(angle),z)
        obj.rotation_euler.z+=angle
    for x in [-4,0,4]:
        px,py=cx+x*math.cos(angle)+6.07*math.sin(angle),cy+x*math.sin(angle)-6.07*math.cos(angle)
        obj=box('Upper clock storey glazing',(px,py,109.7),(1.7,.12,3.3),glass)
        obj.rotation_euler.z=angle
    # Ionic colonnade above the dial, open around an inset octagonal core.
    for x in [-6,-2,2,6]:
        ox,oy=x,-6
        px,py=cx+ox*math.cos(angle)-oy*math.sin(angle),cy+ox*math.sin(angle)+oy*math.cos(angle)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.36,depth=8,location=(px,py,116.5))
        bpy.context.object.data.materials.append(stone)
        for z in [112.5,120.5]:box('Column capital',(px,py,z),(.95,.95,.5),stone)
box('Colonnade entablature',(cx,cy,121),(15,15,1),stone)
bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=3.5,depth=8.4,location=(cx,cy,116.5))
bpy.context.object.data.materials.append(tiles[4])
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=6,radius2=3,depth=3,location=(cx,cy,123))
bpy.context.object.data.materials.append(stone)
bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=2,depth=3,location=(cx,cy,126))
bpy.context.object.data.materials.append(stone)
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=2.6,radius2=.2,depth=3,location=(cx,cy,129))
bpy.context.object.data.materials.append(stone)
finial(cx,cy,130.2,.4)

# North block pavilion: inset glazing, pilasters, parapet and a hipped crown.
nx,ny=8,31
box('North rooftop pavilion',(nx,ny,74),(15,15,20),tiles[4])
for side in range(4):
    angle=side*math.pi/2
    for x in [-4,0,4]:
        px,py=nx+x*math.cos(angle)+7.58*math.sin(angle),ny+x*math.sin(angle)-7.58*math.cos(angle)
        obj=box('North pavilion tall window',(px,py,75),(2,.12,11),glass)
        obj.rotation_euler.z=angle
box('North pavilion cornice',(nx,ny,84),(17,17,.7),stone)
bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=10,radius2=3,depth=7,location=(nx,ny,87.85),rotation=(0,0,math.pi/4))
bpy.context.object.data.materials.append(roof)
finial(nx,ny,91.35,.35)

# Enclosed bridges cross the plaza only; approximate the cited third/14th-floor links.
for z in [11,53]:
    box('Enclosed plaza skybridge',(-2,12,z),(6,15,3.4),tiles[3])
    for x in [-5.06,1.06]:
        for y in [6.5,9.5,12.5,15.5,18.5]:
            box('Bridge recessed glazing',(x,y,z),(.12,1.8,2),glass)
finish('wrigley_building',OUT)
