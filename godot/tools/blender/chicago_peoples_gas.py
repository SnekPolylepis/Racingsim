"""Original Peoples Gas exterior, authored from facade and historic plan references.
Blender +Y north, +Z up. Dimensions fitted to mapped r15953438.
"""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, arch, line, text, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Pale weathered terracotta masonry', (.61,.59,.53), roughness=.86)
trim = material('Carved limestone mouldings', (.70,.67,.59), roughness=.85)
granite = material('Smooth grey granite Ionic base', (.38,.37,.34), roughness=.78)
brick = material('White enameled light court brick', (.66,.66,.62), roughness=.8)
dark = material('Deep opaque window reveals', (.055,.051,.042), roughness=.85)
glass = material('Individual recessed double hung panes', (.16,.20,.21), roughness=.5)
night = material('Night occupied office panes', (.22,.19,.13), roughness=.5, glow=.3)
bronze = material('Bronze entrance and sash', (.22,.17,.095), metallic=.6, roughness=.54)
roof = material('Dark roof and courtyard floor', (.17,.18,.17), roughness=.95)
clear = material('Clear bronze entrance glazing', (.25,.30,.29), roughness=.5)
clear.diffuse_color = (.25,.30,.29,.18)
W,D,H = 51.0,60.0,92.0
MICHIGAN_ENTRIES = [(D/2-D/13*1.5,3.65),(D/2-D/13*2.5,3.65),(0,3.0)]
boxes = {}

