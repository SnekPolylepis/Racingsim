"""Original Blender exterior for 35 East Wacker, on its mapped Chicago footprint.
Reference photographs: City of Chicago and Skyscraper Center; see SOURCES.md.
Blender +Y is north, +Z up; glTF converts these to Godot -Z and +Y.
"""
import bpy
import math
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box as baked_box, line, arch, text, finish

OUT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Cream terra cotta', (.51, .46, .36), roughness=.79)
trim = material('Raised classical ornament', (.65, .59, .46), roughness=.72)
base = material('Street limestone', (.37, .35, .29), roughness=.8)
bronze = material('Bronze window sash', (.13, .14, .12), metallic=.5)
glass = material('Night recessed office glazing', (.12, .17, .18), metallic=.3, roughness=.23, glow=.3)
day_glass = material('Unoccupied recessed office glazing', (.12, .17, .18), metallic=.3, roughness=.23)
roof = material('Terrace roofing', (.10, .11, .10), roughness=.9)
dome_mat = material('Carved terra cotta dome', (.43, .39, .30), roughness=.7)
clock_face = material('Night clock ivory', (.64, .60, .47), roughness=.7, glow=.5)
clock_metal = material('Patinated clock bronze', (.18, .25, .20), metallic=.55, roughness=.48)


def box(name, pos, size, mat):
    obj = baked_box(name, (0, 0, 0), size, mat)
    obj.location = pos
    return obj


def cylinder(name, pos, radius, height, mat, sides=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=height, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def ring(name, pos, inner, outer, thickness, mat, sides=48):
    x, y, z = pos
    vertices = []
    for h in [z-thickness/2, z+thickness/2]:
        for r in [inner, outer]:
            vertices += [(x+r*math.cos(i*math.tau/sides), y+r*math.sin(i*math.tau/sides), h) for i in range(sides)]
    faces = []
    for i in range(sides):
        j = (i+1)%sides
        faces += [(i,j,j+sides,i+sides), (i+2*sides,i+3*sides,j+3*sides,j+2*sides),
                  (i,i+2*sides,j+2*sides,j), (i+sides,j+sides,j+3*sides,i+3*sides)]
    return mesh(name, vertices, faces, mat)


def cornice(width, depth, z, tall=.7):
    for h, proud, thick in [(z-.35,.35,.3), (z,.65,tall), (z+.45,.85,.22)]:
        box('Projecting cornice', (0,0,h), (width+proud,depth+proud,thick), trim)


def elevation(width, depth, bottom, top, bays, floors, side, paired=True):
    previous = set(bpy.context.scene.objects)
    pitch = width/bays
    step = (top-bottom)/floors
    face = depth/2
    for i in range(bays+1):
        x = -width/2+i*pitch
        box('Continuous raised pilaster', (x,face+.15,(bottom+top)/2), (.55,.35,top-bottom), trim)
        box('Pilaster fluting', (x,face+.35,(bottom+top)/2), (.10,.07,top-bottom-.4), stone)
        box('Classical pier capital', (x,face+.22,top-.2), (.85,.5,.45), trim)
    for row in range(floors):
        z = bottom+(row+.5)*step
        for i in range(bays):
            x = -width/2+(i+.5)*pitch
            for offset in ([-pitch*.20,pitch*.20] if paired else [0]):
                pane = pitch*.34 if paired else pitch-.95
                px = x+offset
                box('Recessed glazed office window', (px,face+.02,z+.10), (pane,.08,step-.7), glass if (row*5+i*3+side)%7<3 else day_glass)
                box('Bronze sash', (px,face+.095,z+.1), (.065,.14,step-.7), bronze)
                box('Window transom', (px,face+.095,z+.3), (pane,.14,.08), bronze)
                box('Raised sill', (px,face+.16,z-step/2+.25), (pane+.16,.35,.13), trim)
                box('Recessed spandrel', (px,face+.07,z-step/2+.50), (pane,.13,.35), stone)
                if row == floors-1:
                    arch('Round headed upper window', pane/2, pane/2+.15, (px,z+(step-.7)/2), face+.13,.2,trim,segments=16)
    angle = side*math.pi/2
    for obj in set(bpy.context.scene.objects)-previous:
        if obj.type == 'CURVE':
            obj.rotation_euler.z = angle
        else:
            x,y,z = obj.location
            obj.location = (x*math.cos(angle)-y*math.sin(angle), x*math.sin(angle)+y*math.cos(angle), z)
            obj.rotation_euler.z += angle


def dome(name, cx, cy, bottom, radius, height):
    sides, rows = 64, 16
    vertices = []
    for j in range(rows+1):
        phi = (math.pi/2-.035)*j/rows
        vertices += [(cx+radius*math.cos(phi)*math.cos(i*math.tau/sides),
                      cy+radius*math.cos(phi)*math.sin(i*math.tau/sides),
                      bottom+height*math.sin(phi)) for i in range(sides)]
    faces = []
    for j in range(rows):
        for i in range(sides):
            a, b = j*sides+i, j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(rows*sides+i for i in range(sides)))
    mesh(name,vertices,faces,dome_mat)
    for i in range(16):
        theta = i*math.tau/16
        line('Raised dome rib', [(cx+(radius+.06)*math.cos(math.pi*j/32)*math.cos(theta),
             cy+(radius+.06)*math.cos(math.pi*j/32)*math.sin(theta),
             bottom+height*math.sin(math.pi*j/32)) for j in range(17)], .09, trim)
    # Actual raised rectangular coffers, rather than a texture over the cap.
    for phi in [.24,.48,.72,.96]:
        for i in range(16):
            theta = (i+.5)*math.tau/16
            points=[]
            for p,t in [(phi-.08,theta-.09),(phi-.08,theta+.09),(phi+.08,theta+.09),(phi+.08,theta-.09),(phi-.08,theta-.09)]:
                points.append((cx+(radius+.075)*math.cos(p)*math.cos(t), cy+(radius+.075)*math.cos(p)*math.sin(t), bottom+height*math.sin(p)))
            line('Dome coffer border',points,.055,trim)
    ring('Dome spring cornice',(cx,cy,bottom),radius-.25,radius+.25,.4,trim)


