# Racing Sim — player handbook

This guide is included in the native game. Open Help and choose a chapter. It also lives in the source project for players and maintainers.

## Getting started

On Windows launch RacingSim.exe or Play Racing Sim.cmd. On macOS open Racing Sim.app or Play Racing Sim.command from the project folder. No browser, installation or Godot editor is needed. Skip the studio card or let it finish, then press Enter or the controller's main action button at PRESS START. Choose Race, Time Trial or Free Run, your car and setup, then your circuit and light. Load circuit prepares the run and shows a three-second grid countdown. Back cancels preparation or returns from the grid to circuit selection. Garage, Circuits, Settings, Help and Quit are on the main menu. Use the mouse, arrows / D-pad and Enter / main action; Esc or the second controller action goes back. W or Up accelerates, S or Down brakes, and A/D or Left/Right steer. The title starts a driving demonstration after 25 seconds without input.

The default showcase is the 296 GT3 at Spa. For learning the controls, the Roadster and Monza are also available. Brake before a corner, turn smoothly and apply throttle gradually on exit. R resets to the grid and restores the car and tires. Escape (or Start on a controller) opens the pause menu: Resume, Restart run, Garage, Settings, Help, Main menu and Quit game. Closing Garage or Settings returns to the pause menu. Escape also closes an open window. The game pauses when its window loses focus. During an editor test drive, Escape returns straight to the editor instead.

The default selection is Spa-Francorchamps with the Ferrari 296 GT3, Simcade handling and Afternoon lighting. The console-era presentation uses small filtered textures, glossy reflected paint, painted forests, soft glow and subtle colour dithering. Settings on the title screen also offers Afterhours: indigo skies, amber pit accents and amber floodlights. Time of day and the wet-looking night streaks do not change grip or records. The dedicated 296 body, steering wheels, suspension and brake lights remain animated.

The three included circuits are Monza, Spa-Francorchamps and Nürburgring Nordschleife. Spa and the Nordschleife are built from OpenStreetMap survey data (© OpenStreetMap contributors) with real elevation from terrain models: Spa is 7.004 km across the Ardennes, while the Nordschleife is the complete 20.832 km Eifel mountain circuit spanning nearly 300 m of vertical climb and plunge from Breidscheid to Hohe Acht. Widths, curbs, runoff and scenery are approximations. Monza is a playable approximation traced from official maps. Cars use roadster, GT and Ferrari 296 GT3 parameter presets with procedural body models. The roadster is modelled on a 1990 Mazda MX-5 (NA, 1.6): 2.265 m wheelbase, 955 kg, 136 Nm, a 7200 rpm redline, a five-speed gearbox and 185/60R14 tyres, with no ABS and no traction control.

## Driving and gear changes

Keyboard defaults:
• W / Up: accelerator; S / Down: brake.
• A/D or Left/Right: steering; Space: handbrake.
• E or Shift: shift up; Q or Ctrl: shift down.
• C: clutch; R: reset to grid; M: automatic/manual gearbox.

Automatic mode shifts for you. To select reverse, hold the brake while stopped until the gear changes, then use the accelerator. Repeat while stopped to return to forward drive. In manual mode, use the shift keys and choose whether automatic clutch assistance is enabled in Settings → Driving.

Keyboard inputs are smoothed. Holding a direction produces more steering than a short tap. Simcade has steering grip assist on for both keyboard and controller; its Controls option can disable it. Simulation retains separate keyboard/controller grip and speed-sensitive steering settings. Countersteering remains available to catch a slide. Handbrake use can still rotate the car quickly.

Controller defaults: left stick steering, RT/LT accelerator/brake, LB clutch, X handbrake, A/B shift up/down, Back reset, Start pause. Button names assume a common Xbox-style layout. Physical controller hardware has not yet been verified on this build.

## Handling models

Settings → Driving selects Simcade or Simulation. Changing model resets the attempt and selects separate best laps and ghosts.

