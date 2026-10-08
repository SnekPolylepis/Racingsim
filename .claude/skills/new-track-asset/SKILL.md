---
name: new-track-asset
description: Checklist for adding or changing a Racing Sim track generator (trackgen/*.gd) or any file a track reads at runtime. Use when creating a new track, adding track data/assets, or editing RoadPath banking/terrain.
---

# New or changed TrackAsset

Source of truth: `godot/docs/LLM-GUIDE.md` ("New TrackAsset (v2)") and `godot/docs/DATA-CONTRACTS.md` §5.3. Use `trackgen/spa.gd` or `trackgen/chicago.gd` as the pattern; don't invent a new structure.

## Geometry rules (hard)
- `trackgen/<id>.gd` with static `build_asset()` returning a validated TrackAsset: Surfaces on collision layer 1, Walls on layer 2, TimingLine, Grid, BotLine with smooth handles; optional Props/Scenery/Lights.
- RoadPath bank change **under 0.20°/m** (it warns above that). Positive bank lowers the right side.
- Keep the terrain's **tapered under-road drop**.
- SI units; body frame +X forward, +Y up, +Z right.

## Runtime files — miss one and the exported build breaks
Every file the track reads at runtime must be in **both**:
- [ ] every preset's `include_filter` in `godot/export_presets.cfg` (there are several presets — update all)
- [ ] `check_exported_v2_assets()` in `godot/scripts/game.gd`

`res://` is read-only in exports: never save beside packaged resources.

## Wiring
- [ ] id in `tests/v2/laps.gd` TRACKS; record baseline with `-- --record`
- [ ] a probe like Spa's: racing line on tarmac, no trenches beside the road
- [ ] the v2 front end's track list
- [ ] source data under `trackgen/data/<id>/` with licence + rebuild scripts; raw downloads cached outside git
- [ ] attribution in `THIRD-PARTY.md` and `build/THIRD-PARTY.md`

Then run the `verify` skill.
