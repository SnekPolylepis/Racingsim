# Native changelog

## 2026-09-22 — real 3-D circuits

- Circuits are a ribbon in 3-space (`scripts/track3d.gd`): a centreline with a per-sample frame, banking as a rotation about the tangent, optional road cross-sections, and queries resolved in 3-D, so overpasses are expressible. The game, the car and the gameplay suites run on it; `scripts/track.gd` remains only for `tests/validation.gd`.
- Lap distance now includes elevation. Baselines: Monza 261.50 s, Spa 325.17 s (were 260.30 / 323.00).
- Suspension: road deviation limit raised from 0.12 m to 0.70 m, a bump stop past 8 cm, and a lifted wheel no longer pulls the chassis down.
- The car can leave the ground: takeoff when a crest demands negative normal force, ballistic flight with no tyre force, and landing into the suspension. In flight the rendered attitude follows the road beneath rather than rotating freely.
- The visible road and the terrain corridor are built from the ribbon surface, so what is drawn is what the wheels stand on.
- Nordschleife: both Karussells are now concrete ditches (`trackgen/karussell.gd`), and Flugplatz, Sprunghügel and Pflanzgarten fly again (`trackgen/jumps.gd`). Depths, rises and takeoff speeds are modelled. These edits change the Nordschleife's record identity, so earlier best laps there start fresh.
- New suites: `tests/track3d.gd`, `tests/karussell.gd`, `tests/airborne.gd`.

## 2026-09-22 — Nordschleife named landmarks and scenery dressing

- Added a named-landmark presentation system in `scripts/circuit_world.gd` (`presentation.landmarks` array), supporting buildings, spectator banks, bridges, grandstands, marshal posts and roadside hedges anchored by corner name or arc station.
- Authored 24 landmark installations for the Nürburgring Nordschleife:
  - Ex-Mühle: historic water mill complex on the outside of the turn, with stone foundation, half-timbered walls, gabled terracotta roof, annex wing, and timber waterwheel with mill race.
  - Caracciola-Karussell: multi-tiered stepped spectator bank with crowd ribbons, safety railings and fan tents placed strictly on the outside ($lat > 0$, offset $\ge 13.5\text{ m}$), preserving the 1.25 m inner concrete bowl ditch without obstruction; entry marshal post.
  - Breidscheid: stone road viaduct crossing above the circuit and spectator bank.
  - Döttinger Höhe: Bilstein-style overhead steel truss gantry with 5.8 m clearance and fictional circuit banner.
  - Antoniusbuche and Hatzenbach: covered pedestrian footbridges and roadside natural hedges.
  - Schwedenkreuz: 1638 stone cross monument in forest clearing.
  - Hohe Acht: Kaiser Wilhelm stone tower landmark on the hillside.
  - T13: covered tiered start/finish grandstand.
  - Spectator banks and marshal posts at Brünnchen, Pflanzgarten, Sprunghügel, Adenauer Forst, Wehrseifen, Bergwerk, and Galgenkopf.
- Tuned Nordschleife forest scenery in `scripts/visuals.gd` and track data (trees 6.0, treeline 16.0 m, pines 0.68) with backward-compatible `presentation.scenery.clearings` that clear trees at spectator viewing areas and landmarks.
- Note: modifying `presentation` metadata changes the document serialization hashed by `record_path()`, establishing a fresh record namespace for the Nürburgring Nordschleife without affecting Monza or Spa.
- Verification: syntax check clean, `tests/track3d.gd` 37/37 checks pass, `tests/karussell.gd` 11/11 checks pass, `tests/laps.gd` matches Monza `261.504166666511` and Spa `325.174999999786` byte-for-byte, `tests/test_nordschleife_scenery.gd` passes, and the graphical feature suite passes 260/260 checks.

## 2026-09-22 — single implementation

- Removed the browser game. `racing-sim.html`, the root `docs/` and `tests/` folders and the
  Node/Playwright suites are deleted; they remain in git history. The Godot project in `godot/`
  is now the whole product.
- Deleted the last browser-parity artefacts: `tests/physics.gd`, `tests/reference.json` and
  `tests/browser_roadster.json`. The test had been dead since `car.parity` was retired — it set a
  property the car model no longer has, and CI did not run it.
- Kept the full solver derivation as `docs/SOLVER-MATH.md` (formerly the root `docs/PHYSICS.md`)
  and repointed the LLM guide at it.
