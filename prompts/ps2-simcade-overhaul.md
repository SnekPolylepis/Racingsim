# Task: PS2-era graphics overhaul + Gran Turismo-style simcade handling (native Godot game)

You already know this repo. Work only in `godot/` (the browser `racing-sim.html` stays frozen). Read `AGENTS.md`, `godot/docs/LLM-GUIDE.md`, `ART-DIRECTION.md`, `CAR-MODEL.md`, `ARCHITECTURE.md` and `TESTING.md` again before editing; they are authoritative on invariants.

## Where things stand (as of 2026-09-21)

- Godot 4.6.2, Forward+ with OpenGL fallback, 240 Hz custom vehicle model in `scripts/car.gd` (Pacejka, per-wheel load, two-node tyre temps, integral TC, ABS, steering grip assist). `parity=true` is the browser-exact model used only by `tests/physics.gd`.
- Defaults: Spa (OSM/DEM-built) + Ferrari 296 GT3 (`ferrari_296.gd`). Other cars (roadster, GT) use lofts in `visuals.gd`.
- The "Afterhours" pass is **uncommitted** in the working tree: `night_style.gd`, `retro_paint.gdshader`, `retro_screen.gdshader`, `ferrari_296.gd`, doc/shader/script edits. It is a flat, clean, low-poly night look with a mild grade/grain. It explicitly avoided low resolution, dithering and heavy post. That is what this task replaces.
- Latest physics commit `d9c62f5`: ground-speed auto shifting, combined-slip TC, per-axle load sensitivity, retuned tyre windows. `tests/dynamics.gd` holds the measured targets. Bot laps: Ridgeback ~92.4 s, Spa ~308.4 s.

**Step 0:** Commit the current working tree as-is ("Afterhours baseline") so there is a clean rollback point. Then work in small commits, one per phase below.

---

## Part A: full PS2-era visual overhaul

### Target

The game should look like a good-looking 2003–2006 PS2 racer, with Gran Turismo 4 as the main reference for cars and circuits and NFS Underground 2 for night mood. The goal is to evoke the hardware's *look*, not to emulate the GS or copy anything. No assets, logos, fonts, HUD layouts, car liveries, sponsor names or music from any real game. All art stays procedural/code-built plus CC0 textures. No Blender or hand-modelled scenes.

Do not use PS1 tropes: no vertex snapping/wobble, no affine texture warping, no nearest-filtered textures on 3D surfaces. PS2 textures were bilinear-filtered and perspective-correct.

### Rendering pipeline

1. **Low internal resolution.** Render the 3D world into a `SubViewport` and upscale it to the window. Add a Settings option "Render resolution": `480p` (640×448 equivalent, scaled to aspect; default), `720p`, `Native`. Use a slightly soft upscale, not a razor-sharp nearest one (one setting: `Sharp`/`Soft`, default Soft). The HUD, menus, Help and the whole editor must render at native resolution on top and stay crisp. Mouse picking, camera, render interpolation and `--art-review` screenshots must all work through the SubViewport.
2. **Colour depth + dither.** In the screen pass, quantise to about 5–6 bits per channel with a 4×4 ordered (Bayer) dither. Keep it subtle, with visible banding on skies and fog but nothing noisy. Toggle: "Colour dithering" (default on).
3. **PS2 glow.** Use a strong bright-pass bloom with a wide, soft, slightly low-res blur, the kind that makes headlights, sun-lit paint and sky bleed. Implement it in the retro screen pass (or via the Godot glow tuned for that look) so it also looks right under the OpenGL fallback.
4. **Speed blur (optional, default low).** At high speed, blend the previous frame at low opacity, NFSU2-style. Setting: Off / Low / High. Never let it smear the HUD.
5. **Lighting model.** Switch world materials to per-vertex (Gouraud) lighting: `render_mode vertex_lighting` in custom shaders, per-vertex shading on `StandardMaterial3D`. Put baked vertex-colour AO under barriers, trees, stands and armco bases. Turn off SSAO, SSR, FXAA and MSAA in the retro path; some aliasing and shimmer is part of the look. `Native` resolution can keep MSAA 2× as an option.
6. **Shadows.** By default, no real-time directional shadow map. Instead use a soft blob/drop shadow under each car (a projected quad or decal that follows the road height), plus baked darkening. Keep the shadow map only as a "High" quality option.
7. **Fog and draw distance.** Use strong linear distance fog tinted to the sky, with a shorter far plane and visible LOD pop on trees and scenery (e.g., 3 tiers). Everything repeated stays in MultiMesh.
8. **Sky.** Build a painted panorama sky at startup in code: gradient, band clouds, a distant hill/forest silhouette ring rendered into the panorama, and a sun disc. Add a simple sprite lens flare (a few coloured hexagon/circle sprites along the sun-screen axis, occluded by a raycast) as a GT4 nod.

