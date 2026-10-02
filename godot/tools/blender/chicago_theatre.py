"""Author Chicago Theatre's exterior in Blender; export an editable .blend and game GLB.
Run: blender -b --python tools/blender/chicago_theatre.py -- <output-directory>
Reference: Chicago Architecture Center and Daniel Schwen's Chicago_Theatre_blend.jpg.
Facade proportions follow the 18 m mapped State Street wall and measured front roof.
Blender frame: X across the frontage, Y into the building, Z up. No photo planes.
"""
import bpy
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box, line, text, arch, finish

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)




stone = material("Glazed ivory terra cotta", (.72, .68, .56), roughness=.4)
trim = material("Raised cream ornament", (.87, .82, .69), roughness=.45)
joint = material("Recessed masonry joints", (.43, .40, .33))
brick = material("Auditorium red brown brick", (.29, .15, .10))
glass = material("Recessed blue green glass", (.065, .105, .11), metallic=.25, roughness=.2)
iron = material("Black iron window frames", (.035, .04, .038), metallic=.55)
red = material("Marquee red enamel", (.60, .022, .017), metallic=.2, roughness=.3)
gold = material("Marquee brass edging", (.72, .46, .10), metallic=.65, roughness=.3)
white = material("Sign porcelain lettering", (.94, .90, .74), roughness=.4)
bulb = material("Night incandescent bulbs", (1, .68, .22), glow=3)
neon = material("Night warm white neon", (1, .87, .59), glow=2)












# Lobby frontage: actual depth changes, not painted windows on a solid wall.
# Authoring grid below is fitted to the 27.5 m median measured frontage roof.
H = 27.5
for side in [-1, 1]:
    box("Terra cotta side pier", (side*6.95, .8, 11.0), (4.1, 2.0, 22), stone)
box("Masonry above arch", (0, .8, 22.3), (18, 2, 4.6), stone)
box("Lower entrance head", (0, .8, 5.3), (10, 2, 2.6), stone)
box("Lobby interior", (0, 4, 11), (18, 3, 22), joint)
box("Recessed arched glazing stem", (0, 1.05, 10), (9.3, .22, 7), glass)
# A half-disc closes the upper glass while keeping the opening recessed.
vertices = [(0, 1, 13.5)] + [(4.65*math.cos(i*math.pi/40), 1, 13.5+4.65*math.sin(i*math.pi/40)) for i in range(41)]
mesh("Arched glazing crown", vertices, [(0,i+1,i+2) for i in range(40)], glass)
arch("Deep arch reveal", 4.65, 5.0, (0,13.5), -.15, 1.4, trim)
arch("Outer moulded archivolt", 5.05, 5.5, (0,13.5), -.36, .28, trim)
# Spandrels close the masonry above the curved reveal; the glass opening stays hollow.
for i in range(40):
    a=i*math.pi/40
    b=(i+1)*math.pi/40
    x0,z0=5.5*math.cos(a),13.5+5.5*math.sin(a)
    x1,z1=5.5*math.cos(b),13.5+5.5*math.sin(b)
    mesh("Arch spandrel",[(x0,-.19,z0),(x1,-.19,z1),(x1,-.19,20.1),(x0,-.19,20.1)],[(0,1,2,3)],stone)
box("Arch keystone",(0,-.48,19.0),(.7,.45,.85),trim,.06)
for x in [-4,-2,0,2,4]:
    arch("Frieze wreath",.35,.47,(x,21.0),-.4,.12,trim,end=math.tau,segments=16)
    for i in range(8):
        angle=i*math.tau/8
        line("Frieze carved petal",[(x+.47*math.cos(angle),-.48,21+.47*math.sin(angle)),
                                    (x+.65*math.cos(angle+.10),-.48,21+.65*math.sin(angle+.10)),
                                    (x+.47*math.cos(angle+.22),-.48,21+.47*math.sin(angle+.22))],.045,trim)
