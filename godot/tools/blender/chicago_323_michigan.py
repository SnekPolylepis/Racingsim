"""323 Michigan exterior draft; historical and current listing imagery.
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
W,D,H=24.4,18.5,14.5 # Approximate frontage fit; height is not surveyed.
box('Foundation',(0,0,-4),(W,D,8),dark)
box('Upper interior',(0,.6,9.9),(W-1,D-1.2,9.2),back)
box('Ground interior behind vestibule',(0,1.0,2.65),(W-1,D-3,5.3),back)
for side in [-1,1]:
    box('Side masonry',(side*(W/2-.15),0,H/2),(.3,D,H),brick)
box('Rear masonry',(0,D/2-.15,H/2),(W,.3,H),brick)
# Front in local -Y; export becomes Godot +Z. Rotate at placement to Michigan.
front=-D/2
pitch=W/7
for bay in range(7):
    x=-W/2+(bay+.5)*pitch
    box('Continuous tall stone pier',(x-pitch/2,front,9.3),(pitch*.28,.65,8),stone)
    box('Inset continuous upper glazing',(x,front+.26,9.55),(pitch*.68,.04,7.5),glass)
    for dx in [-pitch*.34,0,pitch*.34]:
        box('Raised tall sash stile',(x+dx,front+.13,9.55),(.055,.12,7.6),metal)
    for z in [5.8,7.7,9.55,11.4,13.3]:
        box('Separate sash rail',(x,front+.13,z),(pitch*.7,.12,.055),metal)
    box('Continuous aperture sill',(x,front-.12,5.72),(pitch*.76,.35,.16),stone)
    if bay in [1,2,3]:
        # Visible light horizontal screens in listing panorama; simplified slats.
        for row in range(28):
            box('Physical light window screen',(x,front+.08,5.95+row*.255),(pitch*.66,.08,.065),stone)
box('End stone pier',(W/2,front,9.3),(.5,.65,8),stone)
box('Solid upper frieze',(0,front,13.9),(W+.25,.55,1.2),stone)
box('Parapet cap',(0,front-.08,14.45),(W+.4,.7,.1),roof)
# Backing is farther inside than the clear doors; retain a real portal opening.
for side in [-1,1]:
    left,right=(1.25,W/2) if side>0 else (-W/2,-1.25)
    x=side*6.8; half=4.25
    box('Storefront base',((left+right)/2,front,.35),(right-left,.7,.7),dark)
    box('Storefront head',((left+right)/2,front,4.75),(right-left,.7,1.1),dark)
    for low,high in [(left,x-half),(x+half,right)]:
        if high>low:box('Storefront wall pier',((low+high)/2,front,2.45),(high-low,.7,3.5),dark)
    box('Recessed retail display glass',(x,front+.22,2.45),(8.5,.04,3.5),clear)
    for dx in [-4.25,-1.42,1.42,4.25]:
        box('Physical retail mullion',(x+dx,front+.08,2.45),(.08,.14,3.5),metal)
box('Entrance head',(0,front,4.7),(2.6,.7,1.2),dark)
box('Vestibule back',(0,front+2,2.05),(2.5,.15,4.1),back)
box('Clear separate doors',(0,front+1.1,1.95),(2.35,.04,3.9),clear)
for x in [-1.2,0,1.2]:box('Door stiles',(x,front+1,1.95),(.07,.12,3.9),metal)
text('Raised address','323',(0,front-.4,4.4),.28,stone)
box('Solid flat roof',(0,0,H-.12),(W,D,.24),roof)
finish('michigan_323',OUT)
