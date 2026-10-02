"""Blender-authored Tribune Tower exterior; original geometry, no photo panels.
References: Chicago Architecture Center Tribune Tower; SCB conversion/crown photos.
Run: blender -b --python tools/blender/chicago_tribune_tower.py -- <output dir>
Dimensions are a stylized interpretation inside the existing landmark envelope.
"""
import bpy
import math
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box, line, arch, finish

OUT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Indiana limestone', (.38, .34, .27), roughness=.8)
trim = material('Raised limestone tracery', (.49, .44, .36), roughness=.73)
shadow = material('Recessed bronze spandrels', (.15, .17, .15), metallic=.3)
glass = material('Night warm windows', (.16, .19, .18), metallic=.3, roughness=.24, glow=.35)
roof = material('Dark terrace roofing', (.13, .14, .13), roughness=.9)


def pinnacle(x, y, z, width=1.1, height=3):
    box('Pinnacle base', (x, y, z+.35), (width, width, .7), trim)
    a = width / 2
    mesh('Four sided stone finial', [(x-a,y-a,z+.7),(x+a,y-a,z+.7),
         (x+a,y+a,z+.7),(x-a,y+a,z+.7),(x,y,z+height)],
         [(0,3,2,1),(0,1,4),(1,2,4),(2,3,4),(3,0,4)], trim)


def elevation(width, depth, bottom, top, bays, floors, side):
    # Author a front elevation, then rotate it onto each actual tower face.
    previous = set(bpy.context.scene.objects)
    pitch = width / bays
    step = (top-bottom) / floors
    for i in range(bays+1):
        x = -width/2+i*pitch
        box('Continuous fluted vertical pier', (x,-depth/2-.18,(bottom+top)/2),
            (.9,.6,top-bottom), trim)
        line('Pier moulding', [(x-.16,-depth/2-.51,bottom),(x-.16,-depth/2-.51,top)], .06, stone)
        line('Pier moulding', [(x+.16,-depth/2-.51,bottom),(x+.16,-depth/2-.51,top)], .06, stone)
    for row in range(floors):
        z = bottom+(row+.5)*step
        for i in range(bays):
            x = -width/2+(i+.5)*pitch
            pane = pitch-1.25
            box('Inset glazed bay', (x,-depth/2-.025,z+.15), (pane,.08,step-.85), glass)
            box('Spandrel', (x,-depth/2-.11,z-step/2+.27), (pane,.22,.54), shadow)
            box('Window sill', (x,-depth/2-.26,z-step/2+.58), (pane,.44,.13), trim)
            box('Window central mullion', (x,-depth/2-.12,z+.15), (.065,.20,step-.85), shadow)
            box('Window transom', (x,-depth/2-.12,z+.25), (pane,.20,.07), shadow)
    angle = side*math.pi/2
    for obj in set(bpy.context.scene.objects)-previous:
        x,y,z = obj.location
        obj.location = (x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle),z)
        obj.rotation_euler.z += angle
        # Curves have coordinates baked into their data, rather than object.location.
        if obj.type == 'CURVE':
            obj.rotation_euler.z = angle


# Broad lower office block with a narrower shaft; retain the mapped landmark site.
box('Lower limestone office block', (0,0,23), (40,48,46), stone)
box('Main shaft limestone core', (0,0,66.5), (28,32,87), stone)
box('Setback terrace', (0,0,46.2), (40.8,48.8,.45), trim)
box('Setback dark terrace', (0,0,46.48), (39.8,47.8,.12), roof)
for side in range(4):
    elevation(40 if side%2==0 else 48,48 if side%2==0 else 40,8,46,10 if side%2==0 else 12,10,side)
    elevation(28 if side%2==0 else 32,32 if side%2==0 else 28,46,108,8 if side%2==0 else 9,17,side)
    elevation(28 if side%2==0 else 32,32 if side%2==0 else 28,108,110,8 if side%2==0 else 9,1,side)