for side in [-1,1]:
    box("Arch reveal jamb", (side*4.82, .5, 10), (.35,1.4,7), trim)
    box("Outer pilaster", (side*7.45, -.42, 13.4), (1.1,.55,18.8), trim)
    for x in [-.32,-.16,0,.16,.32]:
        box("Pilaster flute", (side*7.45+x, -.73, 13.5), (.055,.06,15.7), joint)
    for z,w,d in [(4.0,1.5,.8),(21.8,1.6,.8),(22.2,1.9,.9)]:
        box("Pilaster base and capital", (side*7.45,-.45,z), (w,d,.35), trim, .035)
    # Relief medallions, wreaths and inset panels are physical ornament.
    for z in [7.5,12.5,20.6]:
        arch("Carved pier medallion", .48,.63,(side*6.05,z),-.4,.16,trim,end=math.tau,segments=24)
    box("Decorative pier inset", (side*6.05,-.25,16.1),(1.0,.18,2.9),joint)
    for x in [-.45,.45]:
        line("Inset carved border", [(side*6.05+x,-.4,14.65),(side*6.05+x,-.4,17.55)], .06,trim)

for x in [-3,-1.5,0,1.5,3]:
    box("Iron arch mullion", (x,.75,10),(.09,.16,7),iron)
    height = math.sqrt(4.65**2-x*x)
    box("Crown radial mullion", (x,.75,13.5+height/2),(.085,.15,height),iron)
for z in [8,10.2,12.4,13.5]:
    box("Arch horizontal transom", (0,.73,z),(9.3,.16,.095),iron)
arch("Tiffany oculus frame",2.05,2.18,(0,13.5),.55,.2,iron,end=math.tau)
arch("Tiffany inner ring",1.78,1.86,(0,13.5),.54,.21,gold,end=math.tau)
for i in range(12):
    a=i*math.tau/12
    line("Stained glass radial lead",[(1.86*math.cos(a),.53,13.5+1.86*math.sin(a)),(2.05*math.cos(a),.53,13.5+2.05*math.sin(a))],.045,iron)
text("Balaban Katz medallion", "B & K", (0,.51,13.5), .70, gold)

# Two attic rows, recessed windows, ornamental frieze, projecting dentil cornice.
for z,h in [(24.6,3.4),(28.3,3.5)]:
    box("Attic recessed backing",(0,1,z),(18,.6,h),joint)
    for x in [-7.4,-5,-2.5,0,2.5,5,7.4]:
        box("Attic glazing",(x,.42,z),(1.45,.12,1.8),glass)
        for dx in [-.83,.83]:
            box("Attic window jamb",(x+dx,-.05,z),(.20,.85,h),trim)
        for dz in [-1,1]:
            box("Attic sill",(x,-.18,z+dz),(1.9,.95,.22),trim,.025)
for z,width,depth,height in [(22.9,18.2,.75,.4),(23.4,18.6,1.05,.35),(26.2,18.7,1.2,.4),(26.6,19,1.4,.35),(30.1,18.4,1.1,.35),(30.6,19.2,1.6,.45)]:
    box("Projecting cornice course",(0,-depth/2+.3,z),(width,depth,height),trim,.04)
for x in [i*.5 for i in range(-18,19)]:
    box("Cornice dentil",(x,-.4,26.05),(.22,.58,.35),trim)
    box("Roof modillion",(x,-.4,30.1),(.24,.65,.45),trim)
for z in [7,9,11,13,15,17,19,21]:
    for side in [-1,1]:
        box("Terra cotta bed joint",(side*6.95,-.215,z),(4.05,.018,.028),joint)

# Deep door recesses and metal-framed double leaves below the overhanging canopy.
for x in [-6.6,-4.4,-2.2,0,2.2,4.4,6.6]:
    box("Entry glazing",(x,1.1,1.8),(1.85,.18,3.5),glass)
    for dx in [-.95,0,.95]:
        box("Entry brass jamb",(x+dx,.85,1.8),(.055,.16,3.5),gold)
    for z in [.12,2.5,3.55]:
        box("Entry brass transom",(x,.82,z),(1.95,.15,.07),gold)
    for dx in [-.18,.18]:
        box("Door pull",(x+dx,.68,1.3),(.035,.05,.48),gold)

