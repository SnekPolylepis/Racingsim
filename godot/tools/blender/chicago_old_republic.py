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

box('Mapped underground foundation',(0,0,-4),(W,D,8),granite)
box('Inset opaque tower core',(0,0,46),(W-1.6,D-1.6,92),dark)
flush()

def facade(width,bays,p,angle,rear=False):
    before=set(bpy.context.scene.objects)
    pitch=width/bays
    facing=brick if rear else stone
    for i in range(bays):
        at=-width/2+(i+.5)*pitch
        # Central west entry occupies three levels; glazing has a real void.
        entrance = not rear and width==D and angle==-math.pi/2 and i==bays//2
        for floor in range(23):
            lo,hi=(0,5.3) if floor==0 else (5.3+(floor-1)*3.91,5.3+floor*3.91)
            h=hi-lo; pane_w=pitch*.55
            if entrance and floor<3:continue
            if floor==0:
                pane_w=pitch*.82
            box('Continuous projecting pier',(at-pitch/2,0,(lo+hi)/2),(pitch-pane_w,.65,h),facing)
            box('Decorative solid spandrel',(at,0,lo+h*.17),(pane_w+.12,.65,h*.34),green if floor==1 and not rear else facing)
            pane=night if (i*7+floor*11)%19 in [1,4,8] else glass
            box('Separate recessed pane',(at,.29,lo+h*.66),(pane_w-.12,.04,h*.58),pane)
            for side in [-1,1]:
                box('Physical sash jamb',(at+side*(pane_w-.07)/2,.2,lo+h*.66),(.065,.14,h*.61),bronze)
            box('Double hung meeting rail',(at,.17,lo+h*.66),(pane_w,.16,.07),bronze)
            box('Projecting stone sill',(at,-.25,lo+h*.36),(pane_w+.24,.55,.14),trim)
        if not rear:
            for lo,hi in [(1.22,13.05),(76,90.9)]:
                x=at-pitch/2
                box('Engaged pilaster shaft',(x,-.43,(lo+hi)/2),(.42,.44,hi-lo),trim)
                # Physical fluting, stylized acanthus capitals and scrolls.
                for flute in [-.12,0,.12]:
                    box('Fluted pilaster ribs',(x+flute,-.7,(lo+hi)/2),(.04,.08,hi-lo-.4),stone)
                box('Corinthian abacus',(x,-.43,hi),(.88,.72,.22),trim)
                for side in [-1,1]:
                    arch('Corinthian scroll',.07,.15,(x+side*.23,hi-.28),-.78,.12,trim,segments=10,start=0,end=2*math.pi)
                for leaf in [-.24,0,.24]:
                    box('Acanthus capital leaves',(x+leaf,-.58,hi-.48),(.16,.28,.48),trim)
    box('End pier',(width/2,0,46),(.65,.65,92),facing)
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
finish('old_republic',OUT)