def box(name, p, size, mat):
    # Batch masonry/window boxes before creating Blender objects; thousands of
    # independent objects make scene updates dominate authoring time.
    vertices,faces = boxes.setdefault(mat,([],[]))
    start=len(vertices)
    x,y,z=p
    a,b,c=(v/2 for v in size)
    vertices.extend((x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in
                    [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)])
    faces.extend(tuple(start+i for i in face) for face in
                 [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

def flush():
    for mat,(vertices,faces) in boxes.items():mesh(mat.name+' authored boxes',vertices,faces,mat)
    boxes.clear()

def orient(objects, p, angle):
    existing=set(bpy.context.scene.objects)
    flush()
    objects |= set(bpy.context.scene.objects)-existing
    c,s = math.cos(angle),math.sin(angle)
    for obj in objects:
        # Boxes carry baked vertices; rotate them with the same object transform.
        x,y,z = obj.location
        obj.location = (p[0]+x*c-y*s,p[1]+x*s+y*c,z)
        obj.rotation_euler.z += angle

def column(name, x,y,lo,hi,r,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r, depth=hi-lo, location=(x,y,(lo+hi)/2))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj

# Four wings leave a genuine open central court, enlarged above floor 16.
# ponytail: photo/plan-derived proportions, replace with surveyed sections if supplied.
for lo,hi,cw,cd in [(0,14.7,0,0),(14.7,72.9,18.288,21.336),(72.9,91.4,29.87,23.165)]:
    if not cw:
        box('Deep recessed street backing', (0,0,5.25), (W-3.4,D-3.4,10.5), dark)
        box('Solid upper base floors', (0,0,12.6), (W-.9,D-.9,4.2), dark)
        continue
    box('West court wing', (-(W+cw)/4,0,(lo+hi)/2), ((W-cw)/2-.45,D-.9,hi-lo), brick)
    box('East court wing', ((W+cw)/4,0,(lo+hi)/2), ((W-cw)/2-.45,D-.9,hi-lo), brick)
    for side in [-1,1]:
        if side < 0:
            box('South court wing', (0,-(D+cd)/4,(lo+hi)/2), (cw,(D-cd)/2-.45,hi-lo), brick)
        else:
            # Smaller shared north light court is open to the party-wall edge.
            for edge in [-1,1]:
                box('North wing beside shared court',(edge*(cw+14)/4,(D+cd)/4,(lo+hi)/2),((cw-14)/2,(D-cd)/2-.45,hi-lo),brick)
            box('Inset north shared court wing',(0,(cd/2+D/2-4.5)/2,(lo+hi)/2),(14,(D-cd)/2-4.5,hi-lo),brick)
    # Individual windows inset into the court wall, not a filled roof rectangle.
    for width,p,a in [(cw,(0,cd/2),0),(cw,(0,-cd/2),math.pi),
                      (cd,(cw/2,0),-math.pi/2),(cd,(-cw/2,0),math.pi/2)]:
        flush()
        before = set(bpy.context.scene.objects)
        count = int(width/3)
        rows = 14 if lo < 20 else 4
        for row in range(rows):
            z = lo+(row+.5)*(hi-lo)/rows
            for n in range(count):
                x = -width/2+(n+.5)*width/count
                box('Court recessed glazing', (x,.13,z), (1.35,.04,2.5), glass)
                for side in [-1,1]:
                    box('Court window jamb', (x+side*.75,-.08,z), (.13,.22,2.65), trim)
        orient(set(bpy.context.scene.objects)-before,p,a)
box('Below street foundation', (0,0,-3.9), (W,D,8.2), granite)
box('Court lower flat roof', (0,0,14.68), (18.288,21.336,.18), roof)
for side in [-1,1]:
    box('Main roof west east wing', (side*(W+29.87)/4,0,91.4), ((W-29.87)/2,D,.22), roof)
    if side < 0:
        box('Main roof south wing', (0,-(D+23.165)/4,91.4), (29.87,(D-23.165)/2,.22), roof)
    else:
        for edge in [-1,1]:
            box('Roof beside north notch',(edge*(29.87+14)/4,(D+23.165)/4,91.4),((29.87-14)/2,(D-23.165)/2,.22),roof)
        box('Roof behind north notch',(0,(23.165/2+D/2-4.5)/2,91.4),(14,(D-23.165)/2-4.5,.22),roof)

def facade(width,p,angle,bays,public=True):
    flush()
    before = set(bpy.context.scene.objects)
    pitch = width/bays
    # Solid wall piers/spandrels surround actual separate recessed panes.
    for floor in range(3,21):
        lo = 14.7+(floor-3)*4.157
        hi = lo+4.157
        for n in range(bays):
            x = -width/2+(n+.5)*pitch
            single = n in [0,bays-1]
            pane_w = pitch*.28 if not single else pitch*.25
            xs = [x] if single else [x-pitch*.19,x+pitch*.19]
            for at in xs:
                box('Recessed double hung office glass',(at,.23,lo+2.10),(pane_w,.045,2.63),night if (n+floor)%8==0 else glass)
                for edge in [-1,1]:
                    box('Bronze window side sash',(at+edge*(pane_w/2+.028),.12,lo+2.10),(.07,.12,2.76),bronze)
                for z in [lo+.78,lo+2.10,lo+3.42]:
                    box('Double hung horizontal sash',(at,.12,z),(pane_w+.1,.12,.07),bronze)
                box('Projecting limestone sill',(at,-.12,lo+.73),(pane_w+.25,.43,.14),trim)
            # Broad solid centre pier is characteristic; corner bay has a single opening.
            if single:
                for edge in [-1,1]:
                    box('Smooth corner masonry pier',(x+edge*pitch*.32,.02,(lo+hi)/2),(pitch*.35,.52,hi-lo),stone)
            else:
                box('Broad paired window centre pier',(x,.02,(lo+hi)/2),(pitch*.10,.52,hi-lo),stone)
                for edge in [-1,1]:
                    box('Outer bay masonry',(x+edge*pitch*.43,.02,(lo+hi)/2),(pitch*.16,.52,hi-lo),stone)
            box('Carved masonry spandrel',(x,.015,lo+.26),(pitch,.49,.98),stone)
            if public:
                for z in [lo+.15,lo+.50]:
                    box('Horizontal stone rustication',(x,-.27,z),(pitch-.03,.08,.045),trim)
                if floor in [3,16,20]:
                    box('Raised rectangular spandrel panel',(x,-.29,lo+.27),(pitch*.38,.12,.44),trim)
        box('Floor masonry lintel',(0,.015,hi-.28),(width,.49,.56),stone)
    # Street colonnade with open glazing behind round Ionic granite shafts.
    for n in range(bays):
        x = -width/2+(n+.5)*pitch
        if public and n in [0,bays-1]:
            # Street corner portals: a real oval aperture above a stone doorway.
            for side in [-1,1]:
                box('Corner portal stone jamb',(x+side*(pitch+1.8)/4,.12,2.65),((pitch-1.8)/2,.76,5.3),granite)
            box('Recessed corner portal glass',(x,.32,2.2),(1.8,.04,4.3),clear)
            for z in [.18,4.42,5.18]:box('Corner portal carved lintel',(x,-.22,z),(2.18,.46,.22),trim)
            verts=[]
            for j in range(40):
                a=j*2*math.pi/40
                c,s=math.cos(a),math.sin(a)
                edge=min(pitch/2/max(abs(c),.00001),2.65/max(abs(s),.00001))
                for y in [-.26,.52]:
                    verts.extend([(x+.64*c,y,7.85+1.24*s),(x+edge*c,y,7.85+edge*s)])
            faces=[]
            for j in range(40):
                a,b=j*4,((j+1)%40)*4
                faces.extend([(a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a,a+2,b+2,b),(a+1,b+1,b+3,a+3)])
            mesh('Granite portal panel with actual oval aperture',verts,faces,granite)
            verts=[(x,.24,7.85)]+[(x+.63*math.cos(j*2*math.pi/40),.24,7.85+1.23*math.sin(j*2*math.pi/40)) for j in range(41)]
            mesh('Recessed oval corner pane',verts,[tuple(range(len(verts)))],glass)
            line_points=[(x+.75*math.cos(j*2*math.pi/40),-.40,7.85+1.36*math.sin(j*2*math.pi/40)) for j in range(41)]
            line('Carved oval portal surround',line_points,.10,trim)
        else:
            spans=[(x-pitch/2+.25,x+pitch/2-.25)]
            entries=MICHIGAN_ENTRIES if p[0] == W/2 else []
            for entry,entry_width in entries:
                trimmed=[]
                for left,right in spans:
                    if left < entry-entry_width/2:trimmed.append((left,min(right,entry-entry_width/2)))
                    if right > entry+entry_width/2:trimmed.append((max(left,entry+entry_width/2),right))
                spans=trimmed
            for left,right in spans:
                if right>left:box('Recessed street glazing',((left+right)/2,.50,3.0),(right-left,.055,5.6),glass)
            box('Upper storefront glazing',(x,.50,7.4),(pitch-.5,.055,3.1),glass)
            for z in [1.1,3.9,7.5,9.0]:
                if z>6 or not entries:
                    box('Bronze storefront transom',(x,.40,z),(pitch-.4,.16,.1),bronze)
                else:
                    for left,right in spans:
                        if right>left:box('Bronze storefront transom',((left+right)/2,.40,z),(right-left,.16,.1),bronze)
        if public:
            # Restoration photo: rectangular base windows alternate with
            # circular carved medallions on the piers, not an all-oculus row.
            pane_w=pitch*.26
            box('Rectangular base window',(x,.23,12.8),(pane_w,.04,2.55),glass)
            for side in [-1,1]:
                box('Solid base window side pier',(x+side*(pitch+pane_w)/4,.20,12.8),((pitch-pane_w)/2,.6,4.0),stone)
            for z in [11.08,14.52]:
                box('Solid base window lintel sill',(x,.20,z),(pane_w,.6,.57),stone)
            box('Base window double hung crossbar',(x,.10,12.8),(pane_w,.12,.08),bronze)
            if n<bays-1:
                at=x+pitch/2
                arch('Carved circular base medallion',.22,.37,(at,12.8),-.40,.28,trim,end=2*math.pi,segments=20)
                # Original stylized relief, not an exact historic sculptural replica.
                for dx,dz,sx,sy,sz in [(0,0,.23,.12,.28),(-.11,.12,.065,.08,.075),(.11,.12,.065,.08,.075),(0,-.06,.14,.14,.12)]:
                    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(at+dx,-.38,12.8+dz))
                    relief=bpy.context.object;relief.name='Physical carved medallion relief';relief.scale=(sx,sy,sz);relief.data.materials.append(trim)
        else:
            box('Plain rear second floor stone panel',(x,.0,12.8),(pitch,.65,4.0),stone)
    for n in range(bays+1):
        x=-width/2+n*pitch
        if public and 0<n<bays:
            column('Round smooth granite Ionic shaft',x,-.10,.65,9.6,.38,granite)
            for z,r,height in [(.32,.57,.30),(.65,.46,.20),(9.50,.46,.22),(9.8,.63,.3)]:
                column('Ionic base capital rings',x,-.10,z-height/2,z+height/2,r,trim)
            box('Ionic capital abacus',(x,-.10,10.1),(1.34,1.0,.24),trim)
            for side in [-1,1]:
                arch('Ionic volute spiral ring',.11,.23,(x+side*.42,9.78),-.65,.25,trim,end=2*math.pi,segments=16)
        else:
            box('Street corner pier',(x,.02,5.3),(.75,.8,10.6),granite)
    # Engaged upper colonnade spans 17th through 20th floors.
    if public:
        for n in range(1,bays):
            x=-width/2+n*pitch
            column('Upper engaged terracotta column',x,-.24,73.2,87.7,.27,trim)
            box('Upper carved capital',(x,-.32,87.75),(.9,.76,.46),trim)
            for edge in [-1,1]:
                arch('Upper Ionic volute',.075,.17,(x+edge*.27,87.7),-.65,.22,trim,end=2*math.pi,segments=12)
            # Original low-relief lion masks evoke the preserved roof ornament.
            # Exact individual sculptural carving is not replicated.
            for dx,dz,sx,sy,sz in [(0,0,.34,.19,.42),(-.23,.27,.12,.13,.12),(.23,.27,.12,.13,.12),(0,-.12,.23,.23,.15),(0,.03,.13,.22,.12)]:
                bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(x+dx,-.47,90.75+dz))
                lion=bpy.context.object;lion.name='Physical carved roof lion mask';lion.scale=(sx,sy,sz);lion.data.materials.append(trim)
            for j in range(14):
                a=j*2*math.pi/14
                bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=1,location=(x+.47*math.cos(a),-.39,90.75+.53*math.sin(a)))
                mane=bpy.context.object;mane.name='Carved lion mane lobes';mane.scale=(.13,.12,.16);mane.data.materials.append(trim)
            for side in [-1,1]:
                box('Lion recessed eye',(x+side*.13,-.65,90.85),(.09,.045,.055),dark)
    # Present-day restrained parapet, not the removed historic giant cornice.
    box('Solid terracotta lion frieze',(0,.015,90.9),(width,.49,2.2),stone)
    for z,height,depth in [(10.6,.42,.82),(14.7,.35,.74),(72.9,.4,.74),(89.6,.5,.9),(91.55,.9,.68)]:
        box('Continuous carved stone band',(0,-.03,z),(width+.12,depth,height),trim)
    orient(set(bpy.context.scene.objects)-before,p,angle)

