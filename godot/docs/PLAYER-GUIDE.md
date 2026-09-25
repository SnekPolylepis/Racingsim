# Racing Sim — player handbook

This handbook describes the rebuilt game (Rebuild Preview 1 onward): a full 3-D car on hand-built 3-D circuits. In-game Help reads it chapter by chapter, so each chapter is plain text.

## Getting started

On Windows run RacingSim.exe. On macOS open Racing Sim.app. The first time, right-click it and choose Open, because the app is not notarized. No installation, browser or Godot editor is needed, and nothing is downloaded while you play.

In the menu choose Race, pick a car, then pick a circuit and choose Load circuit. The first time a circuit is opened it is built from its data, then cached. Spa takes about half a minute to build, and later loads are quick. You start on the grid, and the lap timer starts when you first cross the start line. Esc returns to the menu at any time.

## Circuits and cars

The Proving Ground is an invented test circuit of about 2.5 km. It is the place to learn how the car behaves at the edge. It has:
- a banked bowl;
- a crest you can take off from at about 150 km/h in the 296;
- a compression and off-camber corners;
- a concrete ditch and every kind of kerb.

Spa-Francorchamps is built from real survey data:
- the OpenStreetMap centreline;
- the Walloon government's LiDAR elevation and road banking;
- road widths and kerbs measured from its 2023 aerial photographs.

Eau Rouge and Raidillon climb as they really do. Runoff areas are approximations for now.

The cars are the Mazda MX-5 (NA 1.6), a GT car with high downforce, and the Ferrari 296 GT3. The car models are placeholders; better ones are coming.

## Driving and gear changes

Keyboard controls:
- W or Up accelerates; S or Down brakes.
- A/D or Left/Right steer.
- Space is the handbrake and C the clutch.
- E or Shift changes up; Q or Ctrl changes down.
- R puts the car back on the grid and cancels the lap in progress.

With a controller, the left stick steers, the triggers are throttle and brake, and the bumpers change gear.

The car is a true 3-D body on four suspension corners, with tyre flex and wheel mass. It leans, pitches, lifts wheels, rides kerbs, crests, flies, and can roll over.

Kerbs push the car up and back, and hitting a square edge costs speed. Walls stop the car, and cones can be knocked over. Grass and gravel have much less grip than tarmac, and running wide onto them invalidates the lap.

## Handling and aids

This preview drives with Simcade handling: forgiving tyres that hold their grip over a wide slip range, stability management (ASM 3), traction control (TCS 3), ABS and a steering assist.

Simulation handling keeps the full tyre model, with no assists by default. It and the aid levels will be selectable once the settings menu arrives in the new front end. Best laps are kept separately for each handling model, car and setup.

## Cameras, display and sound

V cycles the cameras: chase, high chase, bonnet (it leans with the car), overhead north-up, and overhead following the car.

The HUD shows:
- the lap timer, best and last laps, and whether the lap is valid;
- sector splits and the live delta to your best;
- a minimap and tyre temperatures;
- the speedometer with gear and RPM.

Y toggles the telemetry graph and B the debug readout.

The engine sound is built from recordings, blended by RPM and load. Tyres squeal by surface and slip, and impacts sound when you hit something. Sky, fog and lighting follow the time of day.

## Laps, sectors and ghosts

A lap counts from start line to start line, through every timing gate in order. The lap becomes invalid if you:
- miss a checkpoint;
- put all four wheels off the track;
- hit a wall, when contact rules are on.

The HUD says why. Each lap is split into three sectors. Purple is your best ever for this car, setup and handling model; green is the best of this session; yellow is slower.

Your best valid lap is saved with its ghost: a translucent blue car that drives your best lap alongside you, from the start line until its lap time runs out. The delta at the top of the screen shows how far ahead (green) or behind (red) you are at this point of the lap.

## Files and saves

Best laps, ghosts, sector times and settings save automatically under your application data folder:
- Windows: %APPDATA%/Godot/app_userdata/Racing Sim/v2/
- macOS: ~/Library/Application Support/Godot/app_userdata/Racing Sim/v2/

Built circuits are cached in the tracks3d folder beside it. Deleting that cache is always safe; the circuit is rebuilt on its next load. Records from the pre-rebuild game are kept separately and do not carry over.

## Troubleshooting and known limits

If a circuit takes a long time to load the first time, that is the one-off build; later loads use the cache. If the game ever starts with odd settings, deleting the v2 settings.json restores the defaults. Physical controllers work through Godot's standard gamepad mapping; wheels and force feedback are not supported.

This is a preview:
- Only the Proving Ground and Spa are available; the Nordschleife is in progress.
- The old game's settings, garage and pause menus are being moved to the new front end.
- Car models are placeholders and scenery is sparse.
- There is no night lighting on the new circuits yet.

## Chicago — River & Lake

Choose Chicago — River & Lake in the circuit picker for an 8.12 km city lap. Drive Michigan Avenue
past Millennium Park, Jackson Drive, Lake Shore Drive, Lower Wacker and Upper Wacker. The route
includes the Bean, Willis Tower, Navy Pier, the Chicago River and Lake Michigan. Try both daylight
and Afterhours for the skyline and the lamps under Lower Wacker.

This is an authored racing route with two fictional ramp connectors, not a surveyed public-road
layout or the NASCAR Chicago circuit. Both Wacker levels are drivable and have separate timing
gates. Road geography: © OpenStreetMap contributors, ODbL 1.0; openstreetmap.org/copyright.