- Rewrote root `README.md`, `AGENTS.md` and `CLAUDE.md` around the native game only.
- Removed the Oval and Ridgeback circuits. `tests/laps.gd` now covers Monza and Spa; the rendered
  verification suite uses Monza where it previously loaded Ridgeback. Three circuits ship: Monza,
  Spa-Francorchamps and the Nürburgring Nordschleife.
- Verification after the removals: laps, handling, dynamics and validation suites pass headless,
  and the rendered feature suite passes 260 checks with no failures.

## 2026-09-22 — macOS native port

- Added a universal Apple Silicon/Intel export, Metal rendering selection, ASTC imports, Retina support and ad-hoc signing. Windows packaging remains available.
- Added `Play Racing Sim.command`, the official pinned engine/template fetcher, repeatable build script and ZIP packaging with license notices under `godot/packaging/`.
- Circuit-editor undo, redo and save accept Command on macOS while preserving Control shortcuts. Integration coverage exercises platform-specific undo/redo.
- Removed stale parity-property setup and retired browser comparisons from the handling suite; native curb assertions remain. The current car model has no parity property.
- On Apple M4 / macOS 27.2 / Metal: exported integration 261/261, fresh-start title 7/7, handling 23/23, Simulation dynamics 34/34, import 9/9 and geometry validation 103/103 passed. All four Simulation bot laps passed without off-track steps or barrier contacts.
- Added macOS CI build/headless tests/artifact upload; GitHub execution is not yet recorded. See [MACOS.md](MACOS.md) for evidence, incomplete runs and release limits. Earlier changelog entries describe their historical state.

## 2026-09-21 — browser parity dropped, MX-5 roadster, shadow and lighting fixes

- Dropped browser physics parity as a project constraint. `tests/physics.gd` and `tests/reference.json` are deleted, and CI no longer runs a browser-reference comparison. `car.parity` still exists in `scripts/car.gd` but is retired and unused: native physics is authoritative and free to evolve. The browser game (`../../racing-sim.html`) stays frozen and playable; only its role as a physics reference is gone.
- Reworked the roadster preset into a 1990 Mazda MX-5 (NA6CE, 1.6): 2.265 m wheelbase, 955 kg, 136 Nm, 7200 rpm redline, five-speed gearbox, 185/60R14 tyres, no ABS and no traction control. This supersedes the earlier "TC (0.4) and ABS on, like the modern road car it is modelled on" line in the 2026-09-21 physics pass below.
- Re-recorded the Simulation bot lap baselines: Ridgeback 96.10 s, Oval 42.78 s, Monza 260.30 s, Spa 323.00 s, replacing 92.35 / 41.51 / 248.23 / 308.43.
- Enabled directional shadows at Medium quality as well as High. Low keeps the projected drop shadow and painted ground darkening.
- Fixed the car contact-patch shadow: `shaders/blob_shadow.gdshader` now renders in the opaque pass with an ordered dither. A transparent material on that mesh is never composited by the world SubViewport, so the shadow previously never appeared at all.
- Gave all three cars night-gated headlights. They used to exist only in `scripts/ferrari_296.gd`.

## 2026-09-21 — amber circuit lighting and recorded engine audio

- Made all circuit lamps, halos, event-sign/pit accents and authored wet-road light streaks amber. Car brake lights and the night sky retain their natural roles.
- Replaced the tonal synthesized engine with an offline CC0 recording bank: idle/low/mid/high RPM, power/coast blending, smooth pitch and gear-cut response. Lowered and smoothed tire squeal; retained audio controls and procedural road/mechanical effects. Recordings are credited to jtvdb and biholao; exact Ferrari models are unspecified.
- Added reproducible bank processing, source/output hashes and a bounded `--audio-review` mixer/lighting check. This update does not resume or claim completion of the earlier full performance benchmark.

## 2026-09-21 — researched console frontend and 296/Spa acceptance follow-up

