# Track generation

Generators for the game's TrackAssets (REBUILD-PLAN.md §5.3). Each `trackgen/<id>.gd` has a static
`build_asset()` that builds and validates the circuit from its data. The game builds it on first load and
caches the bake in `user://tracks3d/` (scripts/proving/track_drive.gd `load_asset()`), and the tests build
it in memory. Baked scenes are not committed.

| Generator | Circuit | Data |
|---|---|---|
| `proving_ground.gd` | Invented ~2.5 km test circuit: bowl, crest, compression, off-camber, concrete ditch, every kerb type | none (authored in code; design in docs/rebuild/proving-ground-P5-02.md) |
| `spa.gd` | Spa-Francorchamps | `data/spa/`: OSM centreline, SPW LiDAR elevation and cross-sections, widths and kerbs measured from SPW 2023 orthophotos (see its README) |
| `nordschleife_s1.gd` | Nürburgring Nordschleife section 1, T13 to Aremberg, with a return road | `data/nordschleife/`: OSM centreline, Rhineland-Palatinate DGM1 (see its README) |

`spa_drive_smoke.gd` is a short headless drive on Spa. Each data folder holds its source licences,
`sources.json` and the scripts that rebuild every derived file from its public source. Raw downloads are
git-ignored caches.

Rules for a new circuit are in docs/LLM-GUIDE.md ("New TrackAsset"): keep the RoadPath bank change under
0.20°/m, leave the terrain's under-road drop tapered, and give it a clean bot lap in tests/v2/laps.gd.

The pre-rebuild JSON circuit pipeline (Overpass and OpenTopoData scripts, `runoff.gd`, `karussell.gd`,
`jumps.gd`) was retired with the legacy game in P7-01; it survives in git history.

## Licences

- **Centrelines:** © OpenStreetMap contributors, ODbL 1.0.
- **Spa elevation and orthophotos:** © Service public de Wallonie (SPW), CC BY 4.0.
- **Nordschleife elevation:** © GeoBasis-DE / LVermGeoRP 2026, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet].

Full titles, sources and modifications are in THIRD-PARTY.md.
