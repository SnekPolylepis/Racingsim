"""Original modeled Carbide and Carbon exterior; references and limits in SOURCES.md.
Blender +Y is north, +Z up; tower occupies the east end of its mapped footprint.
"""
import bpy
import math
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, line, arch, text, finish
OUT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
green = material('Bottle green terra cotta', (.12,.23,.16), roughness=.48)
raised = material('Raised green glazed piers', (.20,.32,.23), roughness=.42)
black = material('Polished black granite base', (.035,.043,.040), metallic=.15, roughness=.22)
gold = material('Night gilded crown and relief', (.70,.46,.12), metallic=.7, roughness=.3, glow=.25)
bronze = material('Bronze window frames', (.19,.16,.10), metallic=.6, roughness=.38)
glass = material('Unoccupied inset glazing', (.075,.14,.15), metallic=.35, roughness=.22)
lit = material('Night occupied inset glazing', (.075,.14,.15), metallic=.35, roughness=.22, glow=.3)
roof = material('Setback terrace roofing', (.09,.12,.10), roughness=.85)


def box(name, pos, size, mat):
    obj=baked_box(name,(0,0,0),size,mat)
    obj.location=pos
    return obj


def orient(objects, angle, offset):
    c,s=math.cos(angle),math.sin(angle)
    for obj in objects:
        x,y,z=obj.location
        obj.location=(offset[0]+x*c-y*s,offset[1]+x*s+y*c,z)
        obj.rotation_euler.z+=angle


def relief(x,y,z,scale=1):
    # Physical stylized botanical fan: central stem, paired angular leaves.
    box('Relief vertical stem',(x,y,z),(.10*scale,.16,1.4*scale),gold)
    for side in [-1,1]:
        for row in range(3):
            obj=box('Raised gilded leaf',(x+side*(.18+row*.08)*scale,y,z+(.3-row*.35)*scale),(.13*scale,.18,.65*scale),gold)
            obj.rotation_euler.y=side*.65


def elevation(width,depth,bottom,top,bays,floors,side,offset=(0,0),base=False):
    before=set(bpy.context.scene.objects)
    pitch=width/bays
    step=(top-bottom)/floors
    face=depth/2
    for i in range(bays+1):
        x=-width/2+i*pitch
        box('Continuous raised facade pier',(x,face+.13,(bottom+top)/2),(.60,.34,top-bottom),black if base else raised)
        if not base:
            box('Pier fluting',(x,face+.32,(bottom+top)/2),(.10,.08,top-bottom-.6),green)
    for row in range(floors):
        z=bottom+(row+.5)*step
        for i in range(bays):
            x=-width/2+(i+.5)*pitch
            pane=pitch-.70
            height=step-.65
            box('Inset dimensional window',(x,face+.02,z),(pane,.09,height),lit if (row*5+i*3+side)%11<4 else glass)
            for u in [-1,1]:
                box('Bronze jamb',(x+u*pane/2,face+.10,z),(.075,.15,height),bronze)
            for h in [-1,0,1]:
                box('Window sash and transom',(x,face+.11,z+h*height/2),(pane,.15,.08),bronze)
            box('Projected glazed sill',(x,face+.17,z-height/2-.1),(pane+.16,.32,.16),raised if not base else black)
            box('Recessed spandrel panel',(x,face+.06,z-step/2+.2),(pane,.17,.30),green if not base else black)
            if not base and row%4==0:
                # Small molded volutes on the actual spandrel, never a flat photo.
                for dx in [-.23,.23]:
                    arch('Spandrel volute',.10,.15,(0,0),0,.08,raised,segments=8).location=(x+dx,face+.17,z-step/2+.2)
    for z in [bottom,top]:
        box('Setback and floor cornice',(0,face+.13,max(.14,z)),(width+.35,.42,.28),gold if not base else bronze)
    if not base:
        for i in range(bays+1):
            relief(-width/2+i*pitch,face+.36,top-.8,.7)
    orient(set(bpy.context.scene.objects)-before,side*math.pi/2,offset)


def tier(width,depth,bottom,top,bays_x,bays_y,floors,offset=(0,0),base=False):
    box('Solid architectural mass',(offset[0],offset[1],(bottom+top)/2),(width,depth,top-bottom),black if base else green)
    for side in range(4):
        elevation(width if side%2==0 else depth,depth if side%2==0 else width,bottom,top,bays_x if side%2==0 else bays_y,floors,side,offset,base)
    box('Recessed flat terrace',(offset[0],offset[1],top+.04),(width-.3,depth-.3,.08),roof)