- Changed the SD raster to 640×448 with anamorphic/4:3 output; Authentic HUD/frontend now share the output chain, with optional Sharp UI, alternating 480i fields and a restrained CRT/composite filter. The editor remains native. Default framebuffer is 24-bit; optional RGB555 is distinct from build-time CLUT16/256 textures.
- Added original boot/title/attract, car/circuit selection, real preparation/grid, results and ghost replay; retained all garage/settings/library/help/editor workflows. Vendored Rajdhani OFL typography and CC0 sky/needle photographs, with hashes and license texts. Eight visual review rounds cover both backends.
- Reduced the 296 from 21,498 to 11,546 mesh triangles; spatially culled static terrain/scenery and reduced tyre-wall tessellation. Added original lamp halos, improved palette/sky conversion, runoff edges, fence filtering and cross-backend terrain colour.
- Diagnosed failed timing, then removed repeated flare circuit queries and finish-line copy/save work. SD Forward+ diagnostic before → after: average 5.91 → 4.94 ms; slowest-1% mean 35.25 → 7.46 ms; maximum 172.99 → 10.35 ms. Loading validation 49–50 → 2.4–2.6 ms after a candidate search verified against 103 exhaustive cases. Complete final matrix and export verification are recorded in [PS2-FOLLOWUP-REPORT.md](PS2-FOLLOWUP-REPORT.md).
- Vehicle equations, browser fixture and handling thresholds remain unchanged. Record schemas/identities remain compatible; completed sample arrays are immutable, and record/sector JSON saves are serialized on a worker and flushed before read/import/delete/shutdown.
- Prepared transparent ghost/skid rendering offscreen before first use and after lighting changes. The affected OpenGL SD lap's maximum fell from 165.12 to 11.04 ms, with zero frames over 16.667 ms in the follow-up diagnostic. Original and final traces are retained separately.

## 2026-09-21 — PS2-era rendering and separate Simcade handling

- Replaced the Afterhours presentation with a world-only low-resolution viewport, RGB565 ordered dither, wide glow and GPU frame-history speed blur. Native-resolution UI/editor stay crisp. Defaults: 480p Soft, Afternoon, Low blur; Native and 720p, Afterhours, and High shadow quality remain available. Small painted textures, crossed-card forests, a generated sky/reflection map, vertex lighting, blob shadows, ground darkening and original menu/HUD styling complete the pass. Car body geometry and pose interpolation remain intact.
- Added Simcade (default) beside the unchanged native Simulation equations. A wider tyre plateau, compressed heat/wear effects, lower load sensitivity, progressive yaw damping, calmer steering, gentler kerbs and dissipative contacts make slides more recoverable. TCS/ASM 0–10 and ABS retain old setup compatibility; handling model and effective aids separate records/ghosts. Cosmetic lighting/resolution do not change identity.
- Measured Simulation → Simcade, Roadster / GT / 296: 0–100 km/h 5.454/4.475/4.121 → 5.363/4.400/4.050 s; 100–0 32.170/29.503/28.666 → 31.416/28.845/28.015 m; skidpad 1.182/1.749/1.986 → 1.201/1.807/2.089 g. All are within ±8%. Simcade ASM 3 mid-corner peak slip is 6.49–6.80°; keyboard 160 km/h maximum is 9.12° with default aids, 11.22° with ASM 1.
- Simulation dynamics and four bot lap outputs match the saved baseline. Simcade Ridgeback/Oval/Monza/Spa: 92.308/41.500/248.179/308.367 s versus Simulation 92.350/41.513/248.225/308.429; zero off-track steps or contacts in either model.
- RTX 4080 at 1280×800: original Native Afterhours Medium → new 480p Medium median 2.872 → 2.439 ms Forward+ and 3.484 → 3.204 ms OpenGL. Final stress-case p95 stays ≤5.138 ms. New 480p does not consistently outperform new Native at this CPU-limited window size; High OpenGL was 2.3% slower than the original baseline in the short sample. These are measured runs, not universal guarantees.
- Verification: browser parity PASS; Simulation handling 24/0 and dynamics 34/0; Simcade dynamics 87/0; both four-circuit lap suites PASS; import 9/0; source/exported features 156/0 each; fresh-default exported title 7/0. Inspected 48 final screenshots across both renderers, lighting presets and 480p/Native. Final stderr is clear. See [PS2-SIMCADE-REPORT.md](PS2-SIMCADE-REPORT.md) for the complete measurements, screenshot paths, limitations and five principal tuning constants.

## 2026-09-21 — rear grip and tyre temperatures

