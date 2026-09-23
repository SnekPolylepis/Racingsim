# Native architecture and invariants

## Rebuild transition (P4-01)

Normal game launch now builds or loads the authored 3D Proving Ground TrackAsset, places a CarBody on its first grid slot, and steps it against TrackSurface at 240 Hz. The generated scene is currently above the 5 MB repository budget, so game.gd builds it from trackgen/proving_ground.gd when the scene is absent. The default view renders in native Godot X/Y/Z coordinates. Its car pose uses the section 5.4 snapshot (Transform3D and four wheel records); render position is interpolated with lerp and basis rotation with quaternion slerp. `--v2-smoke` runs the new headless path for a short deterministic drive; `--v2-visual-smoke` also exercises the temporary car and chase-camera presentation in a window.

The earlier sections below describe the planar feature-harness path retained for `--features` and other existing visual test modes. Race timing, wall response, presentation, camera/instruments/audio, and UI are scheduled for P4-02 through P4-06; they are not connected to normal 3D driving yet. The visual car and chase camera in P4-01 are transitional.

## Ownership and lifecycle

`game.gd` owns TrackModel, CarModel, RaceModel, Controls, Storage and Visuals helpers (RefCounted). Interface is a CanvasLayer owning Instruments, FrontEnd and modals. CircuitEditor is reparented to a native CanvasLayer; Audio is a separate Node. Scenery, sunlight, player/ghost cars and skid MultiMesh share the root World3D. RetroRenderer composites its world and Authentic UI viewports before scaling. Sharp UI optionally overlays that output; the editor always bypasses it. Root 3D rendering is disabled.

Startup loads settings and JSON preset/field data, configures the car and controls, builds environment/UI/audio, enumerates circuits, loads the first circuit, and applies rendering settings. Interface initialization creates the editor before the status label; early status messages must tolerate that label being absent. Property-panel refreshes are deferred to avoid rebuilding controls in their own callbacks.

The root owns transitions and file workflows; the UI invokes these services. Storage does not reset cars or show modals. Car and Track do not depend on scene nodes. This separation allows headless physics tests with no game window.

## Fixed simulation order

`project.godot` sets 240 physics ticks/second and a maximum of 32 physics steps per rendered frame. In `game.gd::_physics_process(dt)`:

1. Return if paused, editing, a modal/dialog is open, or there are no track samples.
2. Smooth/poll controls; consume reset and shift events.
3. Advance `car.step(dt, track, automatic)`.
4. Apply `Collisions.step`; use the resulting velocity change to trigger impact audio.
5. Advance race timing/checkpoints and persist a new valid best lap.
6. Sample telemetry, advance simulation elapsed time, and periodically add/retire skid marks.

`_process(dt)` updates visual car poses, scenery animation, camera and ghost; updates the sound mix; redraws instruments; and evaluates adaptive graphics quality. Render delta must not enter the custom vehicle solver. Visual poses are interpolated: `_physics_process` stores `prev_pose=car.snapshot()` before each tick, and `_process` draws `CarModel.blend(prev_pose, car.snapshot(), Engine.get_physics_interpolation_fraction())`. `prev_pose` is cleared while simulation is blocked and on reset, so a teleport never smears. The camera follows the interpolated model. Physics-state readers (HUD, skids, audio) still read the live solver. Timing also produces three equal-distance sectors per lap (`race.gd`): splits are flagged purple (best ever for the record), green (session best), yellow or invalid; the best individual sectors are saved to `records/<hash>.sectors.json` and summed into the ideal lap. `instruments.frame_ms` measures the root's render-update work, not total GPU frame time.

## Coordinates and units

The simulation retains browser coordinates `(x,y)` on the ground, where positive screen y points down. Position is meters, velocity m/s, force N, torque N m, mass kg, time seconds, angular state radians. Heading `h` points along `(cos(h), sin(h))`; positive heading turns clockwise in the top-down view. Body right is `(-sin(h), cos(h))`.

Rendering maps simulation `(x,y,height)` to Godot `(x,height,y)`. Car model local +X is forward, +Y up, +Z right. Wheels are always `[FL, FR, RL, RR]`; front wheel body x is `p.a`, rear is `-p.b`, left body y is negative. Rendering constructs a basis from road gradients and applies suspension pitch/roll/heave separately.

Track control-point `z` is centerline altitude in meters; point `bank` is degrees. Samples store bank radians. `s` is wrapped centerline arc distance; `lat` is signed lateral distance, positive right. Sample normals are `(-ty, tx)`. Surface height is centerline height minus `lat * tan(bank)`, so positive bank raises the left edge. `grade` is rise/run; `kv` is vertical curvature, 1/m. `car.grade` is slope in the car's heading, not necessarily centerline direction.