# CHICAGO canopy: depth and side faces are visible while driving past.
box("Marquee overhang",(0,-1.9,4.8),(18.4,3.8,.75),red,.12)
box("Lit canopy soffit",(0,-1.8,4.38),(17.8,3.6,.08),white)
for y in [-3.82,0]:
    box("Marquee changeable panel",(0,y,5.7),(17.6,.15,1.35),white)
    for z in [5.0,6.4]:
        box("Marquee gold rail",(0,y-.09,z),(18,.15,.16),gold,.025)
for x in [-9,9]:
    box("Marquee side panel",(x,-1.9,5.7),(.15,3.8,1.35),white)
text("Marquee program", "LIVE MUSIC  •  CHICAGO THEATRE",(0,-3.93,5.72),.43,iron)
for x in [-8,-4,0,4,8]:
    points=[(x+t*.065,-3.91,6.9+.28*math.sin(t*.3)) for t in range(-20,21)]
    line("Marquee gold scrollwork",points,.10,gold)
arch("Marquee circular C brass surround",1.05,1.22,(-2.8,7.5),-4.0,.20,gold,end=math.tau)
text("Marquee sculpted CHICAGO", "CHICAGO",(0,-4.13,7.4),1.55,neon,depth=.10)

# Projecting blade sign: two readable faces, rounded edging, supports and bulb rows.
outline=[(-.45,8.3),(-.6,9),(-.6,27.4),(-.15,28.25),(-.10,29.3),(-.8,29.1),
         (-2,29.8),(-3.2,29.1),(-3.9,29.3),(-3.9,28.25),(-3.4,27.4),(-3.4,9),
         (-3.6,8.3),(-2,7.7)]
count=len(outline)
vertices=[(x,y,z) for x in [-7.925,-7.275] for y,z in outline]
faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]
faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
mesh("Shaped red blade sign",vertices,faces,red)
for x in [-7.98,-7.22]:
    line("Sculpted blade outline",[(x,y,z) for y,z in outline+[outline[0]]],.07,gold)
    for y in [-3.5,-.5]:
        line("Blade brass edge",[(x,y,8),(x,y,28.8)],.085,gold)
    for z in [8,28.8]:
        box("Blade shaped cap",(x,-2,z),(.12,3.2,.35),gold,.08)
    for i,char in enumerate("CHICAGO"):
        # Text's normal is +/-X: letters stand proud of each side of the blade.
        rotation=(math.pi/2,0,math.pi/2 if x>-7.6 else -math.pi/2)
        text("Blade raised letter "+char,char,(x,-2,26.7-i*2.55),2.0,neon,rotation,depth=.075)
for z in [12,20,27]:
    line("Blade wall bracket",[(-7.6,.8,z),(-7.6,-3.2,z)],.075,iron)
    line("Blade diagonal brace",[(-7.6,.8,z+1.4),(-7.6,-2.7,z)],.06,iron)

# Bulbs use shared meshes during authoring, then join by material for a small draw count.
bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=.045)
seed=bpy.context.object
seed.name="Bulb prototype"
seed.data.materials.append(bulb)
def lamp(pos):
    obj=bpy.data.objects.new("Marquee bulb",seed.data)
    bpy.context.collection.objects.link(obj)
    obj.location=pos
for x in [-8.02,-7.18]:
    for y in [-3.45,-.55]:
        for i in range(101):
            lamp((x,y,8.25+i*.20))
for z in [5.01,6.40]:
    for i in range(91):
        lamp((-9+i*.20,-3.99,z))
for x in range(-8,9,2):
    for y in [-3,-2,-1]:
        lamp((x,y,4.31))
bpy.data.objects.remove(seed,do_unlink=True)

for obj in bpy.data.objects:
    obj.location.z *= H / 30.8
    obj.scale.z *= H / 30.8

