"""Original Northern Trust / 125 South Wacker exterior; +Y north, +Z up."""
import bpy, math, sys, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box as baked_box, mesh, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
granite=material('Warm grey granite vertical ribs and piers',(.48,.45,.39),roughness=.88)
glass=material('Dark bronze curtain vision glass',(.13,.17,.18),roughness=.48)
occupied=material('Night occupied curtain vision glass',(.13,.17,.18),roughness=.48,glow=.2)
bronze=material('Bronze spandrel panels and window frames',(.24,.20,.15),metallic=.25,roughness=.65)
dark=material('Mechanical louvers and dark paving joints',(.055,.065,.065),roughness=.85)
pale=material('Pale lobby stone and paving',(.62,.61,.56),roughness=.7)
wood=material('Night warm lobby wood panels',(.40,.27,.14),roughness=.8,glow=.12)
clear=material('Clear arcade storefront and canopy glass',(.37,.44,.44),roughness=.42)
light=material('Night linear lobby and arcade ceiling lights',(.72,.66,.49),roughness=.6,glow=.25)
blue=material('Blue lounge upholstery',(.055,.085,.16),roughness=.95)
W,D,LOBBY,TOP=26.3,59.2,6.4,126.5
cx,cz,YAW=-998.175,564.75,.019009

def box(name,pos,size,mat):
    obj=baked_box(name,(0,0,0),size,mat)
    obj.location=pos
    return obj

def prism(name,plan,bottom,top,mat):
    if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan=list(reversed(plan))
    n=len(plan)
    vertices=[(x,y,z) for z in (bottom,top) for x,y in plan]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vertices,faces,mat)

def orient(objects,angle,origin):
    c,s=math.cos(angle),math.sin(angle)
    for obj in objects:
        x,y,z=obj.location
        obj.location=(x*c-y*s+origin[0],x*s+y*c+origin[1],z)
        obj.rotation_euler.z+=angle

city=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text(encoding='utf-8'))
mapped=next(b for b in city['buildings'] if b.get('o')=='w147350191')
c,s=math.cos(YAW),math.sin(YAW)
plan=[]
for x,z in mapped['f']:
    dx,dy=x-cx,-(z-cz)
    plan.append((dx*c+dy*s,-dx*s+dy*c))
prism('Mapped ground foundation',plan,-8,.12,pale)
prism('Mapped office tower backing',plan,LOBBY,TOP-.8,dark)
prism('Granite roof parapet',plan,TOP-.8,TOP,granite)

def facade(width,origin,angle,columns):
    before=set(bpy.context.scene.objects)
    pitch=width/columns
    floor=(TOP-2.2-LOBBY)/30
    for row in range(30):
        bottom=LOBBY+row*floor
        mechanical=row in (9,22)
        for col in range(columns):
            x=-width/2+(col+.5)*pitch
            mat=dark if mechanical else occupied if (row*7+col*11)%23 in (0,1,8) else glass
            box('Separate recessed vision pane',(x,.015,bottom+floor*.62),(pitch-.27,.04,floor*.69),mat)
            box('Bronze opaque spandrel',(x,.028,bottom+floor*.11),(pitch-.20,.065,floor*.22),bronze)
            box('Thin window sill',(x,.075,bottom+floor*.965),(pitch-.20,.12,.06),bronze)
    for col in range(columns+1):
        x=-width/2+col*pitch
        size=.44 if col%5==0 else .22
        box('Continuous deep granite rib',(x,.20,(LOBBY+TOP)/2),(size,.42,TOP-LOBBY),granite)
    box('Head cornice',(0,.18,TOP-.12),(width,.38,.24),granite)
    box('Recessed upper mechanical grille',(0,.015,TOP-1.45),(width,.045,1.45),dark)
    orient(set(bpy.context.scene.objects)-before,angle,origin)

# Each mapped edge is covered, including the eastern service projection.
if sum(x*v-y*u for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]))<0:plan.reverse()
for (x,y),(u,v) in zip(plan,plan[1:]+plan[:1]):
    width=math.hypot(u-x,v-y)
    if width<.25:continue
    columns=max(1,round(width/1.48))
    facade(width,((x+u)/2,(y+v)/2),math.atan2(v-y,u-x)+math.pi,columns)

# Lower floor recessed on Wacker and Adams, with load-bearing granite piers.
box('Lobby ceiling',(0,0,LOBBY-.12),(W,D,.24),pale)
for y in [-D/2+i*D/8 for i in range(9)]:
    box('West arcade granite pier',(-W/2+.25,y,LOBBY/2),(.75,.8,LOBBY),granite)