`car.z` is chassis suspension heave relative to the road-following pose. `car.elev` is queried road height. `car.ax/ay` exclude slope gravity deliberately: they drive load transfer. Gravity is added to velocity integration separately; adding it to these accelerations would incorrectly cancel downhill weight transfer.

## Vehicle solver

`car.gd::configure()` copies preset and setup data and allocates four wheel dictionaries. `reset_pose()` clears motion, suspension, tires and input. Each step first derives speed/steering and center-surface elevation effects, then advances suspension and loads. Suspension bump excitation uses each wheel's previous surface state. The wheel loop updates contact positions/surfaces, slip and forces, accumulates body forces/reaction torques, and updates temperature/wear. Drivetrain integration follows that loop; aerodynamic drag and gravity then feed velocity/pose integration. Finally it updates body-frame debug velocities and wheel visual phase. Preserve that order before inserting new couplings.

`car.simcade_enabled` chooses the handling model (see [PHYSICS.md](PHYSICS.md)). `car.parity` is retired: the browser-parity path is no longer a project constraint and no longer has a test behind it, and the current `scripts/car.gd` has no parity property. The native path is authoritative and adds these layers on the solver order described above: (1) per-wheel road height — `track.surface_at()` writes `w.roadZ` (banked surface plus a curb profile ramping to 4.5 cm with 0.8 cm ridges); the wheel loop stores `w.dev` = height above the CG tangent plane and a ~12 Hz low-passed `w.devRate`, and the next tick's suspension adds them to compression/velocity, so crests, bank transitions and curbs act through geometry (curbs no longer use random bump); (2) two-node tires — `w.temp` is the fast surface (slip heat, air cooling) coupled to a slow `w.core`; grip uses `0.65·surface + 0.35·core`; (3) self-aligning torque — pneumatic trail collapsing toward the slip peak plus a small mechanical trail gives `w.mz` on the fronts and `car.steer_torque` (N m, positive steers right). It is an output for telemetry/future force feedback and does not feed back into steering. (4) Native tyre curves: longitudinal C 1.5 / E 0, lateral stiffness ×1.4 with C 1.5 / E 0.2, peaking at `peak_slip_ratio()` / `peak_slip_angle()`; TC is an integral controller on driven-wheel slip and ABS targets the same peak. (5) Tyres start warm. `car.steer_slip_limit` (the steering grip assist) caps steering at wheelbase·µ·g·(1+downforce)/v² plus that value, widening only for countersteer against the yaw rate. Suspension travel stops zero velocity into a limit. `car.steer_falloff` (m/s at which lock halves, 0 = off) is set each tick by `game.gd` from the keyboard or controller steering-assist setting.

Pacejka forces are combined through a friction ellipse. Wheel loads come from suspension state. The tire force `need` clamps and clutch/differential equalization torque clamps limit stiff couplings to the change needed in one physics tick. Removing them can cause standstill jitter or drivetrain oscillation. The surface-bump random generator is deterministic; keep it that way so headless runs stay repeatable.

After user objects, `Collisions.step` also tests the derived auto barriers from the 3×3 grid cells around the car. Those segments know which side the track is on (`side`), so contact is one-sided: a point that crossed the barrier centreline within one tick is still pushed back toward the track, which prevents tunnelling at high speed.

Surface IDs: 0 asphalt, 1 curb, 2 grass, 3 gravel, 4 tarmac runoff (road-like grip, but off the circuit: it counts toward all-four-wheels-off and track limits). Paint values are a different domain: 1 grass, 2 gravel, 3 tarmac runoff. The per-wheel query gives asphalt/curbs priority over paint. The model stays on the surface; crest effective gravity is clamped, and barriers are planar.

## Track queries and derived state

Track `data` is the editable document; `samples`, `length`, `checkpoints` and the spatial index are derived. `load_data()` deep-copies and defaults the document, then rebuilds. `rebuild()` samples the closed Catmull-Rom path, calculates tangents/normals, width/bank/curvature/grades and the lookup structures. `project()` returns the closest centerline projection and signed offset. `pos_at()` returns a pose at wrapped arc distance. `elev_at()` returns height/gradients and road shape; `surface_at()` also updates the wheel's `sIdx` search hint.

Geometry/curb changes require rebuild; paint/object changes do not change the centerline. Empty/short drafts have safe query defaults. `validate()` separates blocking errors (insufficient geometry or no start) from warnings (steep slopes/self-crossing). Warnings do not prevent driving. Intersection detection is coarse, not a geometric proof. A 40 m spatial candidate grid accelerates the original every-sixth-sample strict crossing test without changing its predicate or adjacency exclusions; `tests/validation.gd` compares it with the exhaustive algorithm.