facade(D,(W/2,0),math.pi/2,13)
facade(W,(0,-D/2),0,11)
facade(D,(-W/2,0),-math.pi/2,13,False)
# North is principally a party wall, not another ornate street frontage.
for side in [-1,1]:
    box('Plain north party wall',(side*(W+14)/4,D/2-.16,53.05),((W-14)/2,.36,76.7),stone)
box('North base party wall',(0,D/2-.16,7.25),(W,.36,14.5),stone)
facade(14,(0,D/2-4.5),math.pi,5,False)

# Bronze Michigan entries have separate transparent doors and physical recesses.
for at,entry_width in MICHIGAN_ENTRIES:
    flush()
    before=set(bpy.context.scene.objects)
    for side in [-1,1]:
        box('Bronze entry jamb',(at+side*entry_width/2,.22,3.0),(.13,.18,5.7),bronze)
    box('Bronze entry lintel',(at,.22,5.78),(entry_width+.15,.18,.18),bronze)
    door_w=entry_width/2-.16
    for side in [-1,1]:
        box('Separate clear entrance door',(at+side*(entry_width/4-.03),-.02,2.4),(door_w,.04,4.1),clear)
        box('Door stile',(at+side*(entry_width/2-.08),-.07,2.4),(.09,.12,4.2),bronze)
        box('Physical bronze handle',(at+side*.18,-.18,2.2),(.055,.19,.6),bronze)
    box('Entry centre mullion',(at,-.07,2.4),(.08,.12,4.2),bronze)
    box('Entry recessed vestibule rear',(at,1.6,3.0),(entry_width,.12,6),granite)
    box('Entry recessed vestibule floor',(at,.8,.08),(entry_width,1.6,.16),granite)
    text('Raised entrance lettering','122 SOUTH MICHIGAN',(at,-.18,5.3),.19,bronze,depth=.012)
    orient(set(bpy.context.scene.objects)-before,(W/2,0),math.pi/2)
flush()
finish('peoples_gas',OUT)
