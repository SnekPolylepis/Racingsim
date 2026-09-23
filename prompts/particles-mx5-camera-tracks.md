# Next pass: particle effects, MX-5 body, chase camera fix, Chicago street circuit and the Nordschleife

You're working on the native Godot game in `godot/`. The browser version (`racing-sim.html`) is frozen: don't touch it, and don't add the new circuits to the root `tracks/` folder. Before editing anything, read `AGENTS.md`, `godot/docs/LLM-GUIDE.md`, `ARCHITECTURE.md`, `ART-DIRECTION.md`, `CAR-MODEL.md`, `DATA-CONTRACTS.md`, `TESTING.md` and `godot/trackgen/README.md`. Those documents describe the current code and its invariants, and they win over anything in this prompt that contradicts them, unless this prompt explicitly says it's changing a rule.

**Start by running `git status`.** The last session left roughly 70 uncommitted modified files (MX-5 physics preset, parity removal, shadow/lighting fixes, docs). Commit that state as a baseline ("Baseline before particles/MX-5/camera/circuits pass") before you change anything, so this pass has its own diff. Then commit each of the five parts below separately, in order.

Internet access rules from the earlier follow-up prompts still apply. Research, CC0/CC-BY/OFL/MIT assets and build-time tools are fine. The shipped game stays fully offline. Every download goes in `godot/THIRD-PARTY.md`. No GPL, NC or unclear licences. Blender only if it's truly needed (it isn't installed).

Rules that apply to every part:

- **Physics doesn't change.** Nothing here should alter `car.gd`, `collisions.gd`, `race.gd`, surface grip, record identity or the dynamics/handling/lap baselines. If a test result moves, you broke that rule. Find out why.
- **Presentation never reads or advances simulation state.** Visual effects read the render snapshot and the per-wheel fields the car already exposes. Never call the car's `rnd()`: it drives kerb/surface bump and is part of deterministic physics. Effects get their own RandomNumberGenerator.
- **It has to look like the rest of the game.** The target is the PS2-era look in `ART-DIRECTION.md`: small textures, billboards, restrained alpha, ordered dither, low-res raster. Effects must work in both lighting presets, at 480p/720p/Native, and on Forward+ and the OpenGL fallback.
- **Known renderer trap:** the world is drawn in a SubViewport, and `LLM-GUIDE.md` records that a transparent material on the blob-shadow mesh never composited there. Before building the particle system, prove with a screenshot that your particle material actually appears in the world viewport on both backends. Also pre-warm every new material offscreen, the way ghost/skid materials are already prepared. First-use shader compilation previously caused 165 ms hitches.
- Run `gdformat -l 110 scripts tests` and keep CI green.

---

## 1. Particle effects

Build a small, bounded effects system (for example `scripts/effects.gd`, owned and ticked by `game.gd` in `_process`, not `_physics_process`). Pooled billboards via MultiMesh or CPUParticles3D are fine. Pick whichever composites reliably in the world SubViewport on both backends, and justify the choice in the docs. Per-wheel inputs already exist: `w.surf.id` (0 asphalt, 1 kerb, 2 grass, 3 gravel, 4 tarmac runoff), `w.ellipse`, slip ratio/angle, `w.skidding`, wheel world position `w.wx/w.wy`, plus car speed and contact events.

Effects, per wheel where applicable:

1. **Tyre smoke** on asphalt, kerbs and tarmac runoff. Scale density with how far past peak the tyre is, whether that's lockups, wheelspin or big slides/drifts. Smoke rises, spreads, drifts behind the car and fades over a few seconds. Light grey by day, and at night lit by the amber circuit lamps and car lights (not glowing on its own). A brief puff on hard launches.
2. **Grass**: clippings and dark earth clods kicked up behind driven or sliding wheels, plus a faint green-brown dust haze at speed. Leave short-lived darkened wheel tracks in the grass (reuse the skid-mark MultiMesh pattern with a separate mesh/material and pool).
3. **Gravel**: stones thrown in a rooster tail from every wheel in the trap, scaling with speed, plus a beige/grey dust cloud that hangs longer than tyre smoke. Leave short-lived rut marks in the gravel.
4. **Kerbs**: a small dust/rubber puff when a wheel hits a kerb at speed.
5. **Barrier contacts**: sparks on armco/concrete scrapes and a burst on impact (cheap additive streaks), and tyre-wall debris puffs on tyre barriers. Cone hits get a small puff. Hook these from existing contact results without changing collision code. If there's no clean read-only hook, add a presentation-only event list the physics step appends to, and write down why it doesn't affect physics.
6. **Exhaust**: occasional overrun/upshift backfire pops (tiny flame sprite + smoke) at the car's real exhaust positions (the 296 already has them; give the MX-5 a single rear exhaust). Idle heat shimmer isn't needed.
7. **Ambient, per circuit** (see parts 4 and 5): steam from a few street manholes on the Chicago circuit, and drifting leaves or light mist in Nordschleife forest sections. Keep these cheap and spatially culled.

