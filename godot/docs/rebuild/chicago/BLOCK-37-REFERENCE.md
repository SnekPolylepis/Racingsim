# Block 37 candidate — 2026-10-08

Mapped w124865494 is the next unmodeled candidate under investigation:
TRACKSIDE-PRIORITY.csv gives 9.3 m horizontal boundary distance on Grid.
The mapped polygon spans approximately 102 by 119 m; city.json assigns
138.5 m height to the compound. Do not extrude the whole retail block to that
height: retail podium and later tower must be distinguished before authoring.
An editable Blender draft and staged native review now exist; production
integration and route clearance are not yet validated.

Primary project pages read:
- https://www.weoneil.com/project/block-37/
- https://www.gensler.com/projects/block-37
- https://scb.com/project/block-37/
- https://www.blockthirtyseven.com/

W.E. O’Neil describes a four-story retail podium surrounding a central atrium,
transparent ground/corner facades and horizontally woven steel exterior panels.
Its construction scope anticipated later towers. SCB identifies Marquee as the
later residential component. The operator confirms 108 North State Street.
Separate these components using actual photos and mapped building parts;
published project descriptions alone do not establish current roof geometry,
heights, bay counts or the exact tower footprint. W.E. O’Neil gallery exterior images1/3 and SCB’s full tower photograph were
visually inspected in this pass. Retain mapped footprint and validate route
clearance and native visibility before installing a replacement.

Next: validate retained footprint against both routes, refine podium
entrance/glazing/strip coverage and tower crown, then integrate and run full checks.
No export, route change, rendering or lap-validation claim at this checkpoint.

## Editable draft and native evidence

Generator tools/blender/chicago_block_37.py exports block_37.glb and
editable tools/blender/authored/block_37.blend:189984tri/seven materials.
Retained compound foundation at(-357.2,8,104.25). Roof raster distinguishes
north tower x[-405,-317]/z[47,73], southern office x[-403,-336]/z[125,161]
and low retail podium. These simplified upper envelopes and130/80/26m heights
are provisional raster/photo fits, not surveyed dimensions. Four podium rows,
37 residential shaft rows and17 office rows give physical recessed panes,
mullions and rails.48 bowed strip rows approximate woven podium cladding;
coverage/module shape still needs refinement. No external photo is embedded.

Native Mac Godot4.6.2 Forward+ High Grid baseline and staged draft captures
completed exit0/empty stderr. Both draft day/night images actually inspected,
retained in screenshots/chicago-block37-draft-mac. The baseline confirms the
compound is excluded (city3794/authored route clearance). Draft is injected
only by ignored visual-review/block37-draft.gd; production game is unchanged.
First capture exposed opaque upper backing over recessed panes; inset backing
fixed it, final day/night panes/night switching inspected. Blender regeneration
and native editor import exit0/empty stderr; Python syntax and diff checks pass.
Generator asserts polygon bounds, facade pitch, batched topology and backing
clearance. No whole-track clipping, new laps, performance or release claim.

Open: retained-foundation clearance, actual entrance portals/canopies/signage,
central atrium roof opening, podium module placement, asymmetric tower inset
shapes/crown, office roof services and wider measured proportions. This draft
is not a finished exterior. Route versions/cache remain v7/v5/cache188.