### Materials and textures

- Downsample every 3D texture to 128–256 px (bilinear with mipmaps). Generate the downsampled copies at import or build time, and keep the CC0 originals. Tiling may be visible; that is period-correct.
- Road: a painted asphalt texture with a darker rubbered racing line, lighter worn edges and painted lines, still driven by the existing road UV `(lateral_fraction, arc_distance_m)`. Keep the gravel/grass/tarmac-runoff paint mask exactly as the physics uses it.
- **Car paint (the signature element):** a GT4-style glossy paint shader with a base colour, a fake environment reflection from a small generated sphere map/cubemap (sky gradient + horizon silhouette + a few bright light bars), a Fresnel boost at grazing angles and a sharp specular sweep that slides across the body as the car turns. Glass is dark and reflective the same way. Wheels are simple silver with a dark tyre. Clamp every `pow`/dot input (see the NaN note in ART-DIRECTION.md).
- Trees: replace low-poly cones and blobs with classic alpha-tested **crossed billboard cards** (2–3 intersecting quads) using a procedurally painted tree texture (conifer and broadleaf variants, colour-varied per instance). Shrubs are cards too. The Spa Ardennes woods stay dense.
- Grandstands: textured boxes with a painted crowd texture (tiny coloured dots/blocks), not individual people. Boards and signage get original event branding only (e.g., "AFTERHOURS", "RIDGEBACK", made-up sponsors). No real brands.
- Barriers, armco, tyre walls, kerbs: simple geometry with painted textures, including red/white kerb stripes and striped tyre walls.
- Car bodies: keep the 296 and loft geometry (do not redo `CAR-MODEL.md` work), but run them through the new paint shader, and make sure headlight/taillight emissives bloom properly. Keep the `snapshot()/blend()` pose interface unchanged.

### Time of day

Offer two lighting presets through the same pipeline, as a Settings option shown on the title screen:
- **Afternoon** (new default): GT4-like late-afternoon sun, warm key light, blue-white sky, lens flare, long fog.
- **Afterhours**: the existing indigo/teal/amber night palette and `night_style.gd` floodlights, ported to the new pipeline (vertex lighting, glow, dithering, car light flares). In Afterhours, the road may keep its wet-look light streaks.

Time of day is cosmetic. It must not enter setup, record identity or grip.

### HUD and menus

Give the HUD a period feel: a bold rounded or italic sans for numbers, a tachometer arc with a shift light bottom-right, big gear digit and speed, lap/time/delta top-left, and a minimap, using original designs that are not copied from GT4. Menus get a PS2-era treatment: a car turntable or showroom backdrop on the title screen, chunky highlighted list items and an animated selection bar. Everything stays keyboard/controller navigable and readable at 1280×800. Do not pixelate or dither UI text, and never put the screen pass over the editor or Help.

### Performance

It must hold 60 fps+ on the user's PC (RTX 4080) at all settings and remain acceptable on the OpenGL fallback. The low-res path should be *faster* than the current Native path. Report measured frame times from `--art-review` or a timing pass.

---

## Part B: Gran Turismo-style simcade handling

### Target feel

The target is GT4/GT7-style simcade driving. It is weighty and believable: weight transfer, trail-braking rotation, understeer on overcooked entries, and lift-off rotation you can feel. But it is forgiving at and just past the limit, predictable on keyboard and controller, and catchable instead of snappy. It should not be arcade. Cars still brake, corner and accelerate at realistic g, and setup changes in the garage still matter.

### Structure (important)

