"""Original Blender exterior study of CBOT, in metres. No photograph textures.
North building local origin: Godot (-653, 8, 788). Input plan uses +Y south;
the final conversion mirrors Blender Y so glTF's +Y-up export preserves Godot Z.
Authoring reference: cbotbuilding.com/history and CAC building encyclopedia.
Run blender -b --python-exit-code 1 --python this.py -- <landmarks directory>.
"""
import math
import sys
from pathlib import Path
import bpy
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box, line, text, finish

OUT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Grey Indiana limestone', (.47, .45, .40), roughness=.8)
trim = material('Raised pale limestone', (.58, .55, .48), roughness=.75)
bronze = material('Recessed bronze spandrels', (.09, .12, .12), metallic=.5)
glass = material('Unlit recessed glazing', (.10, .15, .17), metallic=.35, roughness=.23)
lit = material('Night occupied windows', (.24, .19, .10), metallic=.3, glow=.7)
copper = material('Standing seam copper roof', (.21, .24, .20), metallic=.6)
aluminum = material('Ceres aluminum', (.65, .66, .65), metallic=.7, roughness=.38)
clock = material('Night clock ivory', (.64, .70, .68), glow=.4)
steel = material('Silver annex frames', (.34,.37,.39), metallic=.65, roughness=.4)
annex = material('Black annex cladding', (.075,.085,.09), metallic=.4)


def facade(width, depth, bottom, top, bays, floors, side, center=(0, 0)):
    """Bake coordinates explicitly, so facade rotations preserve local origins."""
    angle = side*math.pi/2
    c, s = math.cos(angle), math.sin(angle)
    def part(name, x, y, z, w, d, h, mat):
        obj = box(name, (0, 0, 0), (w, d, h), mat)
        obj.location = (center[0]+x*c-y*s, center[1]+x*s+y*c, z)
        obj.rotation_euler.z = angle
    pitch = width/bays
    step = (top-bottom)/floors
    for i in range(bays+1):
        x = -width/2+i*pitch
        part('Vertical limestone pier', x, -depth/2-.16, (bottom+top)/2,
             pitch*.43, .44, top-bottom, trim)
    for row in range(floors):
        for bay in range(bays):
            x = -width/2+(bay+.5)*pitch
            z = bottom+(row+.5)*step
            w = pitch*.48
            part('Dark inset window', x, -depth/2-.03, z+.17,
                 w, .08, step-.7, lit if (row*7+bay*3+side)%6==0 else glass)
            part('Metal spandrel', x, -depth/2-.10, z-step/2+.22, w, .20, .44, bronze)
            part('Window mullion', x, -depth/2-.12, z+.17, .065, .18, step-.7, bronze)
            part('Window transom', x, -depth/2-.12, z+.23, w, .18, .07, bronze)


def tier(width, depth, bottom, top, bays, floors, center=(0, 0), north=True):
    box('Limestone office mass', (*center, (bottom+top)/2), (width, depth, top-bottom), stone)
    for side in range(4):
        if side == 0 and not north:
            continue
        facade(width if side%2==0 else depth, depth if side%2==0 else width,
               bottom+1, top-.5, bays if side%2==0 else max(4, round(depth/3.1)), floors, side, center)
    box('Setback coping', (*center, top), (width+.45, depth+.45, .5), trim)
    box('Dark terrace roof', (*center, top+.28), (width-.1, depth-.1, .08), copper)


# Original north building: broad low base, recessed central front court and
# symmetrical side shoulders. Dimensions are architectural approximations.
tier(52, 72, 0, 34, 16, 9, north=False)
for side in [-1, 1]:
    tier(13, 72, 34, 78, 4, 12, (side*19.5, 0))
tier(26, 54, 34, 102, 8, 18, (0, 9))
tier(36, 42, 78, 122, 11, 12, (0, 9))
tier(30, 34, 122, 144, 9, 6, (0, 9))
tier(24, 27, 144, 158, 7, 4, (0, 9))
tier(27, 29, 158, 163, 8, 1, (0, 9))

# Four-sided hipped roof, with actual seam ribs rather than a triangular prism.
corners = [(-13.5,-5.5,163),(13.5,-5.5,163),(13.5,23.5,163),(-13.5,23.5,163)]
apex = (0,9,175)
mesh('Four sided copper pyramid', corners+[apex], [(0,1,4),(1,2,4),(2,3,4),(3,0,4)], copper)
for i in range(4):
    a, b = corners[i], corners[(i+1)%4]
    for j in range(25):
        t = j/24
        base = tuple(a[k]*(1-t)+b[k]*t for k in range(3))
        line('Standing copper seam', [base, apex], .035, copper)

# Stylized faceless Ceres, 31 feet tall; ribbed dress, arms, sheaf and corn bag.
box('Ceres pedestal', (0,9,175.3), (2.7,2.7,.6), aluminum)
verts = [(x,y,z) for z,w,d in [(175.6,.8,.5),(182.6,1.2,.6)]
         for x,y in [(-w,9-d),(w,9-d),(w,9+d),(-w,9+d)]]