# Mapped 39.5 x 43.9 m base. Main measured roof clusters near 86 m.
tier(39.5,43.9,0,13,12,14,3,base=True)
tier(39.5,43.9,13,86.7,12,14,20)
# Photo-visible fifth-floor botanical relief band above the black podium.
for side in range(4):
    before=set(bpy.context.scene.objects)
    width,depth,bays=(39.5,43.9,12) if side%2==0 else (43.9,39.5,14)
    for i in range(bays+1):
        relief(-width/2+i*width/bays,depth/2+.38,18,1.5)
    box('Lower gilded relief ledge',(0,depth/2+.22,16.4),(width,.45,.20),gold)
    orient(set(bpy.context.scene.objects)-before,side*math.pi/2,(0,0))

# Slender east-end tower and successive upper shoulders.
tower=(9.0,0)
tier(19.0,28.0,86.7,103,6,8,4,tower)
tier(16.0,25.0,103,127,5,7,6,tower)
tier(14.0,22.0,127,130,4,6,1,tower)
# Rounded relief medallions and fluted corner pinnacles on all four upper faces.
for side in range(4):
    before=set(bpy.context.scene.objects)
    width,depth=(14,22) if side%2==0 else (22,14)
    face=depth/2
    for i in range(round(width/1.3)):
        x=-width/2+.7+i*1.3
        obj=arch('Crown circular gilded medallion',.30,.43,(0,0),0,.10,gold,start=0,end=math.tau,segments=20)
        obj.location=(x,face+.32,129)
    box('Crown gilded frieze',(0,face+.22,128),(width,.45,.35),gold)
    for x in [-width/2+.35,width/2-.35]:
        box('Shoulder pinnacle',(x,face-.15,130),(.9,1,5),raised)
        box('Pinnacle gilded flute',(x,face+.40,130),(.2,.16,4.5),gold)
    orient(set(bpy.context.scene.objects)-before,side*math.pi/2,tower)
# Stepped gold cap, with recessed panels and a round vent rather than a plain cube.
for width,depth,bottom,top in [(7,9,130,134),(5.4,7,134,151.5),(4.4,5.7,151.5,153.3)]:
    box('Gilded architectural crown',(9,0,(bottom+top)/2),(width,depth,top-bottom),gold)
    for side in range(4):
        before=set(bpy.context.scene.objects)
        w,d=(width,depth) if side%2==0 else (depth,width)
        for x in [-w/2+.25,w/2-.25]:
            box('Crown vertical rib',(x,d/2+.17,(bottom+top)/2),(.25,.35,top-bottom),gold)
        if top-bottom>5:
            for z in [135+1.3*i for i in range(10)]:
                box('Recessed crown coffer',(0,d/2+.01,z),(w-1,.05,.75),bronze)
                box('Coffer lower ledge',(0,d/2+.15,z-.38),(w-1,.3,.10),gold)
            for x in [-w/6,w/6]:
                box('Crown coffer vertical divider',(x,d/2+.15,141.5),(.10,.25,13.5),gold)
            obj=arch('Crown circular vent bezel',.62,.78,(0,0),0,.12,gold,start=0,end=math.tau,segments=32)
            obj.location=(0,d/2+.12,149.3)
            box('Crown vent backing',(0,d/2+.01,149.3),(1.35,.07,1.35),bronze)
            for dx in [-.4,-.2,0,.2,.4]:
                box('Vent grille',(dx,d/2+.13,149.3),(.07,.10,1.05),gold)
        orient(set(bpy.context.scene.objects)-before,side*math.pi/2,tower)
# Michigan Avenue east entrance: projecting portal, bronze grille, readable raised name.
before=set(bpy.context.scene.objects)
for x in [-2.6,2.6]:box('Entrance granite jamb',(x,39.5/2+.32,3.3),(.6,.7,6.6),black)
box('Entrance gilded lintel',(0,39.5/2+.42,6.5),(6,.8,.42),gold)
for x in [-2,-1,0,1,2]:
    box('Bronze entrance grille',(x,39.5/2+.24,3),(.10,.22,5.6),bronze)
for z in [1.1,2.2,3.3,4.4,5.5]:
    box('Bronze grille crossbar',(0,39.5/2+.24,z),(4.6,.22,.09),bronze)
text('Raised historic building name','CARBIDE AND CARBON BUILDING',(0,39.5/2+.50,9),.75,gold,rotate=(math.pi/2,0,math.pi))
orient(set(bpy.context.scene.objects)-before,-math.pi/2,(0,0))
# Authoring envelope assertions catch accidentally rotated baked world coordinates.
bpy.context.view_layer.update()
from mathutils import Vector
points=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects for v in o.bound_box]
assert min(v.z for v in points)>-.01
assert abs(max(v.z for v in points)-153.3)<.01
assert max(abs(v.x) for v in points)<21
assert max(abs(v.y) for v in points)<23
finish('carbide_carbon',OUT)
