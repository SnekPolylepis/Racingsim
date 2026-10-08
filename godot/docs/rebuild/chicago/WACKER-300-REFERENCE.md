# 300 South Wacker — next close trackside candidate

Current native5m candidate list places w1473501786.4m from Grid station5895.
Candidate distance is not a visibility guarantee or placement acceptance.
Mapped foundation has nine points, x[-1068.8,-1042],z[758.1,828.8],height133m.
Retain all mapped points when authoring and test actual route clearance.

Primary references reviewed2026-10-08:
- [Epstein original architect archive](https://www.epsteinglobal.com/news/throwback-thursday-300-south-wacker):35storeys,440ft(134.112m),69ft(21.0312m)by230ft(70.104m),bronze aluminum/bronze glass,granite plaza and blank river elevator wall. Mechanical level19 plus penthouse. Historical dimensions must be reconciled with mapped outline.
- [Current owner site](https://www.300southwacker.com/):35storeys, current exterior images and brochure/gallery links.
- [Design project record](https://segd.org/projects/300-south-wacker-drive/):river-facing map mural and entry/lobby redesign; inspect current references before authoring those details.

No authored model or new placement claim at this reference checkpoint.

2026-10-08 authoring underway: original twelve-material92614tri exterior uses
retained nine-point foundation, real bronze window recesses/mullions,
mechanical louvers, clear renovated lobby and original physical map linework.
See assets/chicago/landmarks/WACKER-300-SOURCES.md for approximations.
Initial34geometry/night/glazing checks pass; final source renders and both
full clearance scans pending. No acceptance claim from candidate distance alone.

Current final route follows mapped South Wacker road controls(-1038.4,747.8)
and(-1031.1,811.5), with western South connector(-1028,887.1). Native1m
foundation clearance11.509m on both layouts; native5m candidate distance11.6m
Grid5895. Original@v7/Grid@v5/cache180 supersede earlier6.4m placement evidence.
No foundation displacement, clipping exemption or surface-width reduction.
Both full clip scans pass after easing the connector: Grid103/original120
accepted overhead hits, zero failures. Final evidence is recorded below.


### 2026-10-08 — 300 South Wacker exterior and mapped approach

Physical Wacker300 at(-1055.4,8,793.45) replaces generic w147350178 exactly
once. Retained nine-point foundation;92614tri/twelve materials; original Blender
source and GLB. Bronze mullions/spandrels frame individual recessed panes,
physical mechanical louvers, revised clear lobby with spaced granite columns,
ceiling/portal/stairs and correctly oriented extruded300 address. River core
has original physical map linework and red locator; low roof service cabinets.
Owner/architect/SEGD references in WACKER-300-SOURCES.md. Mapped133m differs
from architect440ft/134.112m; height, mural cartography, exact entrance/mechanical
levels and roof configuration remain provisional. No embedded reference photo.

First full Grid scan exposed two foundation overlaps atstations5885/5890:
the old racing straight was too far west beside the mapped13m South Wacker
road. Shared points() now follows mapped(-1038.4,747.8),(-1031.1,811.5), and
world(row) places the western South connector(-1028,887.1). Other connector
and ramp placements/elevations preserved; geographic-source rows unchanged.
Authored widths/grades/easing, not a road-survey claim. A trial879.3 control
made the final16m-wide corner too tight: two tarmac misses and low fence
intrusions. Removed that point; the larger corner now passes full-width tests.
No building displacement, shortened foundation or road-width reduction.
Original@v7/Grid@v5 separate altered drivable surfaces from prior saves;
cache180. NativeCurve3D lengths7859.992/8488.778m; not RoadBuilder station lengths.
Native1m foundation clearance11.509m both routes; finite and greater than10m.
Candidate CSV refreshed236 within50m from native5m samples:30011.6/Grid5895,
3117.7/Grid6170,Brooks14.8/Grid6160,garage14.6/Grid6135,22514.5/original6765.
Prior237 snapshot remains dated evidence. Candidate count is not completion.

Mac Godot4.6.2/M4 Metal Forward+ final37 headless Chicago suites pass112.0s;
parse separately passes0.6s. Includes building38, menu115, both road geometry49,
Brooks31, Franklin25, authoredcoverage23 and all other Chicago exterior checks.
Both full native5m/five-offset clip scans pass after corner easing: Grid103,
original120 accepted overhead hits, zero failures, exit0/empty stderr.
Grid passed the stricter preceding rule. Scan now also recognizes Upper Wacker
fences only over a lower roadway with hitheight>=7.9m; low/street-level fences
and Wacker300 remain failures. Four explicit guardrail/building assertions pass.
No broad Wacker building exemption; wall probes remain active.

Sixteen final actual High source images inspected: eight Grid street/river/
entry/building-facing views and eight original/Grid approach/corner views,
each day/night. All eight final two-view jobs exit0/empty stderr, five awaited
frames plus frame_post_draw per image. Earlier combined8-view and4-view night
jobs hit180s; completed partial images informed revisions, not completion claims.
Final images in rebuild/screenshots/chicago-wacker300-mac/ and
chicago-wacker300-route-mac/. Frozen renders prove appearance, not frame time.

Remaining trackside exteriors and finer civic sculpture remain open. Next close
candidate311SouthWacker has primary architect/contractor references in
chicago/WACKER-311-REFERENCE.md; its octagonal tower and winter garden need
an authored exterior. River bridges stay queued. No export, manual wheel run,
Intel hardware, broad full-game or performance validation at this checkpoint.

Allfivecars/both handling modes on both layouts complete20cleanlap cases,
zerooff-road/wall/prop ticks, finite successful laps. Ten bounded per-car jobs,
max2concurrent, exit0/empty stderr; lap harness has0props. All16 stored timing
references remain within unchanged2% tolerance; four original Formula cases
still have no timing baseline. No baseline rewritten. Logs mac-civic/wacker300-*.
These runs validate the corrected route, not visual-only screenshots or manual
wheel driving. The full trackside-model objective remains active.