mesh('Ceres fluted robe', verts, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], aluminum)
for x in [-.6,-.3,0,.3,.6]:
    line('Vertical garment fold', [(x,8.45,175.7),(x*1.45,8.35,182.4)], .06, trim)
box('Ceres neck', (0,9,182.85), (.65,.65,.5), aluminum)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(0,9,183.65))
bpy.context.object.name='Faceless Ceres head'
bpy.context.object.scale=(.62,.57,.85)
bpy.context.object.data.materials.append(aluminum)
for side in [-1,1]:
    line('Ceres angular arm', [(side*1.1,9,182.3),(side*1.25,8.9,179.1),(side*.7,8.35,178.7)], .22, aluminum)
for dx in [-.15,0,.15]:
    line('Ceres wheat sheaf', [(-.8+dx,8.2,179),(-1+dx,8.2,182.3)], .06, aluminum)
box('Ceres corn bag', (.8,8.2,178.5), (.7,.45,.95), aluminum)

# Clock at the north court parapet, diameter 13 ft. Mesh Roman numerals/hands.
cy, cz = -36.25, 31.2
arch_radius = 1.9812
vertices=[(0,cy,cz)]+[(arch_radius*math.cos(i*math.tau/96),cy,cz+arch_radius*math.sin(i*math.tau/96)) for i in range(96)]
mesh('LaSalle clock dial',vertices,[(0,i+1,(i+1)%96+1) for i in range(96)],clock)
line('Clock bronze rim', vertices[1:]+[vertices[1]], .12, bronze)
for i,roman in enumerate(['XII','I','II','III','IV','V','VI','VII','VIII','IX','X','XI']):
    a=math.pi/2-i*math.tau/12
    numeral=text('Clock numeral',roman,(-1.6*math.cos(a),cy-.03,cz+1.6*math.sin(a)),.33,bronze,depth=.02)
    numeral.scale.x=-1  # Front-facing letters remain readable after the plan conversion.
line('Clock minute hand',[(0,cy-.10,cz),(0,cy-.10,cz+1.4)],.07,bronze)
line('Clock hour hand',[(0,cy-.12,cz),(-.95,cy-.12,cz+.4)],.10,bronze)
inscription=text('North inscription','CHICAGO BOARD OF TRADE',(0,-36.20,25),1.45,bronze,depth=.04)
inscription.scale.x=-1
for x in [-18,-9,0,9,18]:
    box('Tall trading-floor window', (x,-36.05,16), (3.8,.12,15), glass)
    box('Ground entrance glazing', (x,-36.05,5), (3.8,.12,6), bronze)
    for z in [10,13.5,17,20.5]:
        box('Trading-floor metal transom',(x,-36.18,z),(3.8,.22,.10),bronze)
    for dx in [-1,0,1]:
        box('Trading-floor vertical mullion',(x+dx,-36.18,16),(.10,.22,15),bronze)

# Relief silhouettes flank the clock: original stylization, not copied scans.
for x in [-3.6,3.6]:
    box('Hooded figure robe',(x,-36.5,31.3),(1.1,.65,4.8),trim)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=(x,-36.65,34))
    bpy.context.object.name='Hooded clock figure'
    bpy.context.object.scale=(.6,.42,.7)
    bpy.context.object.data.materials.append(trim)
    line('Figure folded arm',[(x-.5,-36.95,32.7),(x-.3,-37,31.6),(x+.4,-37,32.1)],.18,stone)
    for dx in [-.2,0,.2]:
        line('Held grain relief',[(x+dx,-37,31.7),(x+dx+.2,-37,33.1)],.06,stone)
mesh('Clock eagle spread wings',[(-1.7,-36.65,34.5),(-1.4,-36.65,35.3),
     (-.3,-36.65,34.8),(0,-36.65,35.6),(.3,-36.65,34.8),
     (1.4,-36.65,35.3),(1.7,-36.65,34.5),(0,-36.65,34)],
     [(0,1,2,7),(2,3,4,7),(4,5,6,7)],trim)
def metal_elevation(cx, cy, width, depth, bottom, top, bays, floors, side):
    angle=side*math.pi/2
    c,s=math.cos(angle),math.sin(angle)
    def part(name,x,y,z,w,d,h,mat):
        obj=box(name,(0,0,0),(w,d,h),mat)
        obj.location=(cx+x*c-y*s,cy+x*s+y*c,z)
        obj.rotation_euler.z=angle
    pitch=width/bays
    for row in range(floors):
        step=(top-bottom)/floors
        for bay in range(bays):
            x=-width/2+(bay+.5)*pitch
            z=bottom+(row+.5)*step
            part('Annex glazing',x,-depth/2-.02,z,pitch-.18,.08,step-.32,
                 lit if (bay+row*3+side)%9==0 else glass)
            part('Annex horizontal metal band',x,-depth/2-.13,z-step/2,pitch,.20,.25,steel)
    for bay in range(bays+1):
        part('Annex silver mullion',-width/2+bay*pitch,-depth/2-.12,(top+bottom)/2,
             .12,.20,top-bottom,steel)