def turret(cx, cy):
    z = 88.5
    box('Corner turret square pedestal',(cx,cy,z+1.9),(6.6,6.6,3.8),stone)
    cylinder('Turret plinth',(cx,cy,z+4.1),3.1,.6,trim)
    # Open colonnade: no solid cylinder through the gaps.
    for i in range(8):
        theta = i*math.tau/8
        x,y = cx+2.5*math.cos(theta),cy+2.5*math.sin(theta)
        cylinder('Turret column',(x,y,z+8.3),.27,7.5,trim,16)
        cylinder('Turret capital',(x,y,z+12.1),.43,.55,trim,16)
        cylinder('Turret column base',(x,y,z+4.65),.41,.4,trim,16)
    ring('Turret entablature',(cx,cy,z+12.8),2.15,3.2,1.1,trim)
    dome('Corner turret dome',cx,cy,z+13.5,2.9,2.6)
    cylinder('Turret finial',(cx,cy,z+16.5),.27,.8,trim,16)


# Main footprint approximately 50.4 by 44.3 m, mapped roof plateau at 88.5 m.
box('Main terra cotta office block',(0,0,44.25),(50.4,44.3,88.5),stone)
box('Street limestone base',(0,0,5.4),(50.5,44.4,10.8),base)
for side in range(4):
    width,depth = (50.4,44.3) if side%2==0 else (44.3,50.4)
    elevation(width,depth,12,71,9 if side%2==0 else 8,18,side)
    elevation(width,depth,74,86,9 if side%2==0 else 8,4,side)
    elevation(width,depth,1,10,9 if side%2==0 else 8,2,side,paired=False)
for z in [10.8,12,72,87.5]: cornice(50.4,44.3,z)
box('Main terrace',(0,0,88.6),(49.5,43.4,.22),roof)
for x in [-20.8,20.8]:
    for y in [-17.7,17.7]: turret(x,y)
# Narrow upper tower, articulated setbacks and tall lantern above its roof.
box('Tower shoulder',(0,0,92),(24,24,7),stone)
box('Upper shaft',(0,0,112.5),(21,21,35),stone)
box('Lantern pedestal',(0,0,133),(19,19,6),stone)
for side in range(4):
    elevation(24,24,89,95,5,2,side,paired=False)
    elevation(21,21,96,129,7,10,side,paired=False)
    elevation(19,19,131,135,5,1,side,paired=False)
for z,w in [(95,24),(130,21),(135.8,19)]: cornice(w,w,z)
# Rectangular stone corner buttresses support the circular glazed lantern.
cylinder('Lantern recessed drum',(0,0,143.5),7.6,14.4,bronze,64)
for i in range(16):
    theta = i*math.tau/16
    x,y = 7.65*math.cos(theta),7.65*math.sin(theta)
    pane=box('Tall lantern glazing',(x,y,143.1),(2.5,.12,10.9),glass)
    pane.rotation_euler.z=theta-math.pi/2
    cylinder('Doric lantern column',(8*math.cos(theta+math.pi/16),8*math.sin(theta+math.pi/16),143.4),.24,12.6,trim,16)
    previous=set(bpy.context.scene.objects)
    arch('Lantern arch',1.25,1.43,(0,148.55),.1,.3,trim,segments=20)
    for obj in set(bpy.context.scene.objects)-previous:
        obj.location=(x,y,0)
        obj.rotation_euler.z=theta-math.pi/2