The ghost car emits nothing. Replays (last-lap ghost replay) may emit from the replayed car if it's cheap. If it isn't, leave it out and say so.

**Setting:** add `particles` (0 Off, 1 Low, 2 High; default High) to `DEFAULT_SETTINGS`, the Settings screen and Help. It's cosmetic and excluded from record identity, like time of day. Adaptive quality should also scale particle counts down before it drops other quality.

**Budget:** hard caps on live particles and marks per tier. At High with all four wheels in gravel at 150 km/h, the extra frame time must stay within what `--performance` can measure as noise-level on the SD Forward+ case. Measure it and record the number. No per-particle allocations in the frame loop.

**Tests:** extend the feature runner so it drives or places the car on each surface and asserts that the right emitters activate, pools stay within caps, marks retire, Off emits nothing, and the ghost emits nothing. Take screenshots of smoke, grass, gravel and sparks by day and at night on both backends, and look at them yourself.

## 2. MX-5 NA body for the roadster

The roadster preset is already a 1990 Mazda MX-5 NA 1.6 in physics, but it still uses the generic `roadster` loft. Give it a dedicated procedural body, following the `ferrari_296.gd` pattern:

- New `scripts/mx5_na.gd`, selected when `cars.json` roadster `body` is `"mx5"`. Keep the `roadster` loft in `BODIES` as a fallback. Go through `Visuals.finish_car` and return the same dictionary (`root/body/pivots/spins/brakes/wheel_r`). `pose_car`, `snapshot()`/`blend()` and the ghost behaviour stay intact.
- Build around the preset's real numbers: a = 1.087, b = 1.178 (2.265 m wheelbase), track 1.415, wheelR 0.289. Target exterior roughly 3.97 m long, 1.675 m wide, 1.23 m tall with the top down (verify against sourced specs and write them in the doc).
- Signature NA features: a low rounded nose with the oval "smile" intake and a thin bumper line, **pop-up headlamps** (closed by day; they raise when the night headlights come on, with a short animated rise, all presentation-only), the character line down the flank, the short rear deck, the full-width rear lamp cluster shape with amber/red/reverse sections, small door mirrors, a raked windscreen with a frame. Top down, with the folded hood cover, seats and headrests, a visible roll hoop or none (pick one and justify), a steering wheel, and a single exhaust. 14-inch multi-spoke alloys on 185/60R14 tyres, with the existing rim/caliper colours respected.
- No Mazda logos, badges or wordmarks. Keep the livery number system working (or disable it for this car and say why).
- Budget: under 7,000 mesh triangles, keeping the console-era approach from `CAR-MODEL.md`. Correct outward winding (the exterior-normal check must pass), smooth shading where panels are continuous, hard edges at panel gaps.
- Docs: add an MX-5 section (or `CAR-MODEL-MX5.md`) with dimensions, function map, references (public photos/spec sheets, which are study-only and never shipped) and the triangle count. Update `DATA-CONTRACTS.md` for the new `body` value.
- Run `-- --art-review` and inspect front, side, rear, 3/4, chase and menu turntable, by day and at night (pop-ups up). Check that the wheel openings line up with the axles at full steer and suspension travel.

## 3. Chase camera fix

**Bug:** in `game.gd::update_camera()` the camera position is lerped toward a world-space target with `1 - exp(-dt * 7)`. That's a first-order lag, so it trails behind by about `speed / 7`: roughly 10 m extra at 250 km/h. The car shrinks into the distance on straights and the camera lurches back in under braking. The speed-based pull-back (`+ min(speed * .035, 2)`) adds to it.

**Fix (Chase and High chase modes; leave Bonnet and the overhead modes alone):**