Simcade is the default. It retains weight transfer, drivetrain, suspension, differential and aero, with a wider tyre limit, gentler temperature and wear penalties, milder kerbs and dissipative wall contacts. Steering grip assist helps keyboard and controller inputs stay within a catchable range. It does not provide unlimited grip: brake before tight corners and avoid abrupt inputs on grass.

Simulation retains the previous native tyre and contact model, its setup sensitivity and original preset TC/ABS defaults. It has no default ASM.

Garage → Aids has TCS 0–10, ASM 0–10 and ABS On/Off. Simcade defaults to TCS 3, ASM 3 and ABS On. TCS reduces torque when driven wheels spin; a higher level intervenes earlier. ASM selectively brakes a wheel and reduces torque when yaw or body slip departs from the intended turn. ABS releases brake pressure near lockup. Zero switches TCS or ASM off. The aids can be used in either model. They are separate from the small physical yaw damping built into Simcade.

Old setups keep their original TC/ABS choices and load with ASM off. Saved native setups include optional aid levels while keeping the browser's legacy fields. All original tuning fields remain supported; differential and anti-roll-bar changes still matter.

## Cameras, display and sound

V cycles chase, high chase, bonnet, north-up overhead and car-relative overhead views. The mouse wheel changes driving zoom. Settings → Display also provides camera selection, chase height, km/h or mph, graphics quality, adaptive quality and fullscreen. F11 toggles fullscreen. On Apple keyboards, function shortcuts may require Fn/Globe; the menus also offer fullscreen and editor access.

Render resolution offers 480p (the default), 720p and Native. Default 480p component uses a 640×448 world and Authentic UI, displayed in anamorphic 16:9. Choose 4:3 for a conventional TV shape. Authentic menus and HUD share the output filter; Sharp UI is optional. The circuit editor always stays sharp. Optional 480i generates alternating fields with deflicker; CRT / composite adds mild colour bleed and a mask. The default framebuffer is 24-bit; colour dithering applies to optional 16-bit RGB555. Low speed blur affects the driving world. Afternoon and Afterhours use the same pipeline and OpenGL fallback. Medium and High quality add directional shadows; Low uses car drop shadows and painted ground darkening. Native offers optional MSAA 2×. Road height and banking remain physical at every setting.

Settings → Audio provides mute, master, engine and effects levels. Engine pitch follows RPM; throttle changes its tone and level. Tire squeal responds to slip, surface noise changes with speed and terrain, and shifts/impacts have short effects. Sound fades out in menus, the editor and while paused.

If the game is silent, close menus, resume driving, check mute and volume, then check your system output device. The engine blends edited real-car recordings across rev ranges, with a softer off-throttle layer. The source Ferrari models are unspecified; these are tuned game voices rather than exact recordings of each selectable car. Tire, road and mechanical effects remain synthesized.

## Laps, tires and telemetry

Cross the start line in the driving direction to begin timing. Each lap is split into three sectors shown under the lap time: purple is your best ever for this car, setup and rules, green is your best this session, yellow is slower, and dark red means the lap was already invalid. For a few seconds after the line the previous lap's sectors stay visible. IDEAL is the sum of your best three sectors. A valid lap must pass the automatic checkpoints in order and return to the start. The time panel shows the current lap, best and last lap. An invalid last lap is marked with a cross and the reason: off track, contact, a missed checkpoint (passed too far from the road) or the checkpoints reached. When off-track invalidation is turned off, checkpoints accept runoff up to about 25 m from the road edge. Reset starts a fresh attempt.

Settings → Driving controls off-track invalidation and barrier-contact invalidation. Off-track invalidation applies when all four tires leave the road/curb. Changing race rules or tire wear starts a fresh run and selects its matching record.

A valid new best records a ghost. Enable its display in Settings. The live delta compares your elapsed time with the ghost at the corresponding distance: a negative value means ahead. Ghosts are reference replays, not opponents with collision physics.

