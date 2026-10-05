"""Chapin & Gore exterior draft from City of Chicago facade/detail photos."""
import bpy, math, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
brick=material('Warm brick piers and spandrels',(.40,.245,.17),roughness=.95)
terra=material('Terracotta frames and relief',(.36,.30,.235),roughness=.85)
stone=material('Ground stone surrounds',(.52,.46,.37),roughness=.85)
glass=material('Separate recessed upper panes',(.15,.205,.22),roughness=.55)
metal=material('Dark sash and storefront metal',(.09,.085,.075),metallic=.25)
clear=material('Clear recessed retail and doors',(.24,.29,.30),roughness=.5)
clear.diffuse_color=(.24,.29,.30,.18)
back=material('Opaque interior backing',(.045,.045,.04),roughness=.95)
roof=material('Flat roof and coping',(.25,.25,.23),roughness=.95)
W,D,H=24.5,24.5,36.5 # Footprint fit; height not independently surveyed.
f=-D/2
box('Foundation',(0,0,-4),(W,D,8),brick)
box('Inset interior core',(0,1.2,H/2),(W-1,D-3.2,H),back)
for side in [-1,1]:box('Plain party wall',(side*(W/2-.2),0,H/2),(.4,D,H),brick)
box('Plain rear wall',(0,D/2-.2,H/2),(W,.4,H),brick)
pitch=W/4
# Four full-height brick bays. Build walls around apertures, retain depth.
for edge in range(5):
    x=-W/2+edge*pitch
    width=1.55
    if edge in [0,4]:
        width=.775
        x+=.3875 if edge==0 else -.3875
    box('Vertical brick pier',(x,f,21.15),(width,.8,29.3),brick)
for z,h in [(6.1,1.2),(14.8,1.5),(18.65,1.45),(22.5,1.45),(26.35,1.45),(30.2,1.45),(34.4,2.15)]:
    box('Brick spandrel',(0,f,z),(W,.8,h),brick)

def pane(x,z,w,h):
    box('Separate inset pane',(x,f+.46,z),(w,.05,h),glass)
    for dx in [-w/2,-w*.26,w*.26,w/2]:
        box('Physical window stile',(x+dx,f+.33,z),(.08,.16,h),metal)
    for dz in [-h/2,h*.20,h/2]:
        box('Physical window rail',(x,f+.33,z+dz),(w,.16,.07),metal)
    box('Projecting sill',(x,f-.13,z-h/2-.08),(w+.25,.45,.16),terra)

for bay in range(4):
    x=-W/2+(bay+.5)*pitch
    for z in [16.75,20.6,24.45,28.3,32.15]:pane(x,z,pitch-1.55,2.4)
    # Paired lower windows within tall ornamental panel.
    for sign in [-1,1]:
        box('Solid brick beside lower aperture',(x+sign*2.02,f,10.3),(.54,.8,7.3),brick)
    pane(x,8.2,3.5,2.45)
    pane(x,12.4,3.5,2.65)
    box('Relief spandrel panel',(x,f-.06,10.25),(3.65,.28,1.35),terra)
    for dx in [-2.45,2.45]:
        box('Tall relief frame',(x+dx,f-.16,10.5),(.2,.24,7.25),terra)
        for i in range(30):
            box('Inset frame tooth',(x+dx,f-.3,7.05+i*.23),(.15,.12,.065),terra)
    for z in [6.9,14.05]:box('Relief frame crosspiece',(x,f-.16,z),(5.1,.28,.22),terra)
    for i in range(6):
        xx=x-1.48+i*.59
        box('Relief square',(xx,f-.24,10.25),(.38,.12,.52),terra)
        for sign in [-1,1]:
            ob=box('Diagonal relief lattice',(0,0,0),(.52,.10,.075),terra)
            ob.location=(xx,f-.34,10.25)
            ob.rotation_euler[1]=sign*math.pi/4
    for dx in [-1.82,1.82]:box('Lower window corbel',(x+dx,f-.25,6.83),(.38,.5,.36),terra)
box('Projecting lower cornice',(0,f-.2,14.55),(W+.3,.75,.22),terra)
for i in range(80):box('Small cornice tooth',(-W/2+(i+.5)*W/80,f-.3,14.35),(.10,.28,.22),terra)
# Ground openings: two inset end doors and broad central display panes.
box('Ground head',(0,f,5.05),(W,.85,.9),stone)
box('Ground plinth',(0,f,.2),(W,.85,.4),stone)
for x,w in [(-11.75,1),(-8,1.2),(-2.9,.5),(2.9,.5),(8,1.2),(11.75,1)]:
    box('Ground stone pier',(x,f,2.65),(w,.85,4.5),stone)
for x in [-9.95,9.95]:
    box('Recessed entry doors',(x,f+1,2.25),(2.45,.05,4.1),clear)
    box('Vestibule backing',(x,f+2.4,2.25),(2.8,.15,4.5),back)
    for dx in [-1.25,0,1.25]:box('Door stile',(x+dx,f+.87,2.25),(.09,.15,4.1),metal)
    box('Door header',(x,f+.87,4.3),(2.6,.15,.12),metal)
for x in [-5.35,0,5.35]:
    box('Separate storefront glass',(x,f+.45,2.65),(4.8,.05,4.4),clear)
    for dx in [-2.4,0,2.4]:box('Storefront mullion',(x+dx,f+.31,2.65),(.09,.16,4.4),metal)
    box('Storefront transom',(x,f+.31,3.8),(4.8,.16,.09),metal)
box('Roof slab',(0,0,H-.3),(W,D,.3),roof)
box('Plain upper parapet',(0,f,H-.6),(W,.65,1.2),brick)
for y in [f,D/2]:box('Roof coping',(0,y,H-.03),(W+.2,.65,.12),roof)
finish('chapin_gore',OUT)