- Compute the offset in the car's frame using a **smoothed heading/yaw** (angle lag only, frame-rate independent, with a critically damped spring or exponential smoothing on the angle), not a lagged world position. The car should swing a little in frame through corners, which gives a sense of rotation, but the follow distance must not stretch with speed.
- Keep distance as its own tight spring with a **hard clamp**: at zoom 1, Chase stays within ±0.6 m of its nominal distance at any speed, under full braking and under full acceleration. Keep at most a small, capped speed pull-back (≤ 1 m total) if it looks better. High chase gets the same treatment with its own nominal distance.
- Handle elevation: follow the smoothed pitch of the road so crests and dips (Raidillon, Pflanzgarten, Fuchsröhre) don't bury the camera in terrain or leave it hanging high. Keep the existing ground clearance, but it mustn't pop. Use `snap` on reset, respawn and mode change so there's no swoop across the map.
- Keep the FOV speed widening, but check it doesn't fight the new distance.
- Big slides/spins: when body slip is large, blend the smoothed heading toward the velocity direction (a bit, capped) so the camera doesn't whip around with the car during a spin.

**Tests:** add a feature-runner check that drives the 296 at Spa (input-driven, like the existing full-lap check) and logs camera-to-car distance each frame. Assert Chase distance stays within the ±0.6 m band from launch through Kemmel top speed, La Source braking, and a deliberate spin. Assert no single-frame camera jump above a threshold you justify. Run it at a locked 60 fps and 144 fps (or equivalent dt sweeps) to prove frame-rate independence. Put before/after distance numbers in the report.

## 4. New circuit: Chicago street circuit (Grant Park)

A street circuit inspired by the Grant Park street course in downtown Chicago: roughly 3.5 km (about 2.2 mi) with about 12 turns, along Columbus Drive, Balbo, DuSable Lake Shore Drive, Jackson, Michigan Avenue and Congress Plaza/Ida B. Wells. Research the real layout and verify the length and turn count from public sources before committing to numbers. Give it an original in-game name (e.g. "Grant Park Street Circuit"). No NASCAR or sponsor branding.

**Geometry pipeline:** do what `trackgen/spa/` did. Put the scripts in `trackgen/chicago/`: an Overpass export of the street centrelines, cycle-finding along the named streets, projection to local metres, even ~12–16 m control-point spacing and correct lane widths (streets are wide; use real carriageway widths, typically 12–15 m, and document them). Mostly flat: take real elevation from the DEM, which will be near-flat, plus a slight road crown feel. Name the corners by street (e.g. "Michigan & Congress", "Balbo", "Lake Shore"). Make the start/finish and grid a plausible pit/start straight on Columbus Drive. Record ODbL attribution like Spa.

**Street-circuit look (new presentation, not physics):**

- A new `presentation.theme` (e.g. `"street"`) and documented `presentation.scenery` keys that switch `circuit_world.gd` to city dressing:
  - **Flat terrain** (no rolling hills), with a concrete/asphalt ground plane beyond the barriers.
  - **Concrete jersey walls with catch fencing** replacing armco on the auto barriers. Tyre bundles and TecPro-style barriers go only at the ends of escape roads. The barriers must keep the same physics (this is a mesh/material swap chosen by theme). Tight runoff: tarmac escape roads at a few corners, no gravel.
  - **Street details:** lane markings and crosswalks (painted, worn by the racing line), manhole covers, street kerbs and sidewalks, traffic-light poles and street signs (generic, no real brands), street lamps (amber at night, reusing `night_style.gd`), parked-car silhouettes behind fences, temporary grandstands and hospitality suites along Columbus.
  - **Skyline:** procedural buildings along Michigan Avenue and beyond: brick and limestone mid-rises near the street, glass and steel towers behind, a couple of very tall original silhouettes that read as "Chicago skyline" without copying specific buildings exactly. Windows lit at night via an emissive window texture. MultiMesh/instanced and spatially culled to stay inside the console-era budget.
  - **Landmarks, original geometry:** a large ornate tiered fountain in the Congress Plaza area (Buckingham Fountain is from 1927 and fine to evoke), Grant Park trees and lawns inside the circuit, Lake Michigan as a water plane to the east with a lakefront edge, and an elevated-railway structure (steel trestle) visible a block west. **Do not model Cloud Gate ("the Bean") or any other copyrighted modern sculpture.**
- Ambient steam from manholes (part 1). Afterhours should look great here: wet-look streets, reflections of amber lamps and lit windows.

## 5. New circuit: Nürburgring Nordschleife

