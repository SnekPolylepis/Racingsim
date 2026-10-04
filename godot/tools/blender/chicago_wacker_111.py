"""Original 111 South Wacker exterior; Blender +Y north, +Z up."""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
glass=material('Blue grey curtain glass',(.13,.23,.29),roughness=.36)
occupied=material('Night occupied curtain glass',(.13,.23,.29),roughness=.36,glow=.25)
spandrel=material('Dark curtain spandrels',(.065,.11,.15),roughness=.42)
steel=material('Stainless V mullions and round columns',(.47,.50,.51),metallic=.65,roughness=.4)
stone=material('White marble core and pale granite paving',(.62,.58,.49),roughness=.7)
wood=material('Night warm lobby wall panels',(.39,.20,.09),roughness=.7,glow=.15)
roof=material('Mechanical louvers and dark paving joints',(.08,.105,.12),roughness=.85)
clear=material('Clear curved cable lobby glazing',(.35,.44,.47),roughness=.35)
light=material('Night spiral ceiling lights',(.68,.63,.49),roughness=.6,glow=.25)
W,D,LOBBY,TOP,LOW=49.4,56.8,13.8,207.6,201.4
CENTRAL,RETURN=47.4,9.2

def box(name,pos,size,mat):
    obj=baked_box(name,(0,0,0),size,mat)
    obj.location=pos
    return obj

def orient(objects,angle,origin):
    c,s=math.cos(angle),math.sin(angle)
    for obj in objects:
        x,y,z=obj.location
        obj.location=(x*c-y*s+origin[0],x*s+y*c+origin[1],z)
        obj.rotation_euler.z+=angle

