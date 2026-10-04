"""Original modeled 155 North Wacker exterior; +Y north, +Z up."""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, text, finish
OUT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
glass = material('Blue grey curtain glass', (.12,.21,.26), roughness=.36)
occupied = material('Night occupied curtain glass', (.12,.21,.26), roughness=.36, glow=.25)
spandrel = material('Dark curtain spandrels', (.06,.105,.14), roughness=.42)
steel = material('Silver projecting fins and cable fittings', (.46,.49,.5), metallic=.65, roughness=.38)
stone = material('Pale arcade piers and paving', (.56,.53,.46), roughness=.68)
wood = material('Night warm lobby wall panels', (.39,.20,.09), roughness=.7, glow=.15)
roof = material('Mechanical louvers and roof', (.09,.12,.14), roughness=.85)
clear = material('Clear cable supported lobby glazing', (.35,.44,.47), roughness=.35)
light = material('Night arcade ceiling strips', (.67,.61,.46), roughness=.6, glow=.25)
W,D,ARCADE,ROOF,TOP = 66.5,54.2,13.716,191.6,194.6
NOTCH,RECESS = 21.8,11.5

def box(name,pos,size,mat):
    obj=baked_box(name,(0,0,0),size,mat)
    obj.location=pos
    return obj

def orient(objects,angle,origin=(0,0)):
    c,s=math.cos(angle),math.sin(angle)
    for obj in objects:
        x,y,z=obj.location
        obj.location=(x*c-y*s+origin[0],x*s+y*c+origin[1],z)
        obj.rotation_euler.z+=angle

# H plan: two full-width north/south wings and a recessed central bridge.
WING=(D-NOTCH)/2
for y in (-(D+NOTCH)/4,(D+NOTCH)/4):
    box('Full width H plan wing',(0,y,(ARCADE+ROOF)/2),(W-.12,WING-.12,ROOF-ARCADE),spandrel)
    box('Wing roof',(0,y,ROOF-.07),(W-.18,WING-.18,.14),roof)
box('Recessed H plan bridge',(0,0,(ARCADE+188.6)/2),(W-2*RECESS-.12,NOTCH,188.6-ARCADE),spandrel)
box('Recessed bridge roof',(0,0,188.53),(W-2*RECESS-.18,NOTCH,.14),roof)

def facade(width,origin,angle,top=ROOF,fins=False):
    before=set(bpy.context.scene.objects)
    cols=round(width/1.5)
    pitch=width/cols
    fp=3.9624
    for row in range(45):
        bottom=ARCADE+row*fp
        if bottom+fp>top-.25:break
        for col in range(cols):
            x=-width/2+(col+.5)*pitch
            mat=occupied if (row*11+col*7)%19 in (0,1,7) else glass
            box('Individual vision pane',(x,.018,bottom+fp*.58),(pitch-.055,.035,fp*.76),mat)
        box('Floor transom',(0,.045,bottom),(width,.09,.065),steel)
        box('Inset floor spandrel',(0,.012,bottom+fp*.095),(width,.035,fp*.19),spandrel)
        # Architect photographs show small projecting metal clips at each floor.
        if fins:
            for col in range(1,cols,2):
                box('Curtain wall projecting clip',(-width/2+col*pitch,.115,bottom+.14),(.10,.23,.35),steel)
    for col in range(cols+1):
        box('Continuous curtain mullion',(-width/2+col*pitch,.065,(ARCADE+top)/2),(.055,.12,top-ARCADE),steel)
    orient(set(bpy.context.scene.objects)-before,angle,origin)

# Outer long north/south faces and shorter ends of each wing.
facade(W,(0,D/2),0,fins=True)
facade(W,(0,-D/2),math.pi,fins=True)
for y in (-(D+NOTCH)/4,(D+NOTCH)/4):
    facade(WING,(-W/2,y),math.pi/2)
    facade(WING,(W/2,y),-math.pi/2)
