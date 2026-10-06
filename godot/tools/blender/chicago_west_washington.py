"""170/166 West Washington: authored frontages from Visviva's 2020 photograph."""
import bpy,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material,box,finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
for address,W,D,H,rows,cols in [(170,12.5,27.9,17.0,3,5),(166,12.8,30.6,29.0,6,3)]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 brick=material('Red brick piers and spandrels',(.38,.18,.13),roughness=.95)
 pale=material('Pale projecting panels and stone',(.72,.70,.59),roughness=.9)
 glass=material('Separate recessed opaque window panes',(.12,.17,.18),roughness=.65)
 metal=material('Physical dark sash and storefront frames',(.07,.08,.075),metallic=.2)
 back=material('Opaque interior backing',(.035,.04,.04),roughness=1)
 rear=material('Unsurveyed party and rear masonry',(.28,.23,.19),roughness=.95)
 box('Foundation',(0,0,-4),(W,D,8),brick)
 box('Interior backing',(0,.65,H/2),(W-.6,D-1.8,H),back)
 box('Rear wall',(0,D/2-.15,H/2),(W,.3,H),rear)
 for x in [-W/2+.15,W/2-.15]:box('Party wall',(x,0,H/2),(.3,D,H),rear)
 box('Roof',(0,0,H-.15),(W,D,.3),rear)
 def front(name,x,z,w,h,depth,thickness,mat):
  box(name,(x,-D/2+depth,z),(w,thickness,h),mat)
 step=(H-5.2)/rows
 pitch=(W-1.0)/cols
 aperture=1.25 if address==170 else 2.65
 window_h=step-.95
 for edge in range(cols+1):
  x=-cols*pitch/2+edge*pitch
  front('Solid facade pier',x,(H+5)/2,pitch-aperture,H-5,0,.55,pale if address==170 else brick)
 for row in range(rows):
  z=5.2+step*(row+.5)
  front('Solid brick spandrel',0,z-step/2,W,.95,0,.55,brick if address==166 else pale)
  if address==170:
   for rib in range(65):
    front('Raised spandrel panel rib',-W/2+.15+rib*(W-.3)/64,z-step/2,.035,.92,-.31,.065,pale)
  for col in range(cols):
   x=(col-(cols-1)/2)*pitch
   front('Inset window pane',x,z,aperture,window_h,.42,.04,glass)
   for dx in [-aperture/2,0,aperture/2]:front('Window sash stile',x+dx,z,.055,window_h,.29,.10,metal)
   for dz in [-window_h/2,0,window_h/2]:front('Window sash rail',x,z+dz,aperture,.055,.29,.10,metal)
   if address==166:front('Projecting stone sill',x,z-window_h/2-.09,aperture+.22,.16,-.10,.62,pale)
 for x in [-W/2+.2,W/2-.2]:front('Brick edge pier',x,(H+5)/2,.4,H-5,-.04,.65,brick)
 front('Parapet',0,H-.3,W,.6,0,.6,brick)
 front('Storefront head',0,4.7,W,.8,-.04,.65,metal if address==170 else brick)
 front('Ground plinth',0,.25,W,.5,0,.65,brick)
 for x in [-W/2+.22,-2.0,2.0,W/2-.22]:front('Storefront pier',x,2.35,.44,4.7,0,.7,brick)
 for x in [-4.1,4.1]:
  front('Inset storefront glazing',x,2.35,3.45,3.7,.48,.045,glass)
  for dx in [-1.73,-.58,.58,1.73]:front('Storefront vertical sash',x+dx,2.35,.075,3.8,.30,.14,metal)
  for z in [.55,3.4,4.2]:front('Storefront horizontal sash',x,z,3.45,.075,.30,.14,metal)
 front('Inset entrance backing',0,2.2,3.55,4.0,1.6,.08,back)
 for x in [-.82,.82]:
  front('Recessed door pane',x,2.0,1.5,3.4,1.0,.04,glass)
  for dx in [-.78,.78]:front('Door stile',x+dx,2.0,.08,3.5,.88,.14,metal)
  front('Door rail',x,1.6,1.5,.08,.82,.16,metal)
 if address==166:
  for x in [-1.9,1.9]:front('Pale entry surround',x,2.4,.30,4.8,-.1,.85,pale)
  front('Pale entrance lintel',0,4.55,4.1,.45,-.1,.85,pale)
 else:
  front('Black storefront sign fascia',0,4.35,W-.6,.75,-.20,.25,metal)
 # ponytail: photo-proportion heights and plain party walls; replace when surveyed references exist.
 finish('west_washington_'+str(address),OUT)