def cylinder(name,pos,radius,height,mat,segments=48):
    vertices=[]
    for z in (-height/2,height/2):
        for i in range(segments):
            a=2*math.pi*i/segments
            vertices.append((radius*math.cos(a),radius*math.sin(a),z))
    faces=[tuple(reversed(range(segments))),tuple(range(segments,2*segments))]
    faces += [(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
    obj=mesh(name,vertices,faces,mat)
    obj.location=pos
    return obj

# Mapped plan: full-width central west projection, recessed north/south shoulders.
box('Raised street foundation',(0,0,-4),(W,D,8),stone)
box('Ground paving',(0,0,.10),(W,D,.2),stone)
box('Central projected tower',(0,0,(LOBBY+TOP-.2)/2),(W-.12,CENTRAL-.12,TOP-.2-LOBBY),spandrel)
for y in (-(D+CENTRAL)/4,(D+CENTRAL)/4):
    box('Lower north south shoulder',(RETURN/2,y,(LOBBY+LOW-.2)/2),
        (W-RETURN-.12,(D-CENTRAL)/2-.12,LOW-.2-LOBBY),spandrel)
box('Central roof',(0,0,TOP-.15),(W-.2,CENTRAL-.2,.1),roof)
for y in (-(D+CENTRAL)/4,(D+CENTRAL)/4):
    box('Shoulder roof',(RETURN/2,y,LOW-.15),(W-RETURN-.2,(D-CENTRAL)/2-.2,.1),roof)

def facade(width,origin,angle,top,major=False):
    before=set(bpy.context.scene.objects)
    cols=round(width/1.52)
    pitch=width/cols
    floors=[LOBBY+i*3.4 for i in range(8)]
    office=LOBBY+8*3.4
    floors += [office+i*(203.8-office)/42 for i in range(43)]
    for row,bottom in enumerate(floors):
        fp=3.4 if row<8 else (203.8-office)/42
        height=min(fp,top-.2-bottom)
        if height<.25:continue
        for col in range(cols):
            x=-width/2+(col+.5)*pitch
            mat=occupied if row>=8 and (row*11+col*7)%19 in (0,1,7) else glass
            box('Individual vision pane',(x,.018,bottom+height*.59),(pitch-.065,.035,height*.76),mat)
        box('Floor transom',(0,.05,bottom),(width,.09,.07),steel)
        box('Recessed floor spandrel',(0,.01,bottom+height*.095),(width,.035,height*.19),spandrel)
    for col in range(cols+1):
        x=-width/2+col*pitch
        # Solid triangular extrusion gives the V mullion two distinct sloped faces.
        verts=[(x+dx,y,z) for z in (LOBBY,top) for dx,y in ((.07,.04),(0,.19),(-.07,.04))]
        mesh('Physical stainless V mullion',verts,[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],steel)
    if major:
        for i in range(6):
            x=-width/2+.65+i*(width-1.3)/5
            box('Broad perimeter column cladding',(x,.25,(LOBBY+top)/2),(.65,.45,top-LOBBY),steel)
    orient(set(bpy.context.scene.objects)-before,angle,origin)

facade(CENTRAL,(-W/2,0),math.pi/2,TOP,True)
facade(CENTRAL,(W/2,0),-math.pi/2,TOP,True)
for y in (-(D+CENTRAL)/4,(D+CENTRAL)/4):
    facade((D-CENTRAL)/2,(-W/2+RETURN,y),math.pi/2,LOW)
    facade((D-CENTRAL)/2,(W/2,y),-math.pi/2,LOW)
for y in (-D/2,D/2):
    facade(W-RETURN,(RETURN/2,y),math.pi if y<0 else 0,LOW,True)
for y in (-CENTRAL/2,CENTRAL/2):
    facade(RETURN,(-W/2+RETURN/2,y),math.pi if y<0 else 0,TOP)

# Circular net-wall lobby with genuine modeled interior, separate from tower box.
R=23.7
cylinder('White marble compact lobby core',(4,0,LOBBY/2),5.6,LOBBY,stone,64)
for i in range(48):
    a=2*math.pi*i/48
    obj=box('Marble core vertical fluting',(4+5.62*math.cos(a),5.62*math.sin(a),6.6),(.08,.13,12.3),stone)
    obj.rotation_euler.z=a
box('Warm inner elevator wall',(11,0,6.65),(.4,20,13.3),wood)
for side in (-1,1):
    for offset in (-12.5,12.5):
        cylinder('West east freestanding round column',(side*22.7,offset,LOBBY/2),1.15,LOBBY,steel)
        cylinder('North south freestanding round column',(offset,side*26.1,LOBBY/2),1.15,LOBBY,steel)

# Parking-ramp underside: real annular helix, with radial panel joints and light path.
segments=96
inner=6.4
verts=[]
for i in range(segments+1):
    a=2*math.pi*i/segments
    z=9.1+4.0*i/segments
    for height in (z,z+.45):
        for r in (inner,R):verts.append((r*math.cos(a),r*math.sin(a),height))
faces=[]
for i in range(segments):
    a,b=4*i,4*(i+1)
    faces += [(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)]
faces += [(0,1,3,2),(4*segments,4*segments+2,4*segments+3,4*segments+1)]
mesh('Helical parking ramp soffit',verts,faces,stone)
for i in range(48):
    a=2*math.pi*i/48
    z=9.1+4*i/48
    obj=box('Radial soffit panel seam',((inner+R)/2*math.cos(a),(inner+R)/2*math.sin(a),z-.022),
        (R-inner,.028,.028),roof)
    obj.rotation_euler.z=a
for i in range(96):
    a,b=2*math.pi*i/96,2*math.pi*(i+1)/96
    r=8.8
    mesh('Helical luminous ceiling rim',[(r*math.cos(a),r*math.sin(a),9.055+4*i/96),
        ((r+.12)*math.cos(a),(r+.12)*math.sin(a),9.055+4*i/96),
        ((r+.12)*math.cos(b),(r+.12)*math.sin(b),9.055+4*(i+1)/96),
        (r*math.cos(b),r*math.sin(b),9.055+4*(i+1)/96)],[(3,2,1,0)],light)

# Curved clear panes, thin cables and round point fittings. No photographic wall.
for i in range(64):
    a,b=2*math.pi*i/64,2*math.pi*(i+1)/64
    x,y=R*math.cos(a),R*math.sin(a)
    cylinder('Lobby vertical tension cable',(x,y,6.8),.018,13.2,steel,8)
    for row in range(4):
        z=.2+row*3.35
        mesh('Curved lobby glass panel',[(R*math.cos(a),R*math.sin(a),z),(R*math.cos(b),R*math.sin(b),z),
            (R*math.cos(b),R*math.sin(b),z+3.32),(R*math.cos(a),R*math.sin(a),z+3.32)],[(0,1,2,3)],clear)
        if row:
            fit=cylinder('Round cable point fitting',(0,0,0),.085,.08,steel,12)
            fit.rotation_euler=(math.pi/2,0,a+math.pi/2)
            fit.location=(x,y,z)
    # Radial granite paving joints extend the circular lobby pattern outside glass.
    if i%2==0:
        r0,r1=6.0,24.5
        obj=box('Radial paving joint',((r0+r1)/2*math.cos(a),(r0+r1)/2*math.sin(a),.205),
            (r1-r0,.07,.01),roof)
        obj.rotation_euler.z=a
for side in (-1,1):
    before=set(bpy.context.scene.objects)
    for x in (-2.6,0,2.6):
        for dx in (-1.1,1.1):box('Entry jamb',(x+dx,R-.18,1.65),(.10,.15,3.3),steel)
        box('Entry head',(x,R-.18,3.3),(2.3,.16,.14),steel)
        box('Door pane',(x,R-.26,1.65),(2.05,.06,3.1),clear)
        box('Door pull',(x+.7,R-.32,1.5),(.06,.1,.8),steel)
    text('Raised entry address','111 SOUTH WACKER',(0,R-.3,3.7),.45,steel,rotate=(math.pi/2,0,math.pi))
    orient(set(bpy.context.scene.objects)-before,side*math.pi/2,(0,0))
box('Rooftop mechanical enclosure',(8,0,TOP-1.5),(16,18,2.3),roof)
finish('wacker_111',OUT)