for x in [-7.0,7.0]:
    for y in [-7.0,7.0]:
        box('Lantern corner buttress',(x,y,143.4),(1.15,1.15,14.4),stone)
        box('Buttress capital',(x,y,150.4),(1.65,1.65,.7),trim)
        cylinder('Crown urn',(x,y,151.6),.35,1.6,trim,16)
        cylinder('Urn finial',(x,y,152.7),.17,.6,trim,16)
ring('Lantern upper entablature',(0,0,150.5),7.2,8.4,1.1,trim)
dome('Central ribbed coffered dome',0,0,151.2,7.7,7.5)
cylinder('Dome apex vent',(0,0,159.0),.85,.8,trim,24)
# Entrance recess, bronze doors and individual geometry for its carved inscription.
box('North entrance recess',(0,22.22,4.4),(6.4,.12,8.2),bronze)
for x in [-1.6,0,1.6]:
    box('Entry bronze glass door',(x,22.32,2.4),(1.4,.08,4.4),glass)
    box('Door stile',(x,22.4,2.4),(.065,.13,4.4),bronze)
arch('Entrance archivolt',3.2,3.6,(0,7),22.3,.4,trim,segments=32)
text('Carved address','35 EAST WACKER DRIVE',(0,22.45,10),.62,bronze,rotate=(math.pi/2,0,math.pi))
# Northeast projecting corner clock, readable circular dial and dimensional case.
clock_x,clock_y,clock_z=24.2,23.4,11.8
obj=cylinder('Father Time clock ivory dial',(clock_x,clock_y,clock_z),1.25,.12,clock_face,64)
obj.rotation_euler.x=math.pi/2
obj=ring('Clock circular bronze bezel',(0,0,0),1.25,1.46,.3,clock_metal)
obj.rotation_euler.x=math.pi/2
obj.location=(clock_x,clock_y,clock_z)
for i in range(12):
    a=i*math.tau/12
    obj=box('Clock raised hour marker',(clock_x+.99*math.sin(a),clock_y+.10,clock_z+.99*math.cos(a)),(.09,.1,.2),bronze)
    obj.rotation_euler.y=a
line('Clock minute hand',[(clock_x,clock_y+.13,clock_z),(clock_x+.79,clock_y+.13,clock_z+.43)],.045,bronze)
line('Clock hour hand',[(clock_x,clock_y+.14,clock_z),(clock_x-.49,clock_y+.14,clock_z+.27)],.065,bronze)
box('Clock mounting bracket',(24.2,22.6,10.6),(.3,1.7,.3),clock_metal)
line('Clock scroll bracket',[(24.2,22.25,9.8),(24.2,23.1,9.8),(24.2,23.4,10.4)],.11,clock_metal)
# Stylized Father Time figure above the clock; a sculptural silhouette, not a photographic cutout.
cylinder('Clock sculpture robed body',(clock_x,clock_y,14.0),.22,1.3,clock_metal,16)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.23,location=(clock_x,clock_y,14.85))
bpy.context.object.data.materials.append(clock_metal)
line('Figure scythe',[(clock_x+.3,clock_y,13.7),(clock_x+.4,clock_y,15.35),(clock_x-.35,clock_y,15.6)],.04,clock_metal)
# Mesh Arabic dial numerals and a simplified winged Father Time silhouette.
for number in range(1,13):
    a=number*math.tau/12
    text('Clock Arabic numeral',str(number),(clock_x-.99*math.sin(a),clock_y+.16,clock_z+.99*math.cos(a)),.27,bronze,rotate=(math.pi/2,0,math.pi),depth=.012)
box('Clock TIME plaque',(clock_x,clock_y,10.1),(2.3,.32,.5),clock_metal)
text('Clock TIME lettering','TIME',(clock_x,clock_y+.18,10.1),.28,trim,rotate=(math.pi/2,0,math.pi),depth=.012)
for side in [-1,1]:
    wing=[(clock_x+side*x,clock_y-.12,z) for x,z in [(.15,14.7),(.8,15.2),(.65,14.1),(.15,13.4)]]
    wing += [(x,y-.10,z) for x,y,z in wing]
    faces=[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
    mesh('Father Time wing',wing,[tuple(reversed(face)) for face in faces] if side<0 else faces,clock_metal)
line('Father Time arm',[(clock_x,clock_y,14.3),(clock_x-.45,clock_y+.05,14.4),(clock_x-.7,clock_y+.05,14.2)],.07,clock_metal)
# Author assertions before joining/export: no flying rotated features or baked translations.
bpy.context.view_layer.update()
from mathutils import Vector
points=[obj.matrix_world@Vector(v) for obj in bpy.context.scene.objects for v in obj.bound_box]
assert min(v.z for v in points)>-.01
assert max(v.z for v in points)<159.5
assert max(abs(v.x) for v in points)<26
assert max(abs(v.y) for v in points)<24
finish('jewelers_building',OUT)
