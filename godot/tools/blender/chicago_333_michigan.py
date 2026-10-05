"""Original 333 North Michigan exterior draft; Blender +Y north/+Z up.
City/Goettsch photographs and owner floor plans guide authored geometry.
"""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, mesh, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Buff limestone vertical piers',(.64,.60,.50),roughness=.84)
trim=material('Pale limestone Art Deco crown',(.73,.68,.57),roughness=.82)
granite=material('Polished dark purple granite retail base',(.13,.105,.12),roughness=.42)
band=material('Dark terracotta vertical spandrels',(.25,.235,.205),roughness=.75)
glass=material('Separate recessed office panes',(.14,.19,.21),roughness=.5)
night=material('Night occupied office panes',(.23,.19,.125),roughness=.5,glow=.3)
bronze=material('Restored bronze entrance and sash',(.39,.29,.12),metallic=.65,roughness=.5)
iron=material('Dark decorative entrance grille',(.05,.047,.04),metallic=.3,roughness=.6)
clear=material('Clear retail and vestibule glazing',(.26,.32,.35),roughness=.5)
clear.diffuse_color=(.26,.32,.35,.18)
back=material('Opaque inset interior backing',(.065,.064,.06),roughness=.95)
roof=material('Grey roof terrace',(.25,.255,.23),roughness=.95)
W,D,H=18.5,59.5,120.7
batch={}
def box(name,p,size,mat):
    vertices,faces=batch.setdefault(mat.name,([],[]));start=len(vertices)
    vertices.extend([(p[0]+x*size[0]/2,p[1]+y*size[1]/2,p[2]+z*size[2]/2)
        for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]])
    faces.extend([tuple(start+i for i in face) for face in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
def flush():
    for name,(vertices,faces) in batch.items():mesh(name,vertices,faces,bpy.data.materials[name])
    batch.clear()
def orient(before,p,angle):
    flush();c,s=math.cos(angle),math.sin(angle)
    for obj in set(bpy.context.scene.objects)-before:
        x,y,z=obj.location;obj.location=(p[0]+x*c-y*s,p[1]+x*s+y*c,z);obj.rotation_euler.z+=angle
def outline(width,depth,centre=0,chamfer=1.4):
    return [(-width/2,centre-depth/2),(width/2,centre-depth/2),
        (width/2,centre+depth/2-chamfer),(width/2-chamfer,centre+depth/2),
        (-width/2+chamfer,centre+depth/2),(-width/2,centre+depth/2-chamfer)]
def prism(name,plan,lo,hi,mat):
    n=len(plan)
    mesh(name,[(x,y,z) for z in [lo,hi] for x,y in plan],
        [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
pitch_height=(H-8.8)/32
def level(floor):return 4.4*floor if floor<2 else 8.8+(floor-2)*pitch_height
prism('Mapped foundation',outline(W,D),-8,.1,granite)

# Original broad slab through level25; much smaller tower by level30.
# Exact intermediate setbacks are photo-derived approximations.
tiers=[(0,25,W,D,0),(25,28,17,26,16.75),(28,32,14.5,21,16.75),(32,34,12.0,18,16.75)]
for lo_floor,hi_floor,width,depth,centre in tiers:
    lo,hi=level(lo_floor),level(hi_floor)
    plan=outline(width,depth,centre)
    # The lower west vestibule must remain open behind transparent doors.
    if lo_floor==0:
        prism('Opaque upper slab',outline(width-1.4,depth-1.4,centre),8.8,hi-.3,back)
        box('Retail backing behind vestibule',(.65,0,4.4),(width-2.7,depth-1.4,8.8),back)
        for low_y,high_y in [(-depth/2+.7,10.5),(15.5,depth/2-.7)]:
            box('Retail side backing',(-width/2+1, (low_y+high_y)/2,4.4),(.6,high_y-low_y,8.8),back)
        flush()
    else:prism('Opaque setback tower',outline(width-1.4,depth-1.4,centre),lo,hi-.3,back)
    for edge,A in enumerate(plan):
        B=plan[(edge+1)%len(plan)];dx,dy=B[0]-A[0],B[1]-A[1];length=math.hypot(dx,dy)
        angle=math.atan2(dy,dx);before=set(bpy.context.scene.objects)
        bays=max(1,round(length/2.85));pitch=length/bays
        west=abs(A[0]+width/2)<.01 and abs(B[0]+width/2)<.01
        for i in range(bays):
            at=(i+.5)*pitch
            world_y=A[1]+dy*at/length
            entrance=west and lo_floor==0 and abs(world_y-13)<2.45+pitch/2
            for floor in range(lo_floor,hi_floor):
                low,high=level(floor),level(floor+1);height=high-low
                if entrance and floor<2:
                    # Clip the entire bay against the physical portal interval;
                    # matching centres alone leaves adjacent glazing in its jambs.
                    portal=A[1]-13
                    for left,right in [(at-pitch/2,min(at+pitch/2,portal-2.45)),
                                       (max(at-pitch/2,portal+2.45),at+pitch/2)]:
                        if right>left:
                            box('Granite beside restored entrance',((left+right)/2,0,(low+high)/2),
                                (right-left,.65,height),granite)
                    continue
                pane_width=pitch*.58 if floor>=2 else pitch*.82
                facing=granite if floor<2 else stone
                box('Continuous limestone pier',(at-pitch/2,0,(low+high)/2),(pitch-pane_width,.6,height),facing)
                box('Dark recessed vertical spandrel',(at,.16,low+height*.17),(pane_width,.27,height*.34),
                    granite if floor==0 else (iron if floor==1 else band))
                pane=clear if floor<2 else (night if (floor*11+i*7+edge)%23 in [1,5,9] else glass)
                box('Individual recessed window',(at,.25,low+height*.66),(pane_width-.12,.04,height*.59),pane)
                box('Double hung meeting rail',(at,.15,low+height*.66),(pane_width,.16,.07),iron)
                for side in [-1,1]:box('Physical window jamb',(at+side*(pane_width-.04)/2,.1,low+height*.66),(.065,.17,height*.62),iron)
                box('Stone window sill',(at,-.17,low+height*.35),(pane_width+.18,.4,.1),facing)
        box('End stone pier',(length,0,(max(lo,8.8)+hi)/2),(.5,.6,hi-max(lo,8.8)),stone)
        if lo_floor==0:box('Granite corner base',(length,0,4.4),(.5,.6,8.8),granite)
        box('Setback parapet',(length/2,0,hi-.25),(length+.3,.55,.5),trim)
        orient(before,A,angle)
    prism('Solid terrace roof',plan,hi-.32,hi-.2,roof)

# Restored Michigan doorway: raised metalwork and separate clear vestibule doors.
before=set(bpy.context.scene.objects)
for side in [-1,1]:
    box('Granite entrance jamb',(side*2.15,0,4.4),(.6,1.0,8.8),granite)
    box('Bronze entrance stile',(side*1.79,.28,3.3),(.12,.18,6.6),bronze)
box('Entry back wall',(0,1.75,4.4),(4.2,.18,8.8),back)
box('Separate glazed doors',(0,1.1,1.8),(3.5,.04,3.4),clear)
for x in [-1.72,0,1.72]:box('Door metal stiles',(x,1.0,1.8),(.08,.18,3.6),bronze)
box('Tall entrance transom',(0,.36,4.7),(3.5,.04,2.2),clear)
box('Bronze upper grille backing',(0,.35,7.3),(3.5,.12,2.8),bronze)
for x in range(-7,8):box('Physical upper grille bars',(x*.22,.17,7.3),(.045,.12,2.8),iron)
for ring in [1.0,.76]:
    line('Raised oval Art Deco medallion',[(ring*.56*math.cos(i*math.pi/24),-.02,7.3+ring*.82*math.sin(i*math.pi/24)) for i in range(49)],.035,iron)
for side in [-1,1]:
    box('Entrance vertical lamp housing',(side*2.15,-.57,2.6),(.2,.22,1.3),bronze)
    for x in [-.055,.055]:box('Lamp diffuser',(side*2.15+x,-.71,2.6),(.045,.08,1.1),trim)
text('Raised address','333',(0,.17,4.3),.35,bronze)
box('Entry threshold',(0,.8,.1),(4.1,2.3,.2),granite)
orient(before,(-W/2,13),-math.pi/2)
flush()
finish('michigan_333',OUT)