# Street entrance: three pointed arches, real opening outlines and recessed doors.
for x in [-9,0,9]:
    box('Entrance recessed bronze doors',(x,-24.08,3.2),(4.4,.12,5.8),shadow)
    for dx in [-2.45,2.45]:
        box('Entrance jamb',(x+dx,-24.4,3),( .45,.8,6),trim)
    line('Pointed entrance archivolt',[(x-2.45,-24.42,5.8),(x-2,-24.42,7),
         (x,-24.42,8.6),(x+2,-24.42,7),(x+2.45,-24.42,5.8)],.22,trim)
    for dx in [-1.1,0,1.1]:
        box('Door mullion',(x+dx,-24.2,3.2),(.10,.2,5.8),trim)

# Eight outer shafts and an octagonal lantern: open air between the buttresses.
points = [(18*math.cos(i*math.pi/4),20*math.sin(i*math.pi/4)) for i in range(8)]
inner = [(10*math.cos(i*math.pi/4),12*math.sin(i*math.pi/4)) for i in range(8)]
vertices = [(x,y,z) for z in [108,137] for x,y in inner]
faces = [(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)] + [tuple(range(8,16))]
mesh('Octagonal crown lantern',vertices,faces,stone)
for i,(x,y) in enumerate(points):
    ix,iy = inner[i]
    box('Outer buttress shaft',(x,y,117), (1.5,1.5,24),trim)
    pinnacle(x,y,129,1.5,4)
    # Sloping tops and arched undersides leave the characteristic open crown.
    radial = math.atan2(y-iy,x-ix)
    span = math.dist((x,y),(ix,iy))
    previous = set(bpy.context.scene.objects)
    arch('Flying buttress arch',span*.48,span*.48+.6,(span/2,123),-.55,1.1,
         trim,start=0,end=math.pi,segments=16)
    line('Buttress sloping coping',[(0,0,130),(span,0,128)],.38,trim)
    for obj in set(bpy.context.scene.objects)-previous:
        obj.location = (ix,iy,0)
        obj.rotation_euler.z = radial
    pinnacle(ix,iy,137,1,4)
    # Crown openings, tracery and parapets are individually modeled on each face.
    j = (i+1)%8
    a,b = inner[i],inner[j]
    mid = ((a[0]+b[0])/2,(a[1]+b[1])/2)
    angle = math.atan2(b[1]-a[1],b[0]-a[0])
    length = math.dist(a,b)
    outward = (math.sin(angle),-math.cos(angle))
    obj = box('Lantern inset window',(mid[0]+outward[0]*.08,mid[1]+outward[1]*.08,130),
              (length-1,.12,9),glass)
    obj.rotation_euler.z = angle
    obj = box('Tall lancet crown window',(mid[0]+outward[0]*.08,mid[1]+outward[1]*.08,116.5),
              (length-1.6,.12,14),glass)
    obj.rotation_euler.z = angle
    previous = set(bpy.context.scene.objects)
    half = (length-1.6)/2
    line('Pointed crown archivolt',[(-half,-.22,122.5),(-half*.65,-.22,124),
         (0,-.22,125.4),(half*.65,-.22,124),(half,-.22,122.5)],.18,trim)
    arch('Crown quatrefoil roundel',.65,.83,(0,135),-.27,.3,trim,segments=20,end=math.tau)
    for obj in set(bpy.context.scene.objects)-previous:
        obj.location = (*mid,0)
        obj.rotation_euler.z = angle
    for z in [108,124,133,136.6]:
        obj = box('Crown cornice',(mid[0]+outward[0]*.2,mid[1]+outward[1]*.2,z),(length,.6,.45),trim)
        obj.rotation_euler.z = angle
    for u in [-.3,0,.3]:
        px,py = mid[0]+(b[0]-a[0])*u,mid[1]+(b[1]-a[1])*u
        line('Lantern narrow tracery',[(px+outward[0]*.18,py+outward[1]*.18,109),
             (px+outward[0]*.18,py+outward[1]*.18,136)],.09,trim)
    # Open stone balcony lattice between the shafts.
    for j in range(7):
        t = (j+.5)/7
        px,py = x+(points[(i+1)%8][0]-x)*t,y+(points[(i+1)%8][1]-y)*t
        box('Open parapet baluster',(px,py,108.8),(.16,.16,1.5),trim)
    line('Open crown parapet',[(x,y,109.6),(*points[(i+1)%8],109.6)],.16,trim)
finish('tribune_tower',OUT)