The full Nordschleife as a closed loop, about 20.8 km (the commonly quoted 20.832 km; verify). Use the Nordschleife-only lap, not the 24h combination with the GP circuit. Use the same pipeline as Spa, in `trackgen/nordschleife/`: OSM `highway=raceway` ways, a cycle closest to the official length (exclude the GP circuit, pit lanes and access roads), EU-DEM/SRTM elevation at 20 m, median filter and smoothing, and ~16 m control-point spacing (about 1,300 points, well under the 2,000-point cap). Label the famous corners from OSM names or references: Hatzenbach, Flugplatz, Schwedenkreuz, Aremberg, Fuchsröhre, Adenauer Forst, Metzgesfeld, Kallenhard, Wehrseifen, Breidscheid, Ex-Mühle, Bergwerk, Kesselchen, Klostertal, Steilstrecke, Karussell, Hohe Acht, Wippermann, Brünnchen, Pflanzgarten, Schwalbenschwanz, Galgenkopf, Döttinger Höhe, Antoniusbuche, Tiergarten, Hohenrain.

Specific requirements:

- **Elevation:** roughly 300 m of change (low near Breidscheid, high near Hohe Acht). Keep the character (Fuchsröhre compression, Flugplatz and Pflanzgarten crests, Kesselchen climb). The game has no airborne state, and `trackgen` limits vertical curvature. Keep the crests as sharp as the existing vertical-curvature rule and the dynamics test allow. Don't loosen the test's threshold silently. If the Ring needs a per-circuit exception, justify it with numbers and document it. Don't add airborne physics.
- **Karussell:** a steep banked concrete bowl on the inside line, using control-point bank plus a concrete surface look (presentation texture; grip stays road-equivalent). Other notable banking and camber changes where the DEM or sources support them.
- **Width:** narrow, mostly about 8–10 m, wider on Döttinger Höhe. Document the values.
- **Look:** armco close to the road nearly everywhere, with grass verges and little runoff (do not auto-paint big gravel traps; the runoff generator should be tuned or bypassed for this circuit, and document how). Hedges and dense Eifel forest (conifer/deciduous mix through `presentation.scenery`), the long Döttinger Höhe straight with its bridge, a few spectator areas with parked cars and tents at Brünnchen and Pflanzgarten, and graffiti-style painted road markings done with original generic patterns (no real names or logos). Distance marker boards at each kilometre.
- **Scale problems to solve, not ignore:**
  - `circuit_world.gd::build_heights()` sets `cell = max(8, extent / 240)`, which gives about 20+ m cells over a ~5 × 4 km extent. That's too coarse near the road. Make terrain resolution adequate near the track (tiled/local heightfields, a finer cell near the road, or a capped cell size with streamed tiles) while keeping memory and load time reasonable. Measure load time and memory before and after on Spa and the Ring.
  - Check that scenery/terrain spatial culling, the minimap, sectors, checkpoints, ghost size (Spa's replay lap JSON is already ~1.4 MB, and the Ring is ~3× longer), record saving on the worker thread, and the loading screen's real progress all behave at 20 km. Fog and the far plane should hide the pop-in.
- Keep ODbL/EU-DEM/SRTM attribution like Spa.

## Tests for both circuits

- Extend `tests/laps.gd` to six circuits: roadster bot laps on Chicago and the Nordschleife with zero off-track steps and zero barrier contacts, in both Simulation and Simcade. Record the new baseline times. The four existing baselines must stay identical.
- `tests/dynamics.gd` vertical-curvature check passes for all six (see the Ring note above).
- `tests/validation.gd` passes for both. The circuit select screen shows both with correct length, corner count and elevation profile. Startup defaults stay Spa + 296.
- `--features`, `--art-review` and `--performance` on both backends: add both new circuits to the screenshot matrix (day and night, chase and a trackside angle) and look at every shot yourself. Report load time and frame-time percentiles for Chicago and the Ring alongside Spa.

## Finish

- Rebuild `build/RacingSim.exe` and run the exported feature suite. Source-only success doesn't count.
- Update `CHANGELOG.md`, `LLM-GUIDE.md` (source map and recipes), `ARCHITECTURE.md` (effects ownership and frame order), `ART-DIRECTION.md`, `DATA-CONTRACTS.md` (new body, theme and scenery keys, the particles setting), `PLAYER-GUIDE.md`/in-game Help (particles setting, new circuits), `TESTING.md`, `trackgen/README.md`, `THIRD-PARTY.md` and the root `README.md` track list.
- Write `godot/docs/EFFECTS-CIRCUITS-REPORT.md` with what you built, measured numbers (camera distance before/after, particle cost, load times, bot laps, triangle counts), screenshot paths, anything you cut and why, and known limitations. Keep recorded results and guarantees clearly separated.
- If you have to cut scope, cut in this order: ambient circuit effects, exhaust pops, spectator areas/graffiti on the Ring, elevated railway in Chicago. Never cut: the camera fix, tyre smoke/grass/gravel effects, the MX-5 body, or either circuit being fully drivable with correct geometry and elevation.