# Auditorium mass follows the real concave OSM footprint in the same local facade frame.
root=Path(__file__).resolve().parents[2]
city=json.loads((root/"trackgen/data/chicago/city.json").read_text())
building=next(b for b in city["buildings"] if b.get("o")=="w124873919")
ring=[(z+51.9,x+274.95) for x,z in building["f"]]
vertices=[(x,y,z) for z in [0,29.0] for x,y in ring]
n=len(ring)
faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
# Leave the front lobby open; otherwise the shell would fill its recessed facade.
faces=[f for f in faces if not (len(f)==4 and max(vertices[i][1] for i in f)<.3)]
mesh("Mapped auditorium shell",vertices,faces,brick)
box("Lobby roof",(0,3,H-.3),(18,6,.6),stone)
box("Auditorium raised stage house",(-16,53,32.0),(25,18,6),brick)
for y in [14,30,46]:
    for x in [-9,8.8]:
        box("Auditorium side buttress",(x,y,13),(1.0,.9,26),brick)



finish("chicago_theatre", OUT)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# Adjacent Page Brothers: the old photo also baked half the Theatre's sign onto this wall.
# Six office floors, seven State Street window bays, raised brick piers, and cast-iron Lake Street face.
page_brick=material("Page warm grey brick",(.43,.38,.31))
page_iron=material("Page painted cast iron",(.28,.30,.28),metallic=.3)
box("Page interior backing",(0,10.3,13.5),(33,20.6,27),page_brick)
for x in [-14,-9.35,-4.7,0,4.7,9.35,14]:
    for z in [8,11.7,15.4,19.1,22.8,26.0]:
        box("Page recessed sash",(x,-.11,z),(2.65,.15,2.75),glass)
        for dx in [-1.4,1.4]:
            box("Page stone jamb",(x+dx,-.3,z),(.18,.55,3.2),trim)
        for dz in [-1.52,1.52]:
            box("Page projecting sill",(x,-.4,z+dz),(3.0,.8,.22),trim,.025)
        box("Page sash meeting rail",(x,-.25,z),(2.65,.08,.055),iron)
for x in [-16.2,-11.7,-7,-2.35,2.35,7,11.7,16.2]:
    box("Page brick pilaster",(x,-.22,16),(.85,.6,21.2),page_brick)
    box("Page pilaster capital",(x,-.4,26.9),(1.25,.8,.38),trim,.025)
for z,width,depth,h in [(5.5,33.2,.75,.35),(6,33.4,.9,.3),(27.2,33.6,1.0,.4),(27.6,34,1.4,.4)]:
    box("Page cornice",(0,-depth/2,z),(width,depth,h),trim,.04)
for x in [i*.55 for i in range(-29,30)]:
    box("Page modillion",(x,-.65,27.0),(.25,.9,.45),page_iron)
for x in [-13.75,-8.25,-2.75,2.75,8.25,13.75]:
    box("Page storefront glazing",(x,-.15,2.7),(4.9,.15,4.8),glass)
    for dx in [-2.55,0,2.55]:
        box("Page shop cast iron mullion",(x+dx,-.4,2.7),(.12,.5,5.4),page_iron)
    box("Page storefront transom",(x,-.4,4.4),(5.3,.5,.12),page_iron)
# The north face faces Lake Street. Its cast iron columns and spandrels have actual depth.
for y in [2,6,10,14,18]:
    for z in [8,11.7,15.4,19.1,22.8,26]:
        box("Lake Street sash",(-16.56,y,z),(.12,2.7,2.7),glass)
        box("Lake Street cast iron sill",(-16.7,y,z-1.5),(.55,3.3,.3),page_iron)
    box("Lake Street cast iron column",(-16.75,y+1.8,16),(.55,.3,22),page_iron)
for z in [5.5,9.9,13.6,17.3,21,24.7,27.4]:
    box("Lake Street spandrel course",(-16.75,10.3,z),(.6,20.6,.3),page_iron)
finish("page_brothers", OUT)