`RecordWriter` owns one serial worker thread and a private Storage helper. Completed ghost arrays transfer ownership to immutable record/replay jobs; the next lap allocates a new recording. Each job carries its destination and values, so changing the selected car/circuit cannot redirect a pending write. The worker performs atomic temporary-file replacement and reports failures on the main thread. Record reads/imports/deletions and shutdown flush pending work. `begin_session()` retains the already loaded matching record while replacing session timing, avoiding disk reads, full track hashing and ghost deep copies during the grid transition. Selecting a different record clears frontend session rows, replay and top speed, and synchronizes the completed-lap counter; an identity change cannot append a zero-time lap from the previous session.

## Modes, modal state and input

`in_menu`, `editing`, `paused` and `test_from_editor` remain separate flags. FrontEnd starts at boot and owns title/main/race/car/circuit/loading/grid/drive/pause/results/replay/attract pages. `show_page()` sets blocking flags and first-button focus. `set_paused()` shows pause/drive; `show_main_menu()` resets to main. `ui.sync_menus()` hides legacy overlays and derives toolbar/HUD visibility. Modals retain the underlying page and restore its focus on close. `ui.is_open()` includes blocker and counted dialogs. Ordinary focus loss clears controls and pauses play. A benchmark driver isolates injected input from desktop focus/physical devices; normal play does not.

`_input()` first lets FrontEnd handle Back, Start and tabs (except during remapping), then captures remapping/key/pad state and forwards GUI events into the UI SubViewport. `_unhandled_input()` retains driving/editor shortcuts. Editor pointer actions enter `_gui_input`; global release ends gestures outside the canvas. Controls combine event-fed axes/buttons with hardware polling. Menu bindings accept all pad IDs. Tests use device 31 through the same application input path.

Entering the editor stops simulation, hides 3D driving presentation, restores cones to rest positions and removes runtime fields. Exiting checks the circuit, rebuilds 3D scenery, resets the car/race and loads the matching record. T starts a test drive; Esc returns while `test_from_editor` is set. Other Esc behavior closes menus or toggles pause.

## Editor transactions

`begin_change()` deep-copies the pre-edit document. `commit_change(rebuild)` records one undo snapshot if changed, clears redo, compares with the saved snapshot, optionally rebuilds geometry, validates, refreshes properties and redraws. Undo is limited to 80 snapshots. A complete drag/paint stroke is one transaction. Point motion rebuilds the spline live; expensive 3D scenery rebuild happens on leaving the editor.

Insertion/deletion must reindex `curbOverride`, whose keys refer to control segments. Cone editing updates both current and rest coordinates. `mark_saved()` moves the dirty baseline only after a successful write. New/load/quit actions use `guard_dirty`; generic read helpers such as `load_track_now()` are lower-level and rely on their caller for discard protection.

## Visual, UI and audio contracts

Visuals return a car dictionary with root/body/pivots/spins/brakes. Pose updates must preserve this interface. Shared materials are cached; brake materials are duplicated so emissive state is independent. Trees use spatial MultiMesh batches and crossed-card LODs; road/terrain use generated meshes. Shadow quality, lighting and camera remain root responsibilities; RetroRenderer owns world resolution, glow and alternating history targets. Cone visuals retain references into the current track document, so rebuilding the world rebinds them.

Ghost meshes use visual layer 2. When a new car model is built, `warm_ghost()` renders its actual transparent meshes once through a 32×32 offscreen viewport sharing the circuit World3D. The main camera excludes that layer only for preparation, then restores it. This prepares the Compatibility shader variant before the ghost first appears at the timing line. It never changes ghost samples or vehicle motion; the isolated flow runner checks that preparation restores the camera mask.

Frontend/UI uses a 1280×896 logical canvas rendered to 640×448 by default; the root/editor retains a 1440×900 logical canvas. Avoid measuring controls before layout settles. Garage/settings/Help use a centered modal and visible focus. Instruments ignore mouse input. Changed garage values reset the attempt and record namespace. Loading reports completed validation, reset, record and view work. Restart reuses meshes for the same preset. Attract swaps in the 296/Spa models without changing saved documents and restores the selection on Back. Replay draws the last recording through snapshot poses without stepping physics.

Audio preloads eight edited CC0 44,100 Hz mono PCM loops: idle/low/mid/high, each with power and filtered coast versions. Adjacent RPM bands use equal-power crossfades on a logarithmic RPM scale; smoothed throttle blends power/coast, and shift cuts briefly soften the power layer. All bank players stay running to avoid loading or restart gaps during a shift. Each car has a tuned voice using the same recorded bank; the sources do not identify the exact Ferrari model. Intake breath, tires, road, shift and impact remain deterministic 22,050 Hz synthesis. Master/mute/activity feed smoothly fading gains; impact cooldown prevents excessive retriggering. Audio only reads vehicle state. `tools/decode_engine_recordings.gd` and `tools/build_engine_audio.py` reproduce the bank from vendored sources; originals are excluded from export. `--audio-review` checks actual mixed PCM, mute/pause/sliders and amber lighting in a short isolated run.