The minimap shows the circuit and car. Four tire cards show surface temperature, with warm/overheated colour; detailed core temperature and wear remain in the debug view. The surface reacts quickly to slides; the core changes more slowly. Simcade starts at the optimum temperature and compresses its effect on grip. Simulation starts warm and retains stronger temperature and wear effects. Curbs are raised: riding one tilts the car and shakes the tires. The tachometer shows RPM, speed, gear and a shift lamp. Aid levels stay visible and brighten while assistance acts. Pause with Esc, the controller menu button or the on-screen Pause button. The Time sheet lists completed laps, sectors, validity/best flags and top speed, with Retry, Change car, Change circuit and Main menu. A completed lap also enables Last-lap replay; Back returns to the time sheet.

B toggles detailed vehicle information and wheel-force lines. Y toggles a rolling ten-second graph of speed, throttle, brake and steering. The graph scales values for comparison; it is not a raw data export. Debug information is intended to help understand vehicle behavior and diagnose changes.

## Garage and setups

Open Garage or press G. Its seven tabs contain the original tuning controls: Tires, Suspension, Aero, Brakes, Diff, Gearing and Aids. Values are constrained to their supported ranges. Change one or two values at a time and compare the same section of track.

Tires affect available grip and temperature behavior. Suspension affects body motion and load distribution. Aero changes speed-dependent forces. Brakes affect stopping and balance. Differential settings affect how driven wheels share torque. Gearing changes the relationship between road speed and engine RPM. Aids adjust driving assistance.

Close the garage to apply a changed setup. The car resets and loads the record associated with that setup. Save as creates a named setup. Load restores one; loading a setup for another car also changes the car. Defaults restores that preset's tuning. Import and Export exchange setup JSON with the browser version or another native installation.

## Creating a circuit

Open Editor with F2, then New circuit. Unsaved changes are protected by a discard confirmation. Click three separated positions in the central workspace to create the first closed loop. Add more points with Insert or by double-clicking an edge. Use broad, smooth bends before fine-tuning.

Select a point and drag it to reshape the road. Properties exposes X/Y, full width, height and bank angle. Width is 4–40 m. Height is in meters and bank is in degrees; positive bank raises the left edge in the driving direction. Elevation follows a smooth curve between points.

Use Start / finish and click the road to place the timing line. Use Grid position to choose a spawn point. Without an explicit grid, the car starts ten meters before the start. A circuit needs at least three useful points and a start line before it can be saved or test-driven.

The height profile under the map shows elevation along the lap from the start line, coloured by gradient (green under 6 %, amber under 12 %, red steeper). Drag a point's dot up or down to change its height; hold Shift for 0.5 m steps. H shows or hides it. Properties also has Reverse direction, Smooth heights and a width for all points.

Import real circuit (in the tool list and the circuit library) reads a GPX track, a GeoJSON line or polygon, or an OpenStreetMap export (.osm; ways tagged highway=raceway are joined). The outline is converted to metres, simplified to control points at 12 m width, and uses GPS elevation when the file has it. Check the driving direction, start line and widths, then save.

Automatic trackside barriers (on by default, in Properties) place armco around the lap and tire walls on the outside of slow corners, set back further where the corner is fast. They are solid. Turn them off for an open airfield-style layout.

Properties reports blocking errors and warnings. Very steep slopes or a crossing layout may be driveable but behave poorly. The game does not model bridges or cars becoming airborne, so avoid relying on vertical separation at crossings.

## Editor tools and navigation

Tool shortcuts:
• 1 Select / move; 2 Insert point; 3 Curb override.
• 4 Paint grass; 5 Paint gravel; 6 Erase paint. Paint tarmac runoff is in the tool list (no number key): near-road grip, but it counts as off the circuit for track limits.
• 7 Wall; 8 Tire barrier; 9 Cone; 0 Start / finish.
• Grid position and Pan are available as buttons.

Curbs can be automatic, on or off for a segment. The curb tool cycles that setting; Properties also offers a selector. Curbs apply to both road edges on that segment.

