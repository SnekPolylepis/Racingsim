# Nordschleife scenery and trackside decor

You're working on a native Godot 4.6.2 racing game in `godot/`. Your task is **presentation only**: make the Nürburgring Nordschleife look like the real circuit, with named landmarks, corner-specific dressing and denser, more varied scenery. You must not change how the car drives.

Before editing, read `AGENTS.md`, `CLAUDE.md`, `godot/docs/LLM-GUIDE.md`, `godot/docs/ART-DIRECTION.md` and `godot/docs/DATA-CONTRACTS.md`. Where they conflict with this prompt, they win.

## Hard boundaries

- **Do not edit** `scripts/car.gd`, `scripts/track3d.gd`, `scripts/track.gd`, `scripts/collisions.gd`, `scripts/race.gd` or anything under `tests/` except to add a new test. The circuit editor (`scripts/editor.gd`) is frozen; don't touch it.
- New objects are **decorative**. They must not add collision, and they must not sit on the road or the runoff. Check placements with `track.project(x, y)` and keep `absf(pr.lat) > pr.width / 2 + margin`, as `build_furniture` in `scripts/circuit_world.gd` already does.
- **No real brands, logos or sponsor names.** Real place names such as corner names are fine. Board and signage text must be original and invented, following `ART-DIRECTION.md`.
- Assets must be procedural or CC0. Don't download or embed third-party models or textures unless they're CC0, and record anything added in `godot/THIRD-PARTY.md`.
- **Preserve line endings.** Some `.gd` files use CRLF and others use LF. Check with `file <path>` before editing and keep what's there. A whole-file line-ending change is a defect.

## How the world is built

- Circuit geometry is a 3-space ribbon (`scripts/track3d.gd`). Samples carry `pos`, `tan`, `right` and `up`, plus plan aliases `x`, `y`, `z`, `nx`, `ny`. `track.pos_at(s)` gives the centreline at arc distance `s`, including heading `h` and width `w`.
- **Coordinates.** Simulation space is `(x, y, z)`, with z as altitude. Godot space is `(x, z, y)`. Convert only at the rendering boundary.
- Place things on the ground with `world.ground_height(x, y)`. It handles the road, the verge blend and the terrain.
- `circuit_world.gd` builds the terrain, the road, `build_barriers` (armco, tyre walls, boards) and `build_furniture`. At the moment `build_furniture` places four generic grandstands at the four tightest corners. Nothing is placed by name.
- `visuals.gd::build_scenery` scatters trees from `presentation.scenery`, using a fixed RNG seed.
- Use **MultiMesh** for anything repeated, grouped into spatial batches as the existing code does, so the far side of the 20.8 km lap can be culled. Keep asset generation out of the physics step.
- Painted small textures come from `scripts/retro_assets.gd`, for example `painted("crowd")`.

## What to build

1. **A named-landmark system.** Add an optional `presentation.landmarks` array to the track document. Each entry needs a `kind` (for example `grandstand`, `spectator_bank`, `building`, `bridge`, `marshal_post`, `footbridge`, `hedge`), an anchor (a corner `label` name, or explicit `x`/`y`), a `side` (`left`/`right`/`outside`/`inside`, resolved from the sign of the curvature for the last two), an offset from the road edge, a length along the lap, and optional scale and variant. Build them in `circuit_world.gd` in a new function called from `build()`. Document the schema in `DATA-CONTRACTS.md`, next to `presentation.scenery`.
2. **Author landmarks for the Nordschleife** in `godot/tracks/Nurburgring-Nordschleife.json`. The corner labels, with coordinates, are in `presentation.labels`. Priorities:
   - **Ex-Mühle.** Research what is actually trackside there and represent it faithfully, within the art direction's low-poly budget.
   - **Caracciola-Karussell.** Spectator banking and trackside structures around the concrete bowl. The road there is a profiled ditch about 1.25 m deep on the inside, so check that nothing clips into it.
   - **The other famous spectator areas**, such as Brünnchen, Pflanzgarten and Adenauer Forst, plus any bridges over the circuit that you can verify.
   - Only include features you can support with a reference. Where you approximate, say so in the circuit's `presentation.description`, which already carries that caveat.
3. **Scenery.** The Nordschleife is almost entirely forest. Tune `presentation.scenery`, and if needed extend `build_scenery` with per-region variation such as clearings at spectator areas and denser woods elsewhere. Any extension must stay backward compatible, so Monza and Spa look exactly as they do now.
4. **Curbs.** The Nordschleife curbs are `#df3330` / `#ffffff` today. Check them against references. Only change `presentation.curbColors` if you find a clear reference. Curb *geometry* is physics; leave it alone.

## Verification (all must pass before you finish)

Run these from `godot/`. On Windows, use `tools/Godot.exe` instead.

```
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/game.gd --check-only
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/laps.gd
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/karussell.gd
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/track3d.gd
tools/Godot.app/Contents/MacOS/Godot --path . -- --features
```

- `tests/laps.gd` must report **Monza 261.504166666511** and **Spa-Francorchamps 325.174999999786**, byte for byte. Any difference means you've changed physics. Find the change and revert it.
- The feature suite must end with `FEATURE RESULTS {"checks":260,"failures":[]}`. It needs a real window, so don't add `--headless`.
- Check the Nordschleife visually. Take screenshots at Ex-Mühle and the Karussell, and confirm nothing floats, sinks or sits on the road.
- Check performance. Load time and frame time on the Nordschleife must not regress noticeably. `-- --performance` measures it; see `godot/docs/TESTING.md`.
- Format with `gdformat -l 110 scripts tests`, or at least keep new lines within 110 columns (tabs count as 4).

## Finishing

- Add a dated entry to `godot/docs/CHANGELOG.md` saying what you added and which features are approximated.
- If the landmark builder is general, add a row for it to the source map in `godot/docs/LLM-GUIDE.md`.
- Commit in logical steps: the landmark system, then the Nordschleife data, then scenery tuning. Don't push.
- Note that `presentation` metadata is part of best-lap record identity (`DATA-CONTRACTS.md`), so editing the Nordschleife document starts a fresh record namespace for that circuit. That's expected. Mention it in the changelog.
