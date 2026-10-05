"""DePaul CDM exterior draft from owner and restoration-contractor photos."""
import bpy,sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,text,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
terra=material('Pale terracotta piers and spandrels',(.65,.64,.59),roughness=.9)
trim=material('Projecting terracotta cornices',(.57,.57,.53),roughness=.85)
glass=material('Separate recessed dark sash panes',(.12,.17,.18),roughness=.55)
metal=material('Dark metal sash and transoms',(.065,.07,.07),metallic=.2)
clear=material('Clear inset storefront and entry glass',(.24,.28,.29),roughness=.5)
clear.diffuse_color=(.24,.28,.29,.18)
back=material('Opaque recessed interior backing',(.055,.055,.045),roughness=.95)
roof=material('Roof and rear masonry',(.29,.27,.23),roughness=.95)
sign=material('Blue university signboards',(.035,.085,.20),roughness=.85)
W,D,H=52.2,29,39 # Approximate footprint fit and photo proportions, not survey height.
box('Foundation',(0,0,-4),(W,D,8),terra)
box('Inset interior core',(.9,.9,H/2),(W-2.6,D-2.6,H),back)
box('Plain north party wall',(0,D/2-.15,H/2),(W,.3,H),roof)
box('Plain east party wall',(W/2-.15,0,H/2),(.3,D,H),roof)

def part(face,name,u,z,w,h,depth,t,mat):
    if face=='south':return box(name,(u,-D/2+depth,z),(w,t,h),mat)
    return box(name,(-W/2+depth,u,z),(t,w,h),mat)

def window(face,u,z,w,h):
    part(face,'Separate inset sash glazing',u,z,w,h,.48,.04,glass)
    for edge in [-w/2,w/2]:part(face,'Physical sash stile',u+edge,z,.06,h,.31,.13,metal)
    for edge in [-h/2,.05,h/2]:part(face,'Physical sash rail',u,z+edge,w,.065,.31,.13,metal)
    part(face,'Projecting pane sill',u,z-h/2-.1,w+.15,.16,-.1,.38,trim)

for face,length,bays in [('south',W,9),('west',D,5)]:
    pitch=length/bays
    for edge in range(bays+1):
        u=-length/2+edge*pitch
        width=.65 if edge in [0,bays] else 1.1
        if edge==0:u+=width/2
        if edge==bays:u-=width/2
        part(face,'Full-height facade pier',u,22.5,width,33,-.02,.7,terra)
    # Seven office rows, grouped triples above and edge singles in middle section.
    for row in range(7):
        z=12.1+row*3.95
        part(face,'Solid office spandrel',0,z-1.65,length,1.05,0,.65,terra)
        for bay in range(bays):
            u=-length/2+(bay+.5)*pitch
            columns=[-.30* pitch,0,.30*pitch]
            if row<4 and bay in [0,bays-1]:columns=[-.28*pitch,.28*pitch]
            for offset in columns:window(face,u+offset,z,1.23,2.5)
            # Slender opaque wall divisions between individual panes.
            centres=[u+c for c in columns]
            low=u-pitch/2+.55
            for centre in centres:
                hi=centre-.615
                if hi>low:part(face,'Solid terracotta window divider',(low+hi)/2,z,hi-low,2.9,0,.65,terra)
                low=centre+.615
            hi=u+pitch/2-.55
            if hi>low:part(face,'Solid terracotta window divider',(low+hi)/2,z,hi-low,2.9,0,.65,terra)
    # Mezzanine row of separate narrow windows above two-height retail openings.
    part(face,'Mezzanine sill band',0,6.45,length,.55,0,.75,terra)
    part(face,'Mezzanine head band',0,9.75,length,.65,0,.75,terra)
    for i in range(bays*3):
        u=-length/2+(i+.5)*length/(bays*3)
        window(face,u,8.15,1.16,2.35)
        part(face,'Mezzanine masonry divider',u-length/(bays*3)/2,8.15,.38,2.8,0,.65,terra)
    for z in [10.15,25.65,38.55]:
        part(face,'Continuous projecting cornice',0,z,length+.25,.24,-.22,1.05,trim)
    part(face,'Upper parapet',0,38.0,length,2.0,0,.65,terra)
    # Open storefront bays, backing farther inside than transparent glazing.
    for bay in range(bays):
        u=-length/2+(bay+.5)*pitch
        if face=='west' and bay==0:
            part(face,'Entry upper transom glass',u,4.78,pitch-1.0,2.2,.5,.05,clear)
            for side in [-1,1]:part(face,'Entry flanking clear pane',u+side*1.99,1.8,.8,3.3,.5,.05,clear)
        else:part(face,'Recessed retail glazing',u,3.05,pitch-1.0,5.7,.5,.05,clear)
        for edge in [-pitch/2+.5,0,pitch/2-.5]:part(face,'Retail metal stile',u+edge,3.05,.09,5.7,.34,.15,metal)
        part(face,'Retail horizontal transom',u,3.7,pitch-1.0,.17,.34,.15,metal)
        part(face,'Retail stone pier',u-pitch/2+.27,3.05,.54,6.1,0,.8,terra)
        part(face,'Stone storefront base',u,.15,pitch,.3,0,.8,terra)
    # Main doors in the west frontage's southern bay; actual sign/door fit approximate.
    if face=='west':
        u=-length/2+pitch*.5
        part(face,'Deep clear entrance doors',u,1.8,3.1,3.3,1.25,.04,clear)
        part(face,'Vestibule opaque back',u,2.05,3.8,4.1,2.6,.15,back)
        for offset in [-1.55,0,1.55]:part(face,'Recessed door stiles',u+offset,1.8,.08,3.3,1.1,.16,metal)
    # Two signboards near the southwest corner, as in owner photograph.
    u=(-length/2+pitch) if face=='south' else (-length/2+pitch)
    part(face,'University signboard',u,6.35,pitch*1.35,.8,-.58,.18,sign)
    if face=='south':text('University raised lettering','DEPAUL UNIVERSITY',(u,-D/2-.70,6.35),.31,terra)
    else:text('University raised lettering','DEPAUL UNIVERSITY',(-W/2-.70,u,6.35),.31,terra,rotate=(math.pi/2,0,-math.pi/2))
box('Flat roof',(0,0,H-.25),(W,D,.3),roof)
finish('depaul_cdm',OUT)
