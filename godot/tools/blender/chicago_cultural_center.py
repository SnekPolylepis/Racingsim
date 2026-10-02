"""Author the Cultural Center exterior; no full-building photograph is rendered.
blender -b --python tools/blender/chicago_cultural_center.py -- <output directory>
References: Chicago Architecture Center; existing credited ccc_east.jpg;
UIC's documented 65 Michigan Avenue windows. Roof returns/footprint: city.json.
"""
import bpy
import base64
import json
import math
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, mesh, box, line, text, arch, finish

OUT = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
root = Path(__file__).resolve().parents[2]
b = next(b for b in json.loads((root/"trackgen/data/chicago/city.json").read_text())["buildings"] if b.get("o")=="r15899437")
# Same State/Michigan frontage frame as ChicagoCrowns.photo_wall, facing east.
a,c = b["f"][0],b["f"][1]
length=math.dist(a,c)
along=((a[0]-c[0])/length,(a[1]-c[1])/length)
outward=(-along[1],along[0])
origin=((a[0]+c[0])/2,(a[1]+c[1])/2)
def local(p):
    dx,dz=p[0]-origin[0],p[1]-origin[1]
    return (dx*along[0]+dz*along[1],-dx*outward[0]-dz*outward[1])
ring=[local(p) for p in b["f"]]
lo,hi=min(p[0] for p in ring),max(p[0] for p in ring)
center=(lo+hi)/2
width=hi-lo
H=28.5
limestone=material("Indiana limestone",(.73,.71,.65),roughness=.8)
carved=material("Raised limestone mouldings",(.83,.80,.71),roughness=.65)
granite=material("Granite plinth",(.32,.31,.29),roughness=.65)
glass=material("Deep window glazing",(.065,.085,.095),metallic=.2,roughness=.22)
iron=material("Bronze window frames",(.16,.13,.09),metallic=.65,roughness=.45)
joint=material("Recessed limestone mortar",(.49,.47,.42))
roof=material("Roof membrane",(.17,.18,.17))

# Concave mapped volume; the east wall itself is assembled around real recesses.
n=len(ring)
vertices=[(x,y,z) for z in [0,H-.5] for x,y in ring]
faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n) if not (abs(ring[i][1])<1.0 and abs(ring[(i+1)%n][1])<1.0)]
mesh("Mapped limestone side walls",vertices,faces,limestone)
box("Recess backing",(center,1.5,14),(width,.3,28),limestone)
pitch=width/13
for i in range(13):
    x=lo+pitch*(i+.5)
    r=2.15
    # Arched main-storey glazing, inset behind the reveal and carved archivolts.
    box("Arcade window stem",(x,.5,10.6),(r*2,.18,6.8),glass)
    v=[(x,.41,14)] + [(x+r*math.cos(j*math.pi/24),.41,14+r*math.sin(j*math.pi/24)) for j in range(25)]
    mesh("Round arch glazing",v,[(0,j+1,j+2) for j in range(24)],glass)
    arch("Deep arcade reveal",r,r+.32,(x,14),-.32,1.05,carved,segments=24)
    arch("Raised archivolt",r+.38,r+.58,(x,14),-.53,.25,carved,segments=24)
    for dx in [-r-.16,r+.16]:
        box("Arcade reveal jamb",(x+dx,.15,10.6),(.32,1.05,6.8),carved)
    for dx in [-1.45,0,1.45]:
        box("Arcade bronze mullion",(x+dx,.2,10.6),(.065,.16,6.8),iron)
    for z in [9.3,11.6,13.8]:
        box("Arcade transom",(x,.15,z),(r*2,.18,.075),iron)
    # Two upper and two ground-floor windows per bay: 13 * 5 = 65.
    for dx in [-1.35,1.35]:
        box("Upper recessed sash",(x+dx,.42,22.6),(1.9,.18,6.0),glass)
        box("Ground recessed sash",(x+dx,.42,3.3),(1.9,.18,3.4),glass)
        for z in [2.5,4.1,21,22.6,24.2]:
            box("Window meeting rail",(x+dx,.2,z),(1.9,.16,.065),iron)
        for dd in [-1.07,1.07]:
            box("Upper stone reveal",(x+dx+dd,-.18,22.6),(.18,.9,6.4),carved)
        for z in [19.5,25.7]:
            box("Upper sill lintel",(x+dx,-.3,z),(2.3,1.1,.22),carved,.025)
    # Fluted pilasters and capitals separate the upper window pairs.
    px=x+pitch*.49
    box("Arcade masonry pier",(px,.2,11.4),(pitch-5.5,1.9,11),limestone)
    box("Upper fluted pilaster",(px,-.25,22.6),(.85,.75,6.4),carved)
    for dx in [-.26,-.13,0,.13,.26]:
        box("Pilaster flute shadow",(px+dx,-.66,22.6),(.05,.06,5.4),joint)
    for z in [19.45,25.85]:
        box("Pilaster capital base",(px,-.28,z),(1.25,1,.32),carved,.03)
    arch("Arcade spandrel medallion",.36,.47,(px,16.1),-.42,.15,carved,end=math.tau,segments=16)
    # Physical rustication on the first two floors.
    for z in [1.2,2.4,3.6,4.8,8,9.2,10.4,11.6,12.8,14.0]:
        box("Pier bed joint",(px,-.77,z),(pitch-5.55,.025,.035),joint)

for z,d,h in [(0.5,1.0,1.0),(6,1.3,.35),(6.6,1.5,.35),(17.9,1.25,.4),(18.5,1.6,.45),(26.3,1.2,.45),(27.0,1.8,.5),(27.6,2.1,.4),(28.2,2.5,.5)]:
    box("Continuous limestone cornice",(center,-d/2+.2,z),(width+.6,d,h),granite if z<1 else carved,.025)
for i in range(int(width/.6)):
    box("Cornice dentil",(lo+i*.6,-.9,27.6),(.24,.7,.35),carved)
text("Library carved entablature","PUBLIC LIBRARY OF THE CITY OF CHICAGO",(center,-.61,26.3),.65,joint,depth=.012)
# Side street entrances: shallow projecting porticos, columns and real door recesses.
for side in [-1,1]:
    x=lo if side<0 else hi
    portico=box("Side entrance entablature",(x,22,7.5),(3.5,13,.7),carved)
    for y in [17,19.5,24.5,27]:
        obj=box("Entrance square pier",(x, y,3.5),(1.3,1.0,7),carved,.04)
    box("Side entrance bronze doors",(x+side*.08,22,2.8),(.12,4.0,5.2),iron)
    for z in [5.5,10.0,17.5,26.5]:
        box("Side facade string course",(x,22,z),(1.3,44,.3),carved)

# Preserve the measured roof volumes above the cornice, instead of inventing domes.
g=b["L"]
data=base64.b64decode(g[5])
values=struct.unpack('<'+'H'*(len(data)//2),data)
for row in range(g[3]):
    for col in range(g[2]):
        h=values[row*g[2]+col]*.1
        if h<=H+.5:
            continue
        x,y=local((g[0]+(col+.5)*g[4],g[1]+(row+.5)*g[4]))
        box("Measured raised roof cell",(x,y,(H+h)/2),(g[4],g[4],h-H),roof)
finish("cultural_center",OUT)