for x in [-W/2+i*W/4 for i in range(1,5)]:
    box('South arcade granite pier',(x,-D/2+.25,LOBBY/2),(.8,.75,LOBBY),granite)
box('North ground service wall',(2,D/2-.3,LOBBY/2),(W-4,.4,LOBBY),granite)
for y in (-17,17):
    box('Elevator bank stone core',(5,y,LOBBY/2),(12,14,LOBBY),pale)
    for x in (1,4,7):
        box('Recessed elevator door',(x,y-math.copysign(7.01,y),2), (1.35,.08,3.4),bronze)
box('Rear lobby wood wall',(11,0,LOBBY/2),(.16,19,LOBBY),wood)
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.55,depth=LOBBY-.12,location=(.5,0,(LOBBY+.12)/2))
bpy.context.object.name='White round lobby column'
bpy.context.object.data.materials.append(pale)
box('Dark lobby floor inset',(-3,0,.14),(10,10,.025),dark)
for x in range(-8,11,2):
    box('Lobby wood ceiling panel',(x,0,LOBBY-.28),(1.85,19,.065),wood)
    box('Exposed lobby linear light',(x,0,LOBBY-.322),(.07,16,.025),light)
for y in range(-27,28,3):
    box('Arcade ceiling strip',(-W/2+1.7,y,LOBBY-.255),(2.7,.13,.025),light)

def storefront(width,origin,angle):
    before=set(bpy.context.scene.objects)
    cols=max(1,round(width/2.4))
    pitch=width/cols
    for i in range(cols):
        x=-width/2+(i+.5)*pitch
        box('Arcade clear storefront pane',(x,0,3.05),(pitch-.07,.055,5.9),clear)
        box('Storefront transom',(x,.04,3.9),(pitch,.09,.075),bronze)
    for i in range(cols+1):
        box('Storefront bronze jamb',(-width/2+i*pitch,.05,3.05),(.08,.13,6),bronze)
    orient(set(bpy.context.scene.objects)-before,angle,origin)
storefront(D-8,(-W/2+4,0),math.pi/2)
storefront(W-4,(2,-D/2+4),math.pi)

# Renovated clear canopy and hanging address, without third-party logos.
box('West glass canopy',(-W/2-.8,0,4.65),(3.4,29.6,.08),clear)
box('Canopy front edge',(-W/2-2.5,0,4.65),(.15,29.6,.20),bronze)
for y in [-14.8+i*3.7 for i in range(9)]:
    box('Canopy cantilever rib',(-W/2-.8,y,4.64),(3.4,.12,.16),bronze)
    line('Canopy suspension tie',[(-W/2+.03,y,6),(-W/2-2.4,y,4.72)],.022,bronze)
text('Raised canopy address','125 SOUTH WACKER',(-W/2-2.6,0,5.12),.52,bronze,rotate=(math.pi/2,0,-math.pi/2))
box('Glass vestibule',(-W/2+3.4,0,1.9),(.045,5.4,3.8),clear)
for y in (-2.7,0,2.7):
    box('Entry jamb',(-W/2+3.35,y,1.9),(.16,.10,3.8),bronze)
    box('Entry pull',(-W/2+3.25,y+.7,1.7),(.1,.055,.9),bronze)
box('Reception desk stone',(3,-7,.9),(4,1.5,1.6),pale)
box('Reception desk wood plinth',(3,-7,.18),(4.1,1.6,.25),wood)
for y in (-2.8,2.8):
    box('Blue lounge seat',(-2,y,.55),(1.2,1.0,.25),blue)
    box('Blue lounge back',(-1.5,y,.9),(.2,1.0,.8),blue)
    for dy in (-.55,.55):box('Lounge arm',(-2,y+dy,.8),(1.25,.15,.45),blue)
box('Lobby coffee table',(-4,0,.65),(1.2,2.8,.12),wood)
for x in (-4.45,-3.55):
    for y in (-1.1,1.1):box('Coffee table leg',(x,y,.35),(.06,.06,.55),bronze)

# Measured rear roof steps are distinct from the 126.5 m street-facing parapet.
# Raw roof cells rise to 141.5 m; identification of rear plant is approximate.
box('Central raised roof service deck',(1.5,4,127.6),(9,32,3),dark)
box('Rear tall mechanical enclosure',(12,4.5,133.8),(16,29.5,15.4),dark)
for z in [127+i*.75 for i in range(19)]:
    box('Rear plant louver slat',(3.94,4.5,z),(.1,29.5,.14),bronze)
    box('Rear plant louver slat',(12,19.30,z),(16,.12,.14),bronze)
box('Rear mechanical cap',(12,4.5,141.4),(16.15,29.65,.2),granite)
finish('wacker_125',OUT)