Measured causes:
- **Rear wheels locked on every braking zone.** The automatic box judged engine speed, which drops during a shift, so it cascaded down to 1st at ~117 km/h; each downshift dumped the clutch onto a slow engine and locked the rears (-0.47 to -0.70 slip ratio against a -0.12 to -0.15 peak). Now it shifts on ground speed with a 0.4 s cooldown and never into over-revving, and downshifts blip the throttle (automatic or auto-clutch). Worst rear slip braking from 190 km/h is now -0.07 to -0.15.
- **Power oversteer through TC.** TC only watched wheelspin, not how hard the rears were already cornering, so full throttle at 90 % of the limit spun every car (88° body slip). TC now shrinks its slip target with lateral load (friction ellipse); the same test gives 10-20°.
- **Rear-heavy cars penalised.** Load sensitivity used a quarter of the car's weight as every tyre's reference, so the 58 %-rear GT3's rears lost grip just for carrying the engine. Each axle now uses its own static load.
- **Tyres cooked on slides and sat outside their window.** Surface slip heat is 25 % lower, carcass-flex heat higher, grip fades more gently above the window, and the presets' windows now match where the tyres actually run (roadster 70±42 °C, GT 78±40, GT3 80±38). A minute at 90 % cornering peaks at 75-86 °C. Tyres start 75 % of the way to their window. Tyre cards are now coloured by the window (blue cold, green working, red hot) instead of by raw temperature.

New dynamics checks: lift, brake and power mid-corner at 90 % of the limit, and a one-minute heat soak. Bot laps: Ridgeback 92.35 s, Spa 308.43 s.

## 2026-09-21 — physics pass

Measured first (new `tests/dynamics.gd`): the browser-era tyre curves only reached ~80 % of peak grip at 6° slip and ~95 % at 20°, so cars cornered on huge slip angles (15-19° at the front on a skidpad) and felt vague and drifty; longitudinal grip peaked near 30 % wheel slip, past where TC and ABS intervene. With a controller, the 0.35 speed-sensitive default still allowed ~15° of lock at 160 km/h, enough to spin the roadster.

- Native tyre curves (parity mode unchanged): peak at ~7-8° slip angle and ~12-15 % slip ratio, falling to ~70-80 % when locked, spinning or fully sideways. Skidpad grip now 1.2 g roadster, 1.7 g GT, 2.0 g GT3 on a 150 m circle.
- Steering grip assist (Settings → Controls, on for controller by default): caps steering at the kinematic angle for a limit corner plus the front tyres' peak slip, and always lets countersteer follow a slide. Full stick at 80-160 km/h no longer spins any car in the test; before, the roadster reached 32° body slip at 160 km/h.
- Traction control is an integral controller aimed just past peak slip (no on/off chatter, no bogging launches). ABS targets the new peak. The roadster preset now has TC (0.4) and ABS on, like the modern road car it is modelled on; both can be turned off in the garage.
- Tyres start warm (60 % of the way to their window, as after an out-lap) instead of 25 °C.
- Spa: the elevation fed the track spline unevenly spaced heights, which produced vertical kinks worth +6 g / -5.7 g at 200 km/h (cars going light and heavy at random through Bruxelles and the Bus Stop). The profile is now resampled every 16 m and curvature-limited; worst case is +/-0.7 g at 200 km/h. The dynamics test checks every bundled circuit for this.
- Results: roadster 0-100 5.5 s, 100-0 33 m; GT 4.5 s / 30 m; GT3 4.1 s / 29 m. Bot laps: Ridgeback 92.5 s, Spa 308.9 s.
- Test harness note: earlier numbers quoted during this investigation from a straight-line rig were invalid (the car started on grass); the committed test uses the middle of the straight.

## 2026-09-18 — realistic Spa-Francorchamps

- Spa rebuilt from the OpenStreetMap `highway=raceway` centreline (the Grand Prix loop found as the ~7 km cycle through the named corners), scaled 0.5 % to the official 7.004 km. 297 control points instead of the hand trace; corner labels placed on the named OSM ways.
- Real elevation: lower of EU-DEM 25 m and SRTM 30 m per 20 m sample (tree canopy reads as terrain), median-filtered and smoothed over 60 m. About 103 m of climb, lowest near Stavelot/Paul Frère, highest at Les Combes/Malmedy, steepest 18 %. DEM resolution softens Raidillon's local peak gradient (about 12 % here versus ~17-18 % quoted).
- Generated runoff (`trackgen/runoff.gd`): tarmac on the outside of slow corners, a tarmac strip then gravel on faster ones, pinholes closed and specks removed. New paint value 3 / surface id 4 = tarmac runoff (road-like grip, off-circuit for track limits) with an editor tool and ground-shader support.
- Ardennes scenery: `presentation.scenery` drives denser, taller conifer woods and a darker forest floor. Instance colours on trees, tire walls and boards are now treated as sRGB (they were rendering washed out).
- Bot lap 325.9 s (was 320.7 on the flatter hand trace); zero off-track ticks and barrier contacts. Pipeline and sources in `trackgen/`.

