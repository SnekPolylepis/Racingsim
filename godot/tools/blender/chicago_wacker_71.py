"""Original 71 South Wacker exterior; Blender +Y north, +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, line, text, finish
OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
glass = material('Blue grey curtain vision glass', (.15,.23,.27), roughness=.42)
occupied = material('Night occupied curtain vision glass', (.15,.23,.27), roughness=.42, glow=.25)
spandrel = material('Dark curtain backing and mechanical louvers', (.065,.10,.12), roughness=.7)
steel = material('Silver horizontal bands and end blades', (.43,.45,.45), metallic=.3, roughness=.55)
granite = material('Black granite core and raised planters', (.045,.055,.05), roughness=.65)
paving = material('Pale granite paving and lobby ceiling', (.59,.56,.49), roughness=.8)
clear = material('Clear reception and curved lobby glazing', (.36,.43,.44), roughness=.4)
light = material('Night recessed lobby ceiling strips', (.66,.61,.44), roughness=.6, glow=.3)
wall = material('Night warm reception wall', (.38,.29,.18), roughness=.8, glow=.15)
green = material('Garden turf and bamboo leaves', (.11,.23,.095), roughness=.9)
stem = material('Bamboo stems', (.26,.30,.10), roughness=.8)
A, B, TIP, HALL, LOBBY, TOP = 47.0, 20.0, 2.6, 15.24, 10.9728, 207.1

def box(name, pos, size, mat):
    obj = baked_box(name, (0,0,0), size, mat)
    obj.location = pos
    return obj

def prism(name, plan, bottom, top, mat):
    # All rings counterclockwise: outward side normals and upward top.
    if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1])) < 0:
        plan = list(reversed(plan))
    n = len(plan)
    vertices = [(x,y,z) for z in (bottom,top) for x,y in plan]
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name, vertices, faces, mat)

def curve(x):
    return TIP+B*(1-(x/A)**2)

# Upper plan is a bowed lozenge, with a real inset glazed slot at each end.
N = 64
north = [(A-2*A*i/N,curve(A-2*A*i/N)) for i in range(N+1)]
south = [(x,-y) for x,y in reversed(north)]
plan = north+[(-A,1.3),(-A+2,1.3),(-A+2,-1.3),(-A,-1.3)]+south
plan += [(A,-1.3),(A-2,-1.3),(A-2,1.3),(A,1.3)]
prism('Lozenge upper tower with inset end slots', plan, HALL, TOP-.2, spandrel)
central = [(33-66*i/48,curve(33-66*i/48)-.06) for i in range(49)]
central += [(x,-y) for x,y in reversed(central)]
prism('Lower central tower above curved lobby', central, LOBBY, HALL, spandrel)
prism('Lozenge roof coping', plan, TOP-.2, TOP, steel)

# Preserve the mapped compound footprint only at ground level, not as a tall slab.
city = json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text(encoding='utf-8'))
footprint = next(b['f'] for b in city['buildings'] if b.get('o')=='w148685510')
c,s = math.cos(.019526),math.sin(.019526)
foundation = []
for x,z in footprint:
    dx,dy=x+964.95,-(z-423.4)
    foundation.append((dx*c+dy*s,-dx*s+dy*c))
prism('Mapped raised street foundation', foundation, -8, .12, paving)

pitch = (201-HALL)/46
for side in (north,south):
    for i,((x,y),(u,v)) in enumerate(zip(side,side[1:])):
        dx,dy=u-x,v-y
        width=math.hypot(dx,dy)
        angle=math.atan2(dy,dx)
        # CCW boundary outward normal; north/south rows already follow CCW.
        nx,ny=dy/width,-dx/width
        clad = abs((x+u)/2)>43.8
        for row in range(47):
            bottom=HALL+row*pitch
            height=min(pitch,TOP-bottom)
            if height<=0: continue
            pane_mat = steel if clad else occupied if (row*11+i*7)%23 in (0,1,8) else glass
            obj=box('Individual bowed vision pane', ((x+u)/2+nx*.035,(y+v)/2+ny*.035,bottom+height*.61),
                    (width-.06,.045,height*.76),pane_mat)
            obj.rotation_euler.z=angle
            obj=box('Physical horizontal floor band', ((x+u)/2+nx*.05,(y+v)/2+ny*.05,bottom+height*.10),
                    (width+.015,.12,height*.20),steel)
            obj.rotation_euler.z=angle
        obj=box('Continuous slender facade mullion', (x+nx*.06,y+ny*.06,(HALL+TOP)/2),(.07,.16,TOP-HALL),steel)
        obj.rotation_euler.z=angle
        lower=HALL if abs((x+u)/2)>33 else LOBBY
        # Tall glazing remains separate and transparent, with real interior behind it.
        for row in range(3):
            z=.25+row*(lower-.25)/3
            mesh('Curved tall lobby pane',[(x,y,z),(u,v,z),(u,v,z+(lower-.25)/3-.05),(x,y,z+(lower-.25)/3-.05)],
                 [(0,1,2,3)],clear)
        obj=box('Tall lobby perimeter pier', (x,y,lower/2),(.15,.22,lower),steel)
        obj.rotation_euler.z=angle
        if abs((x+u)/2)>33:
            obj=box('End hall ceiling',((x+u)/2,(y+v)/2, HALL-.13),(width+.02,1.2,.24),paving)
            obj.rotation_euler.z=angle

for end in (-1,1):
    # Recessed full-height spine between broad steel blades.
    box('Inset end glass spine',(end*(A-2),0,(HALL+TOP)/2),(.045,2.6,TOP-HALL),glass)
    for y in (-1.95,1.95):
        box('Broad silver tip blade',(end*A,y,(HALL+TOP)/2),(.12,1.3,TOP-HALL),steel)
    for row in range(47):
        box('End spine floor band',(end*(A-1.96),0,HALL+row*pitch),(.08,2.6,.10),steel)
    box('Broad entrance canopy',(end*45.2,0,4.4),(7.5,13,.35),steel)
    box('Canopy luminous underside',(end*45.2,0,4.21),(6.8,12.1,.025),light)
    box('Reception glazing',(end*44.8,0,7.62),(.05,6.6,HALL),clear)
    for y in (-3.3,-1.1,1.1,3.3):
        box('Reception vestibule jamb',(end*44.83,y,7.62),(.13,.10,HALL),steel)
    box('Vestibule door head',(end*44.9,0,3.2),(.16,6.7,.16),steel)
    for y in (-2.2,0,2.2):
        box('Vestibule glass door',(end*44.91,y,1.6),(.06,2.0,3.1),clear)
        box('Door pull',(end*45,y+.6,1.5),(.1,.06,.8),steel)
    text('Entrance address','71 SOUTH WACKER',(end*49.02,0,4.42),.48,granite,
         rotate=(math.pi/2,0,end*math.pi/2))
    box('Reception warm elevator wall',(end*29.5,0,7.5),(.14,9,15),wall)
    for y in (-5,5):
        box('Reception ceiling strip',(end*37,y,HALL-.265),(12,.18,.025),light)

# Main curved lobby, polished core and actual ceiling lights below its soffit.
core = [(28-56*i/40,4+5*(1-((28-56*i/40)/28)**2)) for i in range(41)]
core += [(x,-y) for x,y in reversed(core)]
prism('Granite clad curved central elevator core',core,.12,LOBBY,granite)
prism('Curved lobby ceiling',central,LOBBY-.22,LOBBY,paving)
for x in range(-30,31,3):
    for sign in (-1,1):
        edge=curve(x)-.6
        box('Exposed lobby ceiling strip',(x,sign*(edge+10)/2,LOBBY-.235),(.15,edge-10,.025),light)
for x in (-23,-12,0,12,23):
    y=-15.5
    box('Black bamboo planter',(x,y,.5),(5.5,2.4,.8),granite)
    for i in range(7):
        bx,by=x-2+i*.65,y+(.45 if i%2 else -.45)
        top=5.6+(i%3)*.6
        line('Bamboo stalk',[(bx,by,.9),(bx+.12,by,top)],.035,stem)
        for j in range(5):
            z=2+j*.9
            for sign in (-1,1):
                mesh('Bamboo leaf spray',[(bx,by,z),(bx+sign*.65,by+.20,z+.25),
                     (bx+sign*.92,by+.04,z+.37),(bx+sign*.5,by-.1,z+.31)],[(0,1,2,3)],green)

# Reference-informed small raised garden beds remain inside the mapped plot.
for x in (-22,0,22):
    bed=[(x+8*math.cos(i*2*math.pi/40),-26+1.8*math.sin(i*2*math.pi/40)) for i in range(40)]
    prism('Curved south garden planter',bed,.12,.65,granite)
    prism('Raised south garden turf',[(x+(u-x)*.94,-26+(v+26)*.85) for u,v in bed],.65,.68,green)
box('Roof mechanical enclosure',(0,0,TOP-1.9),(20,13,3),spandrel)
finish('wacker_71',OUT)
