"""Original Old Republic exterior; Blender +Y north/+Z up, west Michigan front.
Reference: City of Chicago 2010 designation report; dimensions fit w127107033.
"""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, arch, line, text, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone = material('Light buff glazed terracotta', (.69,.66,.57), roughness=.8)
trim = material('Carved terracotta cornices and capitals', (.76,.72,.62), roughness=.82)
granite = material('Minnesota granite street base', (.36,.35,.32), roughness=.85)
brick = material('Buff Kittanning rear brick', (.55,.48,.36), roughness=.9)
dark = material('Deep opaque window backing', (.055,.052,.047), roughness=.85)
glass = material('Separate recessed double hung panes', (.16,.21,.23), roughness=.5)
night = material('Night occupied office panes', (.22,.19,.14), roughness=.5, glow=.3)
green = material('Dark green glazed retail spandrels', (.075,.14,.11), roughness=.48)
bronze = material('Bronze entrance and dark metal sash', (.19,.15,.085), metallic=.5, roughness=.55)
clear = material('Clear arched entry glazing', (.28,.34,.36), roughness=.5)
clear.diffuse_color = (.28,.34,.36,.18)
roof = material('Grey penthouse roof', (.25,.26,.25), roughness=.95)
W,D = 20.5,40.5

# Bake repeated boxes locally; original physical openings are retained.
batch = {}
def box(name,p,size,mat):
    vertices,faces = batch.setdefault(mat.name,([],[]))
    start=len(vertices)
    vertices.extend([(p[0]+x*size[0]/2,p[1]+y*size[1]/2,p[2]+z*size[2]/2)
                     for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                                   (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]])
    faces.extend([tuple(start+i for i in face) for face in
                  [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
def flush():
    for name,(vertices,faces) in batch.items():
        mesh(name,vertices,faces,bpy.data.materials[name])
    batch.clear()
def orient(before,p,angle):
    flush()
    c,s=math.cos(angle),math.sin(angle)
    for obj in set(bpy.context.scene.objects)-before:
        x,y,z=obj.location
        obj.location=(p[0]+x*c-y*s,p[1]+x*s+y*c,z)
        obj.rotation_euler.z+=angle

def column(name,x,y,lo,hi,radius):
    vertices=[(x+radius*math.cos(i*math.pi/8),y+radius*math.sin(i*math.pi/8),z)
              for z in [lo,hi] for i in range(16)]
    mesh(name,vertices,[tuple(reversed(range(16))),tuple(range(16,32))]+
         [(i,(i+1)%16,(i+1)%16+16,i+16) for i in range(16)],trim)

box('Mapped underground foundation',(0,0,-4),(W,D,8),granite)
box('Inset opaque upper tower core',(0,0,52.6),(W-1.6,D-1.6,78.8),dark)
# Keep the west vestibule physically open through the opaque lower core.
inner_x=-W/2+.8
back_x=-W/2+2.5
right_x=W/2-.8
box('Lower core behind vestibule',((back_x+right_x)/2,0,6.6),(right_x-back_x,D-1.6,13.2),dark)
for side in [-1,1]:
    half_depth=(D-1.6)/2
    box('Lower core beside entry',((inner_x+back_x)/2,side*(half_depth+1.75)/2,6.6),
        (back_x-inner_x,half_depth-1.75,13.2),dark)
flush()

def facade(width,bays,p,angle,rear=False):
    before=set(bpy.context.scene.objects)
    pitch=width/bays
    facing=brick if rear else stone
    west=not rear and width==D and angle==-math.pi/2
    for i in range(bays):
        at=-width/2+(i+.5)*pitch
        # Central west entry occupies three levels; glazing has a real void.
        entrance = not rear and width==D and angle==-math.pi/2 and i==bays//2
        for floor in range(23):
            lo,hi=(0,5.3) if floor==0 else (5.3+(floor-1)*3.91,5.3+floor*3.91)
            h=hi-lo; pane_w=pitch*.55
            if west and floor<2:continue
            if entrance and floor<3:continue
            if floor==0:
                pane_w=pitch*.82
            box('Continuous projecting pier',(at-pitch/2,0,(lo+hi)/2),(pitch-pane_w,.65,h),facing)
            box('Decorative solid spandrel',(at,0,lo+h*.17),(pane_w+.12,.65,h*.34),green if floor==1 and not rear else facing)
            pane=night if (i*7+floor*11)%19 in [1,4,8] else glass
            paired = i in [0,bays-1] and floor>0 and not rear
            # Strengthened corner tiers contain two individual window openings.
            panes=[(at-pane_w*.26,pane_w*.42),(at+pane_w*.26,pane_w*.42)] if paired else [(at,pane_w)]
            for centre,pane_width in panes:
                box('Separate recessed pane',(centre,.29,lo+h*.66),(pane_width-.12,.04,h*.58),pane)
                for side in [-1,1]:
                    box('Physical sash jamb',(centre+side*(pane_width-.07)/2,.2,lo+h*.66),(.065,.14,h*.61),bronze)
                box('Double hung meeting rail',(centre,.17,lo+h*.66),(pane_width,.16,.07),bronze)
            if paired:box('Corner paired window stone mullion',(at,0,lo+h*.66),(pane_w*.1,.65,h*.62),facing)
            box('Projecting stone sill',(at,-.25,lo+h*.36),(pane_w+.24,.55,.14),trim)
        if not rear:
            for lo,hi in [(1.22,13.05),(76,90.9)]:
                if west and lo<2:continue
                x=at-pitch/2
                if lo>70:
                    column('Round engaged Corinthian upper shaft',x,-.28,lo,hi,.29)
                else:box('Engaged pilaster shaft',(x,-.43,(lo+hi)/2),(.42,.44,hi-lo),trim)
                # Physical fluting, stylized acanthus capitals and scrolls.
                if lo<70:
                    for flute in [-.12,0,.12]:
                        box('Fluted pilaster ribs',(x+flute,-.7,(lo+hi)/2),(.04,.08,hi-lo-.4),stone)
                box('Corinthian abacus',(x,-.43,hi),(.88,.72,.22),trim)
                for side in [-1,1]:
                    arch('Corinthian scroll',.07,.15,(x+side*.23,hi-.28),-.78,.12,trim,segments=10,start=0,end=2*math.pi)
                for leaf in [-.24,0,.24]:
                    box('Acanthus capital leaves',(x+leaf,-.58,hi-.48),(.16,.28,.48),trim)
    box('End pier',(width/2,0,46),(.65,.65,92),facing)
    if west:
        # Three broad retail bays on either side, with Chicago-style upper panes.
        retail_pitch=(width/2-2.05)/3
        for side in [-1,1]:
            for i in range(3):
                at=side*(2.05+(i+.5)*retail_pitch)
                pane_width=retail_pitch-.95
                box('Granite retail plinth',(at,-.05,.6),(retail_pitch,.75,1.2),granite)
                box('Recessed broad retail glazing',(at,.29,3.1),(pane_width,.04,3.8),glass)
                box('Dark green retail spandrel',(at,0,5.0),(pane_width,.65,.65),green)
                box('Chicago central upper pane',(at,.29,7.2),(pane_width*.56,.04,3.2),glass)
                for small in [-1,1]:
                    cx=at+small*pane_width*.39
                    box('Chicago flanking sash pane',(cx,.29,7.2),(pane_width*.2,.04,3.2),glass)
                    box('Chicago narrow sash rail',(cx,.17,7.2),(pane_width*.2,.15,.07),bronze)
                for mullion in [-.28,.28]:
                    box('Chicago pane divider',(at+mullion*pane_width,.17,7.2),(.08,.16,3.3),bronze)
                box('Retail head',(at,0,8.95),(retail_pitch,.65,.5),stone)
                for edge in [-1,1]:
                    x=at+edge*retail_pitch/2
                    box('Retail full height pier',(x,0,6.6),(.8,.7,13.2),stone)
                    box('Retail Corinthian pilaster',(x,-.48,6.6),(.5,.4,11.8),trim)
                    for flute in [-.14,0,.14]:box('Retail pilaster flute',(x+flute,-.72,6.6),(.04,.08,11.5),stone)
                    box('Retail Corinthian abacus',(x,-.45,12.9),(.95,.8,.25),trim)
                    for scroll in [-1,1]:arch('Retail capital scroll',.07,.17,(x+scroll*.25,12.58),-.85,.12,trim,start=0,end=2*math.pi,segments=10)
    if not rear:
        for z,depth,height in [(1.0,.75,.42),(13.3,.85,.45),(17.1,1.35,.5),(75.8,.95,.3),(91.5,1.7,.7),(92.15,2.05,.4)]:
            box('Projecting classical cornice',(0,-.25,z),(width+1.0,depth,height),trim)
        for i in range(bays*2):
            box('Cornice modillion',( -width/2+(i+.5)*width/(bays*2),-.63,91.15),(.24,1.0,.5),trim)
    orient(before,p,angle)

facade(D,13,(-W/2,0),-math.pi/2)
facade(W,6,(0,-D/2),0)
facade(W,6,(0,D/2),math.pi)
facade(D,13,(W/2,0),math.pi/2,True)

# Monumental Michigan entry: no facade plane across the arched aperture.
before=set(bpy.context.scene.objects)
radius=1.54; spring=9.5; top=spring+radius
for side in [-1,1]:
    box('Three story entry jamb',(side*1.82,0,6.4),(.55,1.2,12.8),trim)
arch('Rounded entry surround',radius,radius+.3,(0,spring),-.65,.6,trim,segments=32)
box('Arch upper lintel',(0,0,12.15),(3.64,1.2,1.6),stone)
box('Vestibule back',(0,1.65,5),(3.3,.2,10),dark)
box('Recessed glass doors',(0,1.1,1.8),(2.6,.04,3.2),clear)
for x in [-1.3,0,1.3]:box('Bronze door stiles',(x,1.02,1.8),(.08,.14,3.4),bronze)
box('Entry transom',(0,.72,6.5),(2.94,.04,6.4),clear)
arc_vertices=[(0,.72,spring)]+[(radius*math.cos(i*math.pi/32),.72,spring+radius*math.sin(i*math.pi/32)) for i in range(33)]
mesh('Actual semicircular upper entry glazing',arc_vertices,[(0,i+1,i+2) for i in range(32)],clear)
for x in [-.77,0,.77]:box('Transom metal mullion',(x,.6,6.55),(.065,.17,6.3),bronze)
for z in [3.5,4.7,5.9,7.1,8.3,9.5]:box('Transom meeting rail',(0,.6,z),(3.02,.17,.07),bronze)
for x in [-.77,0,.77]:
    cap=spring+math.sqrt(max(0,radius*radius-x*x))
    box('Arched upper mullions',(x,.6,(spring+cap)/2),(.065,.17,cap-spring),bronze)
box('Entry threshold',(0,.8,.1),(3.1,2.4,.2),granite)
text('Entry name','OLD REPUBLIC BUILDING',(0,.55,3.35),.16,bronze)
text('Address','307',(0,.55,3.0),.2,bronze)
box('OR cartouche',(0,-.82,11.48),(.6,.28,.9),trim)
text('Cartouche letters','OR',(0,-1.0,11.4),.25,bronze)
orient(before,(-W/2,0),-math.pi/2)

# Setback penthouse about fifteen feet on north/west/south; plain brick east.
box('Solid main roof',(0,0,92.3),(W,D,.45),roof)
box('Setback twenty fourth floor',(2.28,0,94.5),(W-4.572,D-9.144,4.0),stone)
for i in range(9):
    y=-(D-9.144)/2+(i+.5)*(D-9.144)/9
    box('Penthouse west panes',(-W/2+4.5,y,94.5),(.05,1.3,1.7),glass)
box('Penthouse flat roof',(2.28,0,96.6),(W-4.2,D-8.9,.25),roof)
box('Mechanical penthouse',(4.3,3,97.8),(7.6,9,2.4),brick)
box('Mechanical roof',(4.3,3,99.05),(7.9,9.3,.1),roof)
flush()

# 1975 southwest corner alteration: cut the lower exterior diagonally, then
# place the separate retail doors on that recessed face. No texture illusion.
cut_distance=2.35
offset=50-cut_distance/math.sqrt(2)
cutter=baked_box('Temporary southwest chamfer cutter',(0,0,0),(100,100,5.3),dark)
cutter.location=(-W/2-offset/math.sqrt(2),-D/2-offset/math.sqrt(2),2.65)
cutter.rotation_euler.z=-math.pi/4
for obj in list(bpy.context.scene.objects):
    if obj==cutter or obj.type!='MESH':continue
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Actual southwest retail chamfer','BOOLEAN')
    modifier.operation='DIFFERENCE'
    modifier.solver='EXACT'
    modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.data.objects.remove(cutter,do_unlink=True)
before=set(bpy.context.scene.objects)
chamfer_width=cut_distance*math.sqrt(2)
box('Recessed southwest corner doors',(0,.32,2.1),(chamfer_width-.28,.04,3.8),clear)
for x in [-(chamfer_width-.18)/2,0,(chamfer_width-.18)/2]:
    box('Corner retail door stiles',(x,.2,2.1),(.08,.15,4),bronze)
box('Corner retail transom',(0,.2,4.2),(chamfer_width,.15,.09),bronze)
box('Corner entry back wall',(0,.9,2.5),(chamfer_width,.12,5),dark)
box('Corner entry head',(0,0,4.85),(chamfer_width,.65,.9),stone)
box('Corner threshold',(0,.4,.12),(chamfer_width,1.2,.24),granite)
orient(before,(-W/2+cut_distance/2,-D/2+cut_distance/2),-math.pi/4)
finish('old_republic',OUT)