# Later south wing fits the south end of the mapped compound, not the clock tower.
# LiDAR regional roof median 88.5 m includes terrace/roof machinery; office body 82 m.
box('South annex dark office core',(0,60,41),(52,48,82),annex)
for side in range(4):
    metal_elevation(0,60,52 if side%2==0 else 48,48 if side%2==0 else 52,
                    1,82,17 if side%2==0 else 16,23,side)
for z,r in [(82.3,23),(85,19),(88,15),(91,11)]:
    vertices=[(r*math.cos(i*math.tau/8+math.pi/8),60+r*math.sin(i*math.tau/8+math.pi/8),h)
              for h in [z,z+2.8] for i in range(8)]
    mesh('South octagonal roof terrace',vertices,
         [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]+[tuple(range(8,16))],steel)
for x in [-17,17]:
    box('South raised corner shoulder',(x,60,85),(8,40,6),annex)

# East trading hall: tall curtain-wall openings surrounded by limestone piers.
# Existing USGS roof cells median 40.5 m, unlike the much taller historic tower.
box('East trading hall core',(81,47,20.25),(64,74,40.5),stone)
for side in range(4):
    w,d=(64,74) if side%2==0 else (74,64)
    angle=side*math.pi/2
    for bay in range(6):
        x=-w/2+(bay+.5)*w/6
        for row in range(8):
            z=13.5+(row+.5)*2.85
            obj=box('Trading hall curtain glazing',(0,0,0),(w/6-1.8,.08,2.73),glass)
            obj.location=(81+x*math.cos(angle)+(d/2+.03)*math.sin(angle),
                          47+x*math.sin(angle)-(d/2+.03)*math.cos(angle),z)
            obj.rotation_euler.z=angle
        # Sash grid is actual metal, not a photographed pane pattern.
        for dx in [-w/6*.28,0,w/6*.28]:
            obj=box('Trading hall silver vertical sash',(0,0,0),(.10,.18,22.8),steel)
            obj.location=(81+(x+dx)*math.cos(angle)+(d/2+.12)*math.sin(angle),
                          47+(x+dx)*math.sin(angle)-(d/2+.12)*math.cos(angle),24.9)
            obj.rotation_euler.z=angle
    for z in [4,8,12,37,40.3]:
        obj=box('Trading hall horizontal stone joint',(0,0,0),(w,.12,.065),bronze)
        obj.location=(81+(d/2+.025)*math.sin(angle),47-(d/2+.025)*math.cos(angle),z)
        obj.rotation_euler.z=angle

# Elevated hall span over the mapped north-south LaSalle plaza, open below 12.3 m.
box('LaSalle raised hall span',(36,47,26.4),(26,74,28.2),stone)
for side in [0,2]:
    metal_elevation(36,47,26,74,14,37,8,8,side)
for x in [24,48]:
    for y in [13,81]:
        box('LaSalle span bearing',(x,y,6.15),(2.6,3.5,12.3),stone)

# Repeating crown reliefs use small geometric grain/sheaf motifs, no image panels.
for side in range(4):
    angle=side*math.pi/2
    depth=29 if side%2==0 else 27
    for x in [-10,-5,0,5,10]:
        for dx in [-.18,0,.18]:
            p=(x+dx,-depth/2-.15)
            q=(x+dx*2,-depth/2-.15)
            line('Crown grain relief',[(p[0]*math.cos(angle)-p[1]*math.sin(angle),
                 9+p[0]*math.sin(angle)+p[1]*math.cos(angle),161),
                 (q[0]*math.cos(angle)-q[1]*math.sin(angle),
                 9+q[0]*math.sin(angle)+q[1]*math.cos(angle),162.4)],.06,trim)

# Bound the actual authored compound, including relief and parapet overhangs.
from mathutils import Vector
bpy.context.view_layer.update()
points=[o.matrix_world@Vector(p) for o in bpy.context.scene.objects for p in o.bound_box]
assert min(p.z for p in points)>=-.01 and 184<max(p.z for p in points)<185
assert min(p.x for p in points)>-32 and max(p.x for p in points)<114
assert min(p.y for p in points)>-38 and max(p.y for p in points)<86
# glTF maps Blender +Y to Godot -Z. Preserve the mapped plan, including the
# asymmetric annexes and north clock face, and reverse winding after reflection.
from mathutils import Matrix
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.convert(target='MESH')
reflection=Matrix.Diagonal((1,-1,1,1))
for obj in bpy.context.scene.objects:
    transform=reflection @ obj.matrix_world
    obj.data.transform(transform)
    if transform.determinant()<0:
        obj.data.flip_normals()
    obj.matrix_world=Matrix.Identity(4)
finish('board_of_trade',OUT)