## 2026-09-17 — graphics, sectors, editor tools, housekeeping

Graphics
- Forward+ renderer (automatic OpenGL fallback) with quality-tiered SSAO, SSR, bloom, FXAA/MSAA, AgX tonemapping and retuned sky/fog/sun.
- CC0 Poly Haven textures (asphalt, grass, gravel, concrete) through new road, ground and painted-concrete shaders: two-scale tiling break-up, macro variation, a rubbered out-in-out racing line, dusty edges, gravel traps from the same 2 m paint cells the physics uses.
- `circuit_world.gd`: heightfield terrain that follows the track and rolls into hills away from it, verges that blend road into terrain, one-sided physical auto barriers (armco everywhere, tire walls on slow-corner outsides, runoff scaled by corner speed), advertising boards, grandstands at the sharpest corners and marshal posts. `autoBarriers` track option.

Timing
- Three sectors per lap with purple/green/yellow splits, previous-lap sectors held briefly, persisted best sectors and an ideal lap.

Editor
- Height profile strip with draggable point heights and grade colouring; Reverse direction, Smooth heights, width for all points.
- Import real circuits from GPX, GeoJSON or OpenStreetMap.

Housekeeping
- Browser version frozen (see root README). Code formatted with gdtoolkit (identical physics/lap results before and after). CI workflow for GitHub. Logs moved to `tests/logs/`.
- New `tests/import.gd`; `tests/handling.gd` covers barriers and sectors; `tests/laps.gd` requires zero barrier contacts; feature suite 108 checks.

## 2026-09-17 — title screen and pause menu

- The game now opens on a title screen (circuit and car pickers, best lap for the selection, Drive, Garage, Circuit editor, Circuit library, Settings, Help, Quit) over a slow orbit of the car on the grid.
- Esc / Start opens a real pause menu: Resume, Restart run, Garage, Settings, Help, Main menu, Quit game (plus Back to editor when paused during a test drive). Closing Garage or Settings returns to the pause menu. Quit goes through the unsaved-circuit guard.
- Menus are keyboard/controller navigable (arrows or D-pad, Enter or A); Start on the title screen drives.
- Feature suite: 12 new checks for the title/pause flow (102 total).

## 2026-09-17 — fixes, handling and art pass

Fixes
- Render interpolation: the car and camera are drawn between physics ticks (`CarModel.snapshot()/blend()`), removing the 1-/2-step stutter at refresh rates that do not divide 240 Hz (e.g. 144 Hz).
- Speed-sensitive steering is now a setting with separate keyboard and controller strengths. Keyboard keeps the original feel (1.0); controller defaults to 0.35 so the stick keeps authority at speed; 0 disables it.
- Invalid laps now say why ("off track", "contact", "missed CP n", or checkpoints reached). With off-track invalidation disabled, checkpoints accept runoff up to ~25 m from the edge.
- Suspension travel stops zero velocity into the limit, so heave/pitch/roll cannot wind up while clamped.

Handling (native only, `car.parity=false`; the browser-parity test is unchanged)
- Per-wheel road height feeds the suspension: crests, dips and bank transitions act through geometry, and curbs are physical (4.5 cm ramp with 0.8 cm ridges) instead of random bump noise.
- Two-node tires: fast surface plus slow carcass core; grip follows a blend, so tires take a couple of laps to come in and slides spike the surface temperature.
- Self-aligning torque (pneumatic + mechanical trail) is computed on the front wheels and shown in the debug overlay. Groundwork for force feedback; it does not alter steering.

Art
- Lofted car bodies per style (roadster with open cockpit/windscreen/roll hoop, GT coupe, GT3 with splitter, diffuser, side intakes and swan-neck-style wing), wheel arches, head/tail lamps, mirrors, livery numbers, twin-spoke rims with discs and calipers.
- Mixed pine and broadleaf woods in three depth bands with colour variation, trackside shrubs, and a ring of distant hills.

Verification: `tests/physics.gd` PASS, `tests/laps.gd` PASS on all four circuits with zero off-track ticks, new `tests/handling.gd` 15/15, feature suite 90 checks with no failures (run on Linux/Mesa under Xvfb; the Windows exe was re-exported from the same source).