# Six real walls articulate the west/east H recesses, rather than a solid block.
for x in (-W/2+RECESS,W/2-RECESS):
    facade(NOTCH,(x,0),math.pi/2 if x<0 else -math.pi/2,188.6)
for x in (-(W-RECESS)/2,(W-RECESS)/2):
    facade(RECESS,(x,-NOTCH/2),0)
    facade(RECESS,(x,NOTCH/2),math.pi)

# Six silver fins extend down into tall south arcade piers; their tips set height.
for x in (-W/2+.8,-W/2+W/5,-W/2+2*W/5,-W/2+3*W/5,-W/2+4*W/5,W/2-.8):
    box('South freestanding arcade pier',(x,-D/2+.9,ARCADE/2),(1.0,1.8,ARCADE),stone)
    box('South continuous silver blade',(x,-D/2-.14,(TOP+ARCADE)/2),(.32,.55,TOP-ARCADE),steel)
    box('South pier metal face',(x,-D/2-.02,ARCADE/2),(1.05,.09,ARCADE),steel)
    box('North silver blade',(x,D/2+.14,(TOP+ARCADE)/2),(.32,.55,TOP-ARCADE),steel)

# South arcade stays open for 8 m behind its piers, then cable-supported lobby.
box('Street deck foundation',(0,0,-4),(W,D,8),stone)
box('Ground paving',(0,0,.10),(W,D,.2),stone)
box('Arcade ceiling',(0,-D/2+4,ARCADE+.18),(W,8,.36),stone)
box('North lower podium',(0,D/2-8,ARCADE/2),(W,16,ARCADE),spandrel)
box('Lobby rear wall',(0,1,6.65),(W-2,1,13.3),wood)
for x in (-W/2+1,W/2-1):
    box('Lobby side wall',(x,-7,6.65),(1,17,13.3),wood)
for i in range(23):
    x=-W/2+1.4+i*(W-2.8)/22
    box('Tension cable vertical',(x,-D/2+8,6.75),(.028,.05,13.2),steel)
    for z in (3.5,6.8,10.1):
        box('Cable crossing fitting',(x,-D/2+7.94,z),(.10,.14,.10),steel)
for row in range(4):
    for col in range(22):
        x=-W/2+1.4+(col+.5)*(W-2.8)/22
        box('Oversized lobby glass panel',(x,-D/2+8.04,1.76+row*3.25),((W-2.8)/22-.035,.04,3.22),clear)
for z in (3.5,6.8,10.1):
    box('Horizontal tension cable',(0,-D/2+8,z),(W-2.8,.045,.025),steel)
for x in (-25,-12.5,0,12.5,25):
    box('Ceiling luminous strip',(x,-D/2+3.7,ARCADE-.03),(.18,7.0,.04),light)
for x in (-2.8,0,2.8):
    for side in (-1.17,1.17):
        box('Entry door jamb',(x+side,-D/2+7.9,1.65),(.10,.16,3.3),steel)
    box('Entry door head',(x,-D/2+7.9,3.3),(2.45,.16,.12),steel)
    box('Entry door glass',(x,-D/2+7.79,1.7),(2.15,.08,2.95),clear)
    box('Door pull',(x+.75,-D/2+7.7,1.5),(.06,.12,.8),steel)
text('Raised street address','155 NORTH WACKER',(0,-D/2+7.78,3.7),.5,steel)
# Ceiling grid and panel joints make the overhead structure legible close up.
for x in range(-30,31,3):
    box('Arcade ceiling grid',(x,-D/2+4,ARCADE-.02),(.025,8,.025),roof)
for i in range(5):
    box('Arcade ceiling cross grid',(0,-D/2+i*2,ARCADE-.02),(W,.025,.025),roof)
for x in (-24,24):
    box('Roof mechanical enclosure',(x,0,191.9),(12,9,1.6),roof)
    for i in range(5):
        box('Mechanical louver',(x,-4.6,191.25+i*.25),(12,.2,.1),steel)
finish('wacker_155',OUT)