- Add a **Handling model** setting: `Simcade` (default) and `Simulation` (exactly today's native model). Put all simcade behaviour behind a flag in `car.gd` inside the existing `parity=false` branch. `parity=true` must remain byte-for-byte browser-exact; `tests/physics.gd` must still pass at its current thresholds.
- `Simulation` must reproduce the current numbers. Every existing `tests/dynamics.gd` / `tests/handling.gd` / `tests/laps.gd` result with the model set to Simulation stays unchanged.
- Handling model **is** part of record identity (`game.gd` identity near line 633), so simcade and simulation laps do not share bests or ghosts. Ghost files must stay browser-exchangeable as documented.
- Put simcade constants in one clearly named table (e.g., a `simcade` block in `cars.json` per car with shared defaults), not scattered magic numbers. Existing 42 setup fields and saved setups must stay compatible.

### Simcade changes (implement, then tune against the targets below)

1. **Tyres:** a broader, flatter peak. Grip stays ≥95 % of peak from about 5° to 13° slip angle (and the equivalent slip-ratio band), and falls off past peak only to about 85–88 % instead of 70–80 %. Reduce load sensitivity by about 40 % so weight transfer rotates the car without big grip losses.
2. **Temperature and wear:** tyres start in their window. Temperature still moves and shows on the tyre cards, but the grip effect is compressed (roughly 0.95–1.0 within sensible temps). Wear's grip effect drops to about one third.
3. **Stability:** add a small physical yaw-damping term that only acts when body slip exceeds the rear tyres' peak slip, so slides build progressively instead of snapping. This is part of the simcade model, not an aid.
4. **GT-style driver aids:** replace or augment the garage aids with GT-like numbered levels: **TCS 0–10**, **ASM (stability management) 0–10**, which uses per-wheel braking plus torque cut when body slip/yaw exceed the driver's intent, and **ABS On/Off**. Defaults are TCS 3, ASM 3, ABS On. Map existing `tcOn/tcIntensity/absOn` so old setup files still load. Aids work in both handling models but default off in Simulation for cars that currently have them off.
5. **Steering:** in Simcade, the steering grip assist is on by default for keyboard *and* controller, with speed-sensitive steering tuned so full keyboard lock at 160 km/h cannot spin any car with ASM ≥ 1.
6. **Surfaces:** kerbs are less upsetting (lower ridge effect), still readable through the suspension and audio. Grass is slippery and slow but survivable. Gravel drags hard and scrubs speed fast but does not spin the car by itself.
7. **Contacts:** wall hits scrub speed and bleed yaw instead of adding it, so a glancing hit does not spin the car. Keep contact lap invalidation as it is.
8. **Keep:** drivetrain, gearbox and ground-speed auto shifting, diff types, aero, brakes, suspension and load transfer are unchanged except as above. Diff type and anti-roll bars must still clearly change corner-exit and mid-corner balance.

### Measurable targets (add a Simcade section to `tests/dynamics.gd`; it must pass)

- Skidpad lateral g within ±8 % of Simulation for each car. Simcade is not a grip buff.
- 0–100 km/h and 100–0 m within ±8 % of Simulation.
- Mid-corner at 90 % of the limit: lift, brake and full-throttle cases peak ≤ 8° body slip with ASM 3, and ≤ 25° with all aids off, recovering to < 3° within 2 s with neutral inputs.
- Keyboard full lock at 80/120/160 km/h: no spin (body slip < 15°) for all three cars with default aids.
- Trail braking still rotates more than straight-line braking (yaw rate difference measurable). Lift-off still produces a measurable yaw increase.
- `tests/laps.gd`: all four circuits in Simcade with zero off-track steps and zero barrier contacts. Bot lap times within ±4 % of Simulation.
- Heat soak: tyre grip multiplier stays ≥ 0.95 through the one-minute 90 % test.

---

## Constraints (do not break)

- The 240 Hz fixed step, solver clamps, `car.z` vs `car.elev` meaning, sign conventions, snapshot/blend interpolation, `track.barriers` rebuild rules and `res://` read-only rules from LLM-GUIDE's "High-risk assumptions".
- The editor, circuit library, JSON formats, garage and saved user files in `tracks/`, `setups/`, `ghosts/`. No schema changes except additive, optional fields with defaults.
- Everything offline with no plugins. Windows x64 export via `tools/Godot.exe`.
- Code formatted with `gdformat -l 110 scripts tests`. Targeted edits to named functions, no regenerating modules from a summary.

## Verification (run it, report actual output)

1. `tests/physics.gd`, `tests/laps.gd` (both handling models), `tests/handling.gd`, `tests/dynamics.gd` (both models), `tests/import.gd`: all pass.
2. Feature suite (`--features`) from source and from the exported exe, with no failures. Add checks for: render-resolution setting, SubViewport picking in the editor, time-of-day switch, handling-model setting and its effect on record identity, TCS/ASM/ABS levels and old-setup compatibility.
3. Extend `--art-review` to capture Afternoon and Afterhours × 480p/Native (car front/rear/profile, chase at Eau Rouge, title menu, HUD in motion) plus an OpenGL-fallback run. **Look at the screenshots yourself** and iterate until they read as a PS2-era racer. File-written is not success. Check stderr for shader errors.
4. Rebuild `build/RacingSim.exe` and confirm it launches to the title screen with the new defaults.

## Documentation

Rewrite `ART-DIRECTION.md` for the new pipeline (keep the NaN/sRGB notes). Add a "Handling models" section to the physics docs and PLAYER-GUIDE (in-game Help chapter: what Simcade vs Simulation means and what TCS/ASM/ABS do). Update LLM-GUIDE's source map, README feature list, TESTING thresholds and a dated CHANGELOG entry with measured before/after numbers. Distinguish measured results from claims.

## Final report

Include commits made, before/after screenshots (paths), the full test results table (both handling models), frame-time numbers, anything cut or deferred and why, and the 5 simcade constants that most change the feel with what each does.