Drag a paint brush across the ground; adjust its radius in Properties. Paint changes off-road surfaces, not the asphalt underneath. Erase restores the default ground surface. Drag to create a wall or tire barrier. Click to place a cone. Select an object to move it; drag a barrier endpoint to resize it. Cones reset to their placed positions each lap.

Wheel or pinch zooms around the cursor. Middle drag, Space+drag or Pan moves the view. Settings can make trackpad scrolling pan. Hold Shift or enable Snap to grid; set grid spacing in Properties. F frames the whole circuit.

Cmd/Ctrl+Z undoes; Cmd/Ctrl+Shift+Z or Cmd/Ctrl+Y redoes. On macOS use Command; Control also works. A continuous drag or paint stroke is one undo step. Delete removes the selection. Brackets change selected-point width. Comma/period change height; hold Shift for larger height steps. Semicolon/apostrophe change bank.

## Saving and test driving

Cmd/Ctrl+S or Save stores the circuit in the selected data folder. Give an untitled circuit a name. Save as in Circuits creates a separately named copy. Built-in resources are protected; editing a built-in circuit saves a user version. The saved version appears separately in the circuit list.

T starts a test drive from the grid; Escape returns to the editor. You can repeatedly adjust, test and return. Test driving does not automatically save your changes. The Properties heading indicates unsaved edits. Save before closing the game if you want to keep them.

Circuits provides Load, Rename, Delete, Import JSON, Export current and a copy/paste text area. Fill / copy current places the document in the text area and clipboard. Load text validates the pasted document and opens it for editing. Imported tracks remain unsaved until you save them.

Rename or delete operates on saved files, so take care when using a shared folder. Deletion asks for confirmation. Cancelling an unsaved-change prompt retains your current work.

## Files, ghosts and portability

Default saves are under %APPDATA%/Godot/app_userdata/Racing Sim/ on Windows, or ~/Library/Application Support/Godot/app_userdata/Racing Sim/ on macOS. Circuits → Choose folder connects another directory using tracks, setups, ghosts and records subfolders. Local saves switches back to the default location; Rescan refreshes the library. Settings remain in the local application folder.

The native game reads browser-compatible track, setup and ghost JSON. To move data held only in browser localStorage, first export it from the browser. Selecting a folder does not read private browser storage. Existing exported files can be selected individually or through their racing-data folder.

Native best laps are separated by circuit configuration, car, tuning and race rules. A per-track exchange ghost is also maintained for browser compatibility. Older imported ghosts may lack setup/rule information, so treat them as reference laps rather than certified comparisons. Explicit ghost import assigns the replay to your current configuration.

Circuits includes Import ghost, Export ghost and Clear best lap. Clearing removes the current configuration's best and the track's exchange ghost; other native configuration records remain. Back up the racing-data folder to preserve circuits, named setups and records.

## Remapping and troubleshooting

Open Settings → Controls. Click a keyboard binding, then press the replacement key. Click a controller binding, then press a button or move an axis. Escape cancels capture. Steering needs a signed axis; pedals use positive trigger travel. Reset mappings restores defaults. Deadzone and steering-response controls tune controller feel.

If the car will not move, close any menu/dialog, leave the editor, resume from pause and check gear/input bindings. Reset with R if needed. A circuit that refuses to test-drive needs its blocking Properties errors resolved, usually insufficient points or a missing start line.

If a saved circuit is missing, verify the connected folder and press Rescan. An imported circuit must still be saved. A failed write appears in the status line; choose a writable folder. User circuits do not overwrite bundled resources inside the executable.

Native builds target Windows x64 and macOS (Apple Silicon and Intel). Mac validation limits are recorded in the source project’s godot/docs/MACOS.md. Rendered checks have passed on the Windows RTX 4080 and macOS Apple M4 using Metal. Intel Macs, other GPUs and real controller hardware need further testing. There is no multiplayer, force feedback or airborne vehicle simulation. The source project's godot/docs directory contains architecture, file formats and maintenance instructions for developers and LLMs.
