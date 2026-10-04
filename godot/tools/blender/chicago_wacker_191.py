"""Original modeled 191 North Wacker exterior. Blender +Y north, +Z up."""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box as baked_box,mesh,text,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
glass=material('Reflective blue grey curtain glass',(.15,.22,.25),roughness=.32)
occupied=material('Night occupied curtain glass',(.15,.22,.25),roughness=.32,glow=.25)
spandrel=material('Dark reflective glass spandrels',(.065,.105,.13),roughness=.38)
steel=material('Silver curtain mullions and lantern frame',(.39,.43,.44),metallic=.75,roughness=.33)
stone=material('Pale stone lobby piers',(.55,.51,.43),roughness=.62)
roof=material('Roof membrane and mechanical louvers',(.095,.11,.12),roughness=.85)
sleeve=material('Clear lantern sleeve',(.57,.68,.71),metallic=.12,roughness=.12)
sleeve.diffuse_color=(.57,.68,.71,.18)
sleeve.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.18
lantern=material('Night lantern solid inner volume',(.58,.66,.68),roughness=.6,glow=.25)
lobby=material('Clear lobby glazing',(.27,.35,.36),metallic=.15,roughness=.15)
interior=material('Lobby warm wall panels',(.42,.25,.14),roughness=.65)
W,D,MAIN,TOP=42.3,54.2,143.0,157.4


def box(name,pos,size,mat):
    obj=baked_box(name,(0,0,0),size,mat)
    obj.location=pos
    return obj


def orient(objects,angle):
    c,s=math.cos(angle),math.sin(angle)
    for obj in objects:
        x,y,z=obj.location
        obj.location=(x*c-y*s,x*s+y*c,z)
        obj.rotation_euler.z+=angle


box('Full rectangular tower',(0,0,(MAIN+8)/2),(W-.16,D-.16,MAIN-8),spandrel)
box('Lobby floor slab',(0,0,.15),(W,D,.3),stone)
box('Lobby interior core',(0,0,4),(W-11,D-10,8),interior)
box('Tower transfer soffit',(0,0,7.8),(W,D,.4),steel)


def facade(width,dist,angle,vertical):
    before=set(bpy.context.scene.objects)
    columns=round(width/1.52)
    pitch=width/columns
    floor_pitch=(135.0-8)/34
    for floor in range(36):
        z=8+floor*floor_pitch
        if z+floor_pitch>MAIN-.6:break
        for col in range(columns):
            x=-width/2+(col+.5)*pitch
            pane=occupied if (floor*11+col*3)%13 in (0,1,5) else glass
            box('Individual curtain vision pane',(x,dist+.015,z+floor_pitch*.61),
                (pitch-.065,.035,floor_pitch*.72),pane)
        box('Physical floor transom',(0,dist+.055,z),(width,.10,.07 if vertical else .13),steel)
        box('Recessed floor spandrel strip',(0,dist+.009,z+floor_pitch*.1),(width,.035,floor_pitch*.19),spandrel)
    for col in range(columns+1):
        x=-width/2+col*pitch
        box('Continuous vertical mullion',(x,dist+.075,(MAIN+8)/2),
            (.085 if vertical else .05,.16 if vertical else .09,MAIN-8),steel)
    for floor in range(4):
        box('Upper mechanical transom',(0,dist+.07,136.0+floor*1.65),(width,.13,.1),steel)
    # Glass lobby recessed behind a freestanding line of metallic/stone piers.
    for col in range(round(width/5.7)):
        x=-width/2+(col+.5)*width/round(width/5.7)
        box('Recessed lobby glass',(x,dist-.85,3.85),(5.25,.08,7.15),lobby)
        box('Lobby glass fin',(x+2.6,dist-.77,3.85),(.09,.24,7.3),steel)
        box('Freestanding lobby pier',(x+2.65,dist-.10,3.8),(.68,.85,7.6),stone)
    orient(set(bpy.context.scene.objects)-before,angle)


facade(W,D/2,0,False)
facade(D,W/2,math.pi/2,True)
facade(W,D/2,math.pi,False)
facade(D,W/2,-math.pi/2,True)
box('Flat main roof',(0,0,MAIN-.06),(W-.3,D-.3,.12),roof)
box('Mechanical penthouse',(0,-8,MAIN+2),(23,20,4),roof)
for i in range(7):box('Mechanical horizontal louvers',(0,-18.1,MAIN+.5+i*.5),(23,.22,.15),steel)
# Architect's lantern: solid inner rectangle with separate transparent sleeve.
# It spans the northern roof edge; inner block remains physically separated.
CY=D/2-5.15
BASE=MAIN
LH=TOP-BASE
box('Lantern opaque inner volume',(0,CY,(BASE+TOP-.7)/2),(W-3.2,6.2,LH-.7),lantern)
for y in (CY-4.7,CY+4.7):
    box('Lantern outer glass sleeve',(0,y,(BASE+TOP)/2),(W-.3,.05,LH),sleeve)
    for col in range(22):
        box('Lantern outer upright',(-W/2+.2+col*(W-.4)/21,y+.06,(BASE+TOP)/2),(.07,.11,LH),steel)
    for j in range(6):
        box('Lantern sleeve horizontal rail',(0,y+.06,BASE+j*LH/5),(W-.2,.11,.075),steel)
for x in (-W/2+.15,W/2-.15):
    box('Lantern end glass sleeve',(x,CY,(BASE+TOP)/2),(.05,9.4,LH),sleeve)
    for y in (CY-4.7,CY-2.35,CY,CY+2.35,CY+4.7):
        box('Lantern end upright',(x,y,(BASE+TOP)/2),(.11,.07,LH),steel)
    for j in range(6):box('Lantern end rail',(x,CY,BASE+j*LH/5),(.11,9.4,.075),steel)
# Raised west address, revolving door cylinder and flat canopy.
before=set(bpy.context.scene.objects)
box('Wacker entrance canopy',(0,W/2+.2,3.4),(11,2.3,.22),steel)
text('Raised Wacker address','191 NORTH WACKER',(0,W/2+1.38,3.7),.5,stone,
     rotate=(math.pi/2,0,math.pi),depth=.035)
for x in (-2.6,0,2.6):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=1.12,depth=2.9,location=(x,W/2-.65,1.6))
    door=bpy.context.object;door.name='Revolving lobby entrance';door.data.materials.append(lobby)
    box('Revolving door cross blade',(x,W/2-.65,1.6),(.075,2.0,2.85),steel)
    box('Revolving door second blade',(x,W/2-.65,1.6),(2.0,.075,2.85),steel)
orient(set(bpy.context.scene.objects)-before,math.pi/2)
bpy.context.view_layer.update()
from mathutils import Vector
tops=[(o.matrix_world@Vector(v)).z for o in bpy.context.scene.objects for v in o.bound_box]
assert abs(max(tops)-TOP)<.08,max(tops)
OUT.mkdir(parents=True,exist_ok=True)
finish('wacker_191',OUT)
