"""323 Michigan historical exterior draft; primary Shriners photograph.
Dimensions and current facade are unverified. Not integrated into the game.
"""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Pale stone upper frontage',(.63,.60,.53),roughness=.85)
dark=material('Dark polished ground stone',(.12,.11,.105),roughness=.42)
glass=material('Separate recessed sash panes',(.16,.21,.23),roughness=.55)
metal=material('Dark window sash and doors',(.09,.085,.07),metallic=.35)
clear=material('Clear recessed entrance glazing',(.25,.3,.32),roughness=.5)
clear.diffuse_color=(.25,.3,.32,.18)
back=material('Opaque interior backing',(.05,.05,.045),roughness=.95)
brick=material('Plain side and rear masonry',(.35,.29,.23),roughness=.95)
roof=material('Flat roof and parapet cap',(.28,.28,.26),roughness=.95)
W,D,H=18.5,24.4,14.5 # Approximate frontage fit; height is not surveyed.
box('Foundation',(0,0,-4),(W,D,8),dark)
box('Upper interior',(0,.6,9.9),(W-1,D-1.2,9.2),back)
box('Ground interior behind vestibule',(0,1.0,2.65),(W-1,D-3,5.3),back)
for side in [-1,1]:
    box('Side masonry',(side*(W/2-.15),0,H/2),(.3,D,H),brick)
box('Rear masonry',(0,D/2-.15,H/2),(W,.3,H),brick)
# Front in local -Y; export becomes Godot +Z. Rotate at placement to Michigan.
front=-D/2
for floor in [1,2]:
    low=5.3+(floor-1)*4.0
    pitch=W/7
    for bay in range(7):
        x=-W/2+(bay+.5)*pitch
        box('Continuous vertical stone pier',(x-pitch/2,front,low+2),(pitch*.28,.65,4),stone)
        box('Stone spandrel',(x,front,low+.48),(pitch*.75,.5,.96),stone)
        box('Inset individual window',(x,front+.26,low+2.35),(pitch*.68,.04,2.75),glass)
        for dx in [-pitch*.34,0,pitch*.34]:
            box('Raised sash stile',(x+dx,front+.13,low+2.35),(.055,.12,2.8),metal)
        for z in [low+.96,low+2.35,low+3.72]:
            box('Raised sash rail',(x,front+.13,z),(pitch*.7,.12,.055),metal)
        box('Recessed sill',(x,front-.12,low+.94),(pitch*.76,.35,.12),stone)
box('End stone pier',(W/2,front,9.3),(.5,.65,8),stone)
box('Solid upper frieze',(0,front,13.9),(W+.25,.55,1.2),stone)
box('Parapet cap',(0,front-.08,14.45),(W+.4,.7,.1),roof)
# Backing is farther inside than the clear doors; retain a real portal opening.
for side in [-1,1]:
    box('Ground flank',(side*5.25,front,2.65),(8,.7,5.3),dark)
    for x in [side*4.1,side*7.0]:
        box('Small base inset pane',(x,front-.36,2.0),(1.05,.04,1.15),glass)
        for dx in [-.57,.57]:box('Base window surround',(x+dx,front-.42,2),(.1,.15,1.4),stone)
box('Entrance head',(0,front,4.7),(2.6,.7,1.2),dark)
box('Vestibule back',(0,front+2,2.05),(2.5,.15,4.1),back)
box('Clear separate doors',(0,front+1.1,1.95),(2.35,.04,3.9),clear)
for x in [-1.2,0,1.2]:box('Door stiles',(x,front+1,1.95),(.07,.12,3.9),metal)
text('Raised address','323',(0,front-.4,4.4),.28,stone)
box('Solid flat roof',(0,0,H-.12),(W,D,.24),roof)
finish('michigan_323',OUT)
