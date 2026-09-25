# Chicago city asset staging (rb/CHI-assets-prep, 2026-09-25)

Not integrated into any generator, scene, gate, or export. A materials library for whoever next works on
dressing the Chicago circuit (CHI-01, `rb/CHI-01-chicago`) or its surrounding city — models, textures
and a wider street/building/water map than CHI-01's own route-only OSM pull, staged on this branch so
they don't have to re-source them. Nothing here has been wired into `trackgen/chicago.gd`; that file
belongs to CHI-01 and was not touched.

CHI-01 itself (reviewed here, not modified) built its whole circuit — the two Wacker decks, the five
required landmarks (the Bean, Willis Tower, Navy Pier, plus Michigan Avenue and the river/lake) — as
"original procedural low-poly artwork," no downloaded models or textures at all
(`trackgen/data/chicago/README.md`, "All city/landmark geometry is original procedural low-poly
artwork"). That's consistent with this project's house style elsewhere (scenery_builder.gd's
SurfaceTool-built armco/grandstands/pit buildings), but it means there is no facade texture variety and
no background city beyond the authored corridor. This staging area is raw material for closing that gap,
should a future task want to.

## Contents

- **`models/`** — three Kenney CC0-1.0 kits, GLB format only (FBX/OBJ duplicates dropped), each with its
  own `colormap.png` and `License.txt`:
  - `kenney-city-kit-commercial/` (41 GLBs) — low-poly office towers, skyscrapers and low-detail LOD
    variants, storefront awnings/overhangs. The most direct fit for Loop/Streeterville background
    massing.
  - `kenney-city-kit-roads/` (95 GLBs) — traffic lights, curved/square street lamps, electricity
    poles/wires, road signs, bridge pillars, a dumpster, construction barriers/cones/fencing. This pack
    also ships full road-tile geometry (straight/bend/intersection/roundabout pieces); that's included
    but not expected to be used — this project generates its own road mesh from RoadPath/RoadBuilder, so
    only the street-furniture props are likely relevant.
  - `kenney-car-kit/` (50 GLBs) — sedan/SUV/taxi/delivery/van/truck for parked-car street dressing (an
    NFSU/GT4 city track staple this circuit doesn't have yet), plus ambulance/firetruck/police/
    garbage-truck for city-service variety. Also carries kart/race-car/crash-debris models that aren't
    relevant to this task.

  Kenney's `racing-kit` (a 2D isometric sprite pack, not 3D models) was downloaded and evaluated but not
  committed: its cartoon/vector art style doesn't match this game's photographic-source PS2-era look
  (ART-DIRECTION.md), unlike the crossed-card tree/undergrowth atlases which use real photo cutouts.

- **`textures/`** — ten ambientCG CC0-1.0 PBR materials at 1K, Color/NormalGL/Roughness(/Metalness)
  JPGs only (Displacement, AmbientOcclusion and the `.blend`/`.usdc`/`.mtlx`/`.tres`/preview files
  ambientCG also ships were dropped): two glass curtain-wall facades (`Facade001`, `Facade009`), plaza
  concrete (`Concrete034`), Loop-era brick (`Bricks097`), Michigan Avenue limestone/travertine
  (`Travertine009`), Chicago-School glazed terracotta (`GlazedTerracotta001`), Lower Wacker structural
  corrugated steel (`CorrugatedSteel009`), weathered metal (`Metal063`), painted steel
  (`PaintedMetal004`), and granite curbing/paving (`Granite002A`). No water surface material — ambientCG
  has no tileable water photo texture; river/lake water in this game is better done as a shader effect
  than a photo material, the same way the game's other surfaces are (`shaders/`).

- **`roadmap/`** — four raw Overpass/OSM JSON extracts covering the full downtown area (not just the
  named route streets CHI-01's own `osm-roads.json` pulled): the complete road network, every building
  footprint, the river/lake/parks, and named landmarks. See `roadmap/README.md` for the exact queries,
  license (ODbL 1.0) and the lon/lat-to-local-metres formula that lines this up with CHI-01's circuit.

- **`sources.json`** — one entry per download (pack or texture or Overpass query), its URL, licence and
  the sha256 of the original archive/response, in this repo's existing `assets/cc0-source/sources.json`
  format.

## Not here

- **Drafts for lighting and particle effects** (a neon-marquee shader sketch, a steam-grate particle
  emitter sketch) are at `docs/rebuild/chicago-prep/drafts/`, not under `assets/`, since they're authored
  sketches rather than downloaded source material — see that folder's own note.
- No baking, no atlas packing, no `THIRD-PARTY.md` entry yet — this directory itself is excluded from
  export (`export_presets.cfg`'s `exclude_filter` already covers `assets/cc0-source/*`), so nothing here
  reaches a packaged build regardless. A future task that actually bakes/integrates any of this should
  record it in `THIRD-PARTY.md` (both copies, root and `build/`) the way Look-6/Look-10 did for the tree
  and undergrowth atlases.
- Total footprint: ~48 MB (models ~11 MB, textures ~21 MB, roadmap JSON ~16 MB).
