"""City Hall / County paired halves: original geometry from HABS dimensions and municipal photos."""
import bpy, math, sys, json, random
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from architecture import material, box, mesh, arch, line, text, finish
OUT=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
stone=material('Woodbury grey granite',(.57,.57,.53),roughness=.9)
trim=material('Pale granite and terra cotta relief',(.67,.66,.60),roughness=.85)
dark=material('Dark terra cotta spandrels and sashes',(.13,.14,.13),roughness=.78)
glass=material('Separate recessed blue grey sash panes',(.17,.24,.27),roughness=.55)
back=material('Opaque recessed backing and unsurveyed courts',(.26,.25,.23),roughness=.95)
roof=material('Roof slab and coping',(.31,.32,.30),roughness=.95)
H=62.484 # HABS205ft coping; WJE rounded200ft differs. See reference limits.
county='--county' in sys.argv
bronze=material('Clark bronze door and transom frames' if county else 'LaSalle bronze door and transom frames',(.37,.27,.13),metallic=.45,roughness=.55)
cx,cz=(-579.65,106.8) if county else (-626,106.35)
data=json.loads((Path(__file__).resolve().parents[2]/'trackgen/data/chicago/city.json').read_text(encoding='utf-8'))
foot=next(b['f'] for b in data['buildings'] if b.get('o')==('w108240968' if county else 'w108240964'))
ring=[(x-cx,cz-z) for x,z in foot]
def prism(name,z,h,mat,scale=1):
 r=[(x*scale,y*scale) for x,y in ring];n=len(r)
 return mesh(name,[(x,y,z-h/2) for x,y in r]+[(x,y,z+h/2) for x,y in r],
  [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
prism('Exact mapped foundation',-4,8,back)
prism('Inset irregular opaque backing',H/2 if county else (H-1)/2,H-.6 if county else H-1,back,.90)
prism('Mapped roof retaining eastern court notches',H-.25,.5,roof) if county else prism('City roof deck below coping',H-1,.4,roof)
# Three continuous public elevations; eastern reentrant walls retain mapped geometry.
faces=([('south',foot[21],foot[0],7),('north',foot[1],foot[2],7),('east',foot[0],foot[1],18)]
 if county else [('south',foot[0],foot[2],7),('north',foot[19],foot[20],7),('west',foot[20],foot[0],18)])
for name,aa,bb,cols in faces:
 a=(aa[0]-cx,cz-aa[1]);b=(bb[0]-cx,cz-bb[1])
 length=math.dist(a,b);origin=((a[0]+b[0])/2,(a[1]+b[1])/2,0);angle=math.atan2(b[1]-a[1],b[0]-a[0])
 def placed(obj):
  obj.location=Vector(origin)+Matrix.Rotation(angle,3,'Z')@obj.location
  obj.rotation_euler.z+=angle
  return obj
 def part(label,x,z,w,h,d,t,mat):return placed(box(label,(x,d,z),(w,t,h),mat))
 def tube(label,x,d,lo,hi,r0,r1,mat,fluted=False):
  count=80 if fluted else 24
  verts=[]
  for z,r in [(lo,r0),(hi,r1)]:
   for i in range(count):
    theta=2*math.pi*i/count;radius=r*(1-.075*(1+math.cos(theta*20))/2 if fluted else 1)
    verts.append((x+radius*math.cos(theta),d+radius*math.sin(theta),z))
  return placed(mesh(label,verts,[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)],mat))
 pitch=length/cols;ww=pitch*.66
 # ponytail: public bay counts and horizontal spacing are photo-fit estimates, not measured elevations.
 for row in range(3):
  low=row*7.112
  entry_row=name==('east' if county else 'west') and row==0
  if entry_row:
   for sign in [-1,1]:part('Base band outside LaSalle entrances',sign*(length/4+pitch),low+.95,length/2-2*pitch,1.9,0,.6,stone)
  else:part('Rusticated base solid band',0,low+.95,length,1.9,0,.6,stone)
  for c in range(cols):
   x=(c-(cols-1)/2)*pitch
   if entry_row and abs(x)<2*pitch:continue
   for s in range(3):
    px=x+(s-1)*ww/3
    part('Individual base sash glazing',px,low+4.15,ww/3-.10,4.30,1.08,.035,glass)
    for z in [low+2,low+4.1,low+6.3]:part('Base sash transom and meeting rail',px,z,ww/3,.075,.87,.15,dark)
   for dx in [-ww/2,-ww/6,ww/6,ww/2]:part('Base window dark stile',x+dx,low+4.15,.085,4.3,.87,.15,dark)
   for dx in [-ww/2-.16,ww/2+.16]:part('Deep stone base window surround',x+dx,low+4.15,.32,4.8,.12,.55,trim)
   part('Base window stone lintel',x,low+6.55,ww+.64,.35,.12,.55,trim)
  for c in range(cols+1):
   x=-length/2+c*pitch
   if entry_row and abs(x)<2*pitch:continue
   part('Rusticated base pier',x,low+4.35,pitch-ww,4.9,0,.65,stone)
   for z in [low+2.2,low+3.4,low+4.6,low+5.8]:part('Physical shallow rustication joint',x,z,pitch-ww,.025,-.34,.025,dark)
 if name==('east' if county else 'west'):
  # LaSalle Ajay Suresh2021 / Clark Ian Abbott2014: three stone portals and bronze glazing.
  # ponytail: portal/sculpture proportions are photo-fit, not measured relief surfaces.
  for sign in [-1,1]:part('Solid outer entrance masonry',sign*1.84*pitch,3.15,.32*pitch,6.3,0,.65,stone)
  for x in [-pitch,0,pitch]:
   opening=pitch*.64
   for dx in [-opening/2-.34,opening/2+.34]:
    part('LaSalle portal outer stone jamb',x+dx,3.15,.68,6.3,-.38,.95,trim)
    for offset in [0,.16]:part('Nested portal jamb moulding',x+dx+(.20-offset)*(1 if dx<0 else -1),3.1,.075,6.2,-.92-offset*.5,.12,trim)
   for z,w,h,d,t in [(6.35,opening+1.4,.5,-.38,.95),(6.73,opening+1.65,.25,-.54,1.20),(7.02,opening+1.8,.24,-.62,1.3)]:
    part('Layered portal lintel and projecting cornice',x,z,w,h,d,t,trim)
   for dx in [-opening/2+.12,opening/2-.12]:part('Recessed portal stone reveal',x+dx,3.15,.24,6.3,.63,1.5,stone)
   part('Deep portal ceiling',x,6.10,opening,.25,.63,1.5,stone)
   part('Portal threshold',x,.10,opening,.20,.63,1.5,stone)
   for c in range(4):
    px=x+(c-1.5)*opening/4
    part('Recessed bronze entry door glazing',px,1.65,opening/4-.09,3.1,1.40,.04,glass)
    part('Tall separate entrance transom glazing',px,4.62,opening/4-.09,2.4,1.40,.04,glass)
    part('Entrance transom vertical bronze bar',px+opening/8,4.62,.06,2.5,1.18,.14,bronze)
   for dx in [-opening/2,-opening/4,0,opening/4,opening/2]:part('Bronze entrance door stile',x+dx,1.65,.075,3.2,1.18,.16,bronze)
   for z in [.13,3.2,3.4,5.87]:part('Entrance bronze horizontal rail',x,z,opening,.12,1.18,.16,bronze)
   for dx in [-.15,.15]:part('Physical door pull',x+dx,1.55,.055,.65,1.03,.08,bronze)
   part('Portal central stone pendant',x,6.28,.52,1.25,-.94,.3,trim)
   for c in range(15):placed(arch('Portal lintel repeated circular ornament',.065,.10,(x+(c-7)*(opening+1.1)/15,6.74),-1.17,.04,trim,0,2*math.pi,12))
  for x in [-1.5*pitch,-.5*pitch,.5*pitch,1.5*pitch]:
   width=pitch*.36-.1
   part('Stone pier between LaSalle portals',x,3.15,width,6.3,0,.65,stone)
   for dx in [-width/2+.06,width/2-.06]:part('Relief panel outer border',x+dx,3.65,.12,3.9,-.36,.15,trim)
   for z in [1.70,5.60]:part('Relief panel horizontal border',x,z,width,.14,-.36,.15,trim)
   def relief(label,px,z,w,h,depth=.12,d=-.48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(px,d,z))
    obj=bpy.context.object;obj.name=label;obj.scale=(w/2,depth,h/2)
    obj.data.materials.append(trim)
    for polygon in obj.data.polygons:polygon.use_smooth=True
    return placed(obj)
   def stroke(label,points,r=.055):
    return placed(line(label,[(x+px,-.65,z) for px,z in points],r,trim))
   if county and abs(x)>pitch:
    # Municipal7347: paired standing figures, oval County seal and plaque.
    # ponytail: sculpted silhouettes are photo-fit; fine anatomy/seal lettering need closer reference.
    part('County relief recessed stone field',x,3.65,width-.22,3.65,-.35,.08,stone)
    part('County sculpture shared plinth',x,1.97,width-.35,.18,-.54,.28,trim)
    for sign in [-1,1]:
     px=x+sign*width*.31
     relief('County standing figure head',px,5.03,.32,.42,.16)
     relief('County standing figure hair',px+sign*.035,5.14,.37,.35,.13,-.43)
     relief('County standing figure torso',px,4.42,.50,.84,.19)
     relief('County standing figure draped hip',px,3.80,.46,.65,.16)
     relief('County standing figure long robe',px+sign*.12,3.00,.32,1.76,.11)
     for leg in [-1,1]:
      relief('County standing figure shin',px+leg*.105,2.72,.16,1.39,.16)
      relief('County standing figure foot',px+leg*.105,2.08,.22,.15,.22)
     stroke('County raised arm towards seal',[(sign*width*.31,4.66),(sign*.37,4.88),(sign*.25,4.95)],.10)
     stroke('County outer supporting arm',[(sign*width*.34,4.60),(sign*width*.43,4.22),(sign*width*.40,4.10)],.09)
     relief('County figure nose',px,5.02,.075,.10,.065,-.66)
     stroke('County figure mouth',[(sign*width*.31-.06,4.92),(sign*width*.31+.06,4.92)],.018)
     for fold in [-1,0,1]:stroke('County robe fold',[(sign*width*.31+fold*.07,3.8),(sign*width*.31+fold*.08,2.25)],.023)
    relief('County oval seal stone tablet',x,3.82,.92,1.92,.12)
    oval=arch('County oval seal raised rim',.43,.50,(0,0),-.67,.08,trim,0,2*math.pi,40)
    for vertex in oval.data.vertices:vertex.co.x+=x;vertex.co.z=vertex.co.z*1.92+3.82
    placed(oval)
    part('County seal central shield',x,3.72,.46,.62,-.64,.09,trim)
    for stripe in range(5):part('County seal shield vertical division',x+(stripe-2)*.075,3.70,.018,.39,-.71,.035,stone)
    stroke('County seal eagle spread wings',[(-.30,4.08),(-.16,4.23),(0,4.13),(.16,4.23),(.30,4.08)],.065)
    relief('County seal eagle head',x,4.28,.11,.13,.07,-.70)
    stroke('County seal lower scroll',[(-.30,3.29),(0,3.18),(.30,3.29)],.055)
    for sign in [-1,1]:stroke('County seal lower curled ornament',[(sign*.38,3.1),(sign*.51,2.82),(sign*.27,2.48),(0,2.55)],.085)
    part('County Building plaque backing',x,1.43,width*.70,.38,-.41,.10,dark)
    placed(text('County Building plaque lettering','COUNTY\nBUILDING',(x,-.49,1.43),.17,bronze,depth=.012))
   if county and abs(x)<pitch:
    # Abbott2014 Clark frontage: two single seated figures, not the outer paired seals.
    # ponytail: small held attributes are unresolved in the oblique reference; refine with a closeup.
    sign=-1 if x<0 else 1
    part('County seated relief backing',x,3.65,width-.22,3.65,-.35,.08,stone)
    part('County seated figure projecting plinth',x,2.03,width*.72,.26,-.55,.42,trim)
    relief('County seated head',x+sign*.17,4.90,.36,.45,.18,-.59)
    relief('County seated hair',x+sign*.18,5.03,.40,.23,.15,-.56)
    relief('County seated nose in profile',x+sign*.32,4.86,.13,.14,.08,-.77)
    relief('County seated neck',x+sign*.10,4.62,.21,.21,.17,-.54)
    relief('County seated shoulder mantle',x,4.46,.73,.35,.21,-.57)
    relief('County seated chest',x,4.12,.59,.72,.23,-.57)
    relief('County seated folded lap',x-sign*.08,3.50,.68,.47,.23,-.60)
    relief('County seated bent thigh',x+sign*.30,3.38,.73,.36,.27,-.66)
    relief('County seated knee',x+sign*.53,3.23,.33,.36,.26,-.66)
    relief('County seated foreground shin',x+sign*.47,2.75,.24,.90,.24,-.61)
    relief('County seated rear calf',x-sign*.12,2.67,.28,.99,.18,-.53)
    for dx in [-.12,.47]:relief('County seated foot',x+sign*dx,2.15,.32,.15,.26,-.61)
    relief('County seated chair drapery',x-sign*.29,2.93,.41,1.29,.16,-.52)
    stroke('County seated bent inner arm',[(sign*.29,4.47),(sign*.49,4.05),(sign*.13,3.84)],.095)
    stroke('County seated lowered outer arm',[(-sign*.29,4.42),(-sign*.47,4.05),(-sign*.40,3.66)],.095)
    for fold in [-.22,-.05,.13]:stroke('County seated robe fold',[(sign*fold,3.60),(sign*(fold-.05),3.00),(sign*(fold+.06),2.20)],.026)
    for fold in [-.18,0,.18]:stroke('County shoulder mantle fold',[(fold,4.51),(fold-.08,4.22),(fold-.05,4.03)],.023)
   if not county:
    # Suresh2021 full frontage and Diesterheft2007 water figure: four distinct compositions.
    # ponytail: photo-fit bas-relief anatomy; finer faces and occluded attributes remain provisional.
    part('City relief recessed stone field',x,3.65,width-.22,3.65,-.35,.08,stone)
    part('City relief projecting plinth',x,1.96,width-.32,.18,-.54,.34,trim)
    seated=abs(x)<pitch
    hx=x+(.13 if seated else .02);head_z=4.90 if seated else 5.06
    relief('City relief head',hx,head_z,.36,.45,.19,-.58)
    relief('City carved hair mass',hx-.035,head_z+.14,.39,.22,.15,-.54)
    relief('City facial nose',hx-.07,head_z-.03,.10,.16,.085,-.79)
    for dx in [-.095,.09]:relief('City facial brow',hx+dx,head_z+.025,.11,.055,.03,-.765)
    relief('City relief neck',hx,head_z-.27,.18,.19,.15,-.54)
    relief('City shoulder span',x,4.48,.75,.32,.21,-.55)
    relief('City tapered torso',x,4.12,.57,.85,.20,-.54)
    relief('City draped hips',x,3.58,.63,.54,.21,-.53)
    if seated:
     relief('City seated projecting bent thigh',x+.30,3.37,.78,.35,.25,-.64)
     relief('City seated knee',x+.53,3.22,.31,.33,.24,-.66)
     relief('City seated front shin',x+.49,2.68,.23,.92,.23,-.61)
     relief('City seated rear shin',x-.10,2.62,.25,1.12,.17,-.51)
     relief('City seat drapery',x-.24,2.91,.45,1.36,.18,-.52)
     for dx in [-.25,-.10,.04]:stroke('City seat drapery fold',[(dx,3.45),(dx-.08,2.55),(dx-.03,2.15)],.024)
    else:
     relief('City standing left leg',x-.18,2.75,.30,1.55,.19,-.56)
     relief('City standing right leg',x+.22,2.80,.29,1.55,.19,-.55)
     for dx in [-.18,.22]:relief('City standing ankle',x+dx,2.14,.18,.24,.19,-.54)
    for dx in ([-.1,.49] if seated else [-.18,.22]):relief('City relief foot',x+dx,2.05,.30,.14,.25,-.60)
    if x< -pitch:
     # Adult with smaller figure and long horizontal attribute in full frontage.
     stroke('City adult outstretched arm',[(0,4.54),(.35,4.39),(.80,4.56)],.105)
     stroke('City adult lowered arm',[(-.25,4.42),(-.49,4.02),(-.34,3.72)],.10)
     relief('City smaller figure head',x-.53,4.18,.25,.30,.15,-.75)
     relief('City smaller figure body',x-.52,3.69,.32,.59,.17,-.69)
     stroke('City smaller figure bent leg',[(-.51,3.41),(-.74,3.09),(-.67,2.40)],.095)
     stroke('City smaller figure straight leg',[(-.39,3.44),(-.34,2.97),(-.45,2.25)],.08)
     stroke('City horizontal sculptural attribute',[(-.57,4.24),(.65,4.27),(.79,4.42)],.065)
    elif x<0:
     # Seated draped figure; preserve silhouette without inventing obscured handheld object.
     relief('City seated dress',x,3.35,.73,1.20,.14,-.57)
     stroke('City seated bent arm',[(-.28,4.47),(-.43,4.03),(-.13,3.87)],.09)
     stroke('City seated lap arm',[(.28,4.44),(.48,3.95),(.08,3.65)],.09)
     for dx in [-.22,0,.22]:stroke('City seated dress fold',[(dx,3.82),(dx+.05,3.10),(dx-.09,2.15)],.028)
    elif x<pitch:
     # Water-supply man: seated, raised right hand and a tipped handled vessel to the left.
     for dx in [-.14,.14]:relief('City water figure chest',x+dx,4.31,.29,.29,.075,-.73)
     for z in [4.05,3.89]:relief('City water figure abdomen',x,z,.27,.15,.04,-.72)
     stroke('City water raised arm',[(.27,4.47),(.61,4.50),(.70,4.92),(.48,4.83)],.105)
     stroke('City water vessel arm',[(-.25,4.45),(-.52,4.06),(-.76,3.91)],.105)
     relief('City water amphora body',x-.62,3.39,.52,.57,.22,-.61)
     stroke('City water amphora neck',[(-.67,3.62),(-.78,3.83),(-.88,3.86)],.075)
     placed(arch('City water amphora handle',.14,.19,(x-.47,3.61),-.80,.07,trim,-math.pi*.4,math.pi*.8,20))
     for i in range(3):stroke('City flowing water carving',[(-.85+i*.055,3.74),(-.96+i*.07,3.26),(-.82+i*.07,2.98)],.025)
    else:
     relief('City standing draped robe',x-.11,3.18,.65,1.85,.14,-.56)
     stroke('City branch bearer raised arms',[(-.40,4.80),(0,4.99),(.56,4.91),(.77,5.22)],.09)
     stroke('City held branch',[(-.83,5.31),(-.37,5.39),(.25,5.28),(.87,5.37)],.045)
     for i in range(7):
      relief('City branch carved leaf',x+(i-3)*.21,5.31+(i%2)*.10,.22,.105,.04,-.70)
     for dx in [-.25,-.05,.15]:stroke('City standing robe fold',[(dx,3.87),(dx+.14,3.03),(dx-.04,2.12)],.027)
    if abs(x)>pitch:
     part('City Hall outer relief plaque',x,1.43,width*.68,.30,-.41,.10,dark)
     placed(text('City Hall plaque lettering','CITY HALL',(x,-.49,1.43),.17,bronze,depth=.012))
 for z,w in [(20.9,.35),(21.336,.55),(22.5,.22)]:part('Base projecting continuous belt',0,z,length,w,-.14,.95,trim)
 for row in range(6):
  low=22.5+row*4.58
  part('Dark relief spandrel behind colonnade',0,low+.72,length,1.44,.82,.18,dark)
  for c in range(cols):
   x=(c-(cols-1)/2)*pitch
   for s in range(3):
    px=x+(s-1)*ww/3
    part('Separate upper sash pane',px,low+3.0,ww/3-.10,2.85,1.12,.035,glass)
    for z in [low+1.57,low+2.1,low+3.2,low+4.42]:part('Upper sash physical rail',px,z,ww/3,.075,.88,.15,dark)
    # Circular wreath relief from municipal closeup, simplified to physical rings.
    placed(arch('Spandrel wreath relief',.22,.30,(px,low+.70),.65,.1,trim,0,2*math.pi,16))
   for dx in [-ww/2,-ww/6,ww/6,ww/2]:part('Upper triple window stile',x+dx,low+3,.10,3.0,.88,.18,dark)
  for c in range(cols+1):
   part('Stone wall behind columns',-length/2+c*pitch,low+3,pitch-ww,3.2,.30,.5,stone)
 # HABS column base6ft, shaft75.5ft, capital12.5ft, diameter9ft.
 for c in range(1,cols):
  x=-length/2+c*pitch
  tube('Column moulded plinth',x,-.70,21.336,22.1,1.65,1.65,trim)
  tube('Column base torus profile',x,-.70,22.1,23.1648,1.50,1.3716,trim)
  tube('Tall tapered fluted granite shaft',x,-.70,23.1648,46.1772,1.3716,1.23,stone,True)
  tube('Corinthian capital basket',x,-.70,46.1772,49.35,1.23,1.65,trim)
  for tier in range(3):
   for leaf in range(8):
    theta=2*math.pi*(leaf+.5*(tier%2))/8
    r=1.3+tier*.15;z=46.6+tier*.8
    obj=mesh('Raised stylized acanthus leaf',[(x+(r+rr)*math.cos(theta+da),-.7+(r+rr)*math.sin(theta+da),z+dz) for rr,da,dz in [(0,-.16,0),(0,.16,0),(.35,.10,.65),(.45,0,.95),(.35,-.10,.65)]],[(0,1,2,3,4)],trim)
    placed(obj)
  part('Corinthian square abacus',x,49.66,3.7,.65,-.70,3.7,trim)
 for x in [-length/2+1,length/2-1]:part('Colonnade corner pilaster',x,35.65,2,28.65,-.10,.8,stone)
 part('Solid upper entablature',0,53.64,length,7.3152,0,.6,stone)
 for z in [50.1,51.15,56.9]:part('Upper projecting frieze band',0,z,length,.32,-.15,.9,trim)
 for c in range(cols*3):
  x=(c-(cols*3-1)/2)*length/(cols*3)
  placed(arch('Upper circular frieze relief',.22,.32,(x,54.8),-.39,.09,trim,0,2*math.pi,16))
 part('Attic lower masonry band',0,58.15,length,1.7,0,.5,stone)
 part('Attic upper parapet',0,61.55,length,1.6,0,.5,stone)
 for c in range(cols):
  x=(c-(cols-1)/2)*pitch
  for dx in [-.6,.6]:part('Small separate attic pane',x+dx,59.9,.75,1.6,.55,.035,glass)
 for c in range(cols+1):part('Attic pier',-length/2+c*pitch,59.9,pitch-2.1,1.9,0,.5,stone)
 part('Coping without removed historic cornice',0,62.25,length,.468,-.06,.7,trim)
for i in range(2,21 if county else 19):
 a,b=ring[i],ring[i+1];length=math.dist(a,b)
 obj=box('Unsurveyed mapped courtyard wall',(0,0,H/2),(length,.30,H),back)
 obj.rotation_euler.z=math.atan2(b[1]-a[1],b[0]-a[0]);obj.location=((a[0]+b[0])/2,(a[1]+b[1])/2,0)
if not county:
 # Pyszka/City aerial published by USGS2019; dimensions/configuration are photo-fit, not surveyed.
 meadow=material('City roof sedum meadow',(.24,.34,.10),roughness=1)
 herbs=material('City roof mixed herb foliage',(.36,.42,.13),roughness=1)
 metal=material('City roof galvanized ducts and rails',(.48,.51,.51),metallic=.55,roughness=.72)
 deck=H-.8
 prism('City pale service walk surface',deck+.035,.07,trim)
 def inside(px,py):
  result=False
  for a,b in zip(ring,ring[1:]+ring[:1]):
   if (a[1]>py)!=(b[1]>py) and px<(b[0]-a[0])*(py-a[1])/(b[1]-a[1])+a[0]:result=not result
  return result
 rng=random.Random(1911)
 bed_vertices=[];bed_faces=[];herb_vertices=[];herb_faces=[]
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
 template=bpy.context.object
 herb_shape=[tuple(v.co) for v in template.data.vertices]
 herb_polys=[tuple(p.vertices) for p in template.data.polygons]
 bpy.data.objects.remove(template,do_unlink=True)
 for ix in range(-40,40):
  gx=ix*.5
  for iy in range(-106,108):
   gy=iy*.5
   if not all(inside(gx+dx,gy+dy) for dx in [-.25,.25] for dy in [-.25,.25]):continue
   bed=gx<-8 or abs(gy)>32
   if not bed:continue
   if abs(gy-30)<1.2 or abs(gy+30)<1.2:continue
   if abs(gy)>32 and abs(math.hypot((gx-2)*1.2,abs(gy)-43)-7.5)<.75:continue
   if gx<-8 and abs(gx-(-13+2*math.sin(gy*.11)))<.5:continue
   base=len(bed_vertices)
   bed_vertices.extend((gx+dx,gy+dy,deck+z) for z in [.06,.24] for dx,dy in [(-.249,-.249),(.249,-.249),(.249,.249),(-.249,.249)])
   bed_faces.extend(tuple(base+i for i in face) for face in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
   if rng.random()<.65:
    hx=gx+rng.uniform(-.20,.20);hy=gy+rng.uniform(-.20,.20)
    sx=rng.uniform(.22,.45);sy=rng.uniform(.22,.45);sz=rng.uniform(.12,.45)
    base=len(herb_vertices)
    herb_vertices.extend((hx+x*sx,hy+y*sy,deck+.32+z*sz) for x,y,z in herb_shape)
    herb_faces.extend(tuple(base+i for i in face) for face in herb_polys)
 mesh('City planted bed substrates',bed_vertices,bed_faces,meadow)
 mesh('City roof low varied herb clumps',herb_vertices,herb_faces,herbs)
 for px,py,w,d,h in [(-6,-17,5,13,3.6),(-1,0,18,11,4.8),(-6,17,5,13,3.6),(-8,16,3,3,7.0)]:
  box('City raised rooftop mechanical room',(px,py,deck+h/2),(w,d,h),stone)
  box('City mechanical room coping',(px,py,deck+h+.12),(w+.25,d+.25,.24),trim)
  for side in [-1,1]:
   box('City roof room separate window',(px+side*w*.26,py-d/2-.021,deck+2),(.95,.04,1.40),glass)
   for dx in [-.5,.5]:box('City roof room sash stile',(px+side*w*.26+dx,py-d/2-.06,deck+2),(.075,.10,1.55),dark)
   box('City roof room sash meeting rail',(px+side*w*.26,py-d/2-.06,deck+2),(1.05,.10,.075),dark)
 for px,py in [(-6,-17),(-6,17),(-1,0)]:
  top=deck+(4.8 if py==0 else 3.6)
  box('City louvered mechanical unit',(px,py,top+1.35),(4,4,2.7),metal)
  for z in range(12):box('City mechanical physical louver',(px,py-2.05,top+.2+z*.20),(3.8,.14,.065),dark)
  box('City galvanized duct riser',(px-2.6,py,top+.75),(1.2,2,1.5),metal)
  box('City duct horizontal elbow',(px-1.9,py,top+1.45),(2.4,2,.65),metal)
  for dx in [-3,3]:
   for dy in [-2.8,2.8]:line('City roof service railing upright',[(px+dx,py+dy,top),(px+dx,py+dy,top+1.1)],.035,metal)
  line('City roof service perimeter rail',[(px-3,py-2.8,top+1.1),(px+3,py-2.8,top+1.1),(px+3,py+2.8,top+1.1),(px-3,py+2.8,top+1.1),(px-3,py-2.8,top+1.1)],.035,metal)
finish('county_building' if county else 'city_hall',OUT)
