# Racing Sim — Windows and macOS native

Double-click **build/RacingSim.exe**, or **Play Racing Sim.cmd** in the project root. The executable includes the game and runs offline without a browser or an installed Godot editor. Windows targets x64. On macOS, open **build/macos/Racing Sim.app** or **Play Racing Sim.command** in the project root. The Mac bundle contains Apple Silicon and Intel code; see [Mac build and validation](docs/MACOS.md).

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Accelerate / brake | W / S or arrows | RT / LT |
| Steering | A / D or arrows | Left stick |
| Handbrake | Space | X |
| Shift up / down | E / Q, also Shift / Ctrl | A / B |
| Clutch | C | LB |
| Reset to grid | R | Back |
| Pause menu / close window | Esc | Start |
| Automatic / manual gearbox | M | — |
| Cycle five cameras | V | — |
| Garage | G | — |
| Vehicle debug / telemetry | B / Y | — |
| Fullscreen | F11 | — |

Driving inputs can be remapped in Settings. In automatic mode, hold the brake while stopped to switch forward/reverse, then accelerate. Manual mode offers optional automatic clutch assistance.

## Included

- Monza, Spa and the Nürburgring Nordschleife; roadster (a 1990 Mazda MX-5, NA 1.6: 2.265 m wheelbase, 955 kg, 136 Nm, 7200 rpm redline, five-speed, 185/60R14, no ABS or traction control), GT and Ferrari 296 GT3 parameter presets. Spa is built from OpenStreetMap data (© OpenStreetMap contributors, ODbL) with real DEM elevation; see `trackgen/`.
- Original fixed 240 Hz four-wheel vehicle dynamics: Pacejka tires, load transfer, suspension, clutch, differential, gearing, ABS/TC, temperature, optional wear, slope gravity and crest/dip loading. Native additions: per-wheel road height (raised, ridged curbs; crest and bank geometry act through the suspension), surface + core tire temperatures and self-aligning torque output.
- Dedicated procedural 296 GT3 and lofted roadster/GT bodies with arches, lights, aero parts, liveries and detailed wheels; render interpolation between physics ticks for smooth motion at any refresh rate.
- Console presentation at 640×448 SD / 720p / Native, 4:3 or anamorphic 16:9, clean 480p component, optional 480i fields and CRT/composite. Authentic low-resolution menus/HUD are default; Sharp UI is optional. Offline CLUT/RGB555 texture builds, reflective paint, crossed-card woods, lamp halos and GPU history blur work on both renderers.
- Original boot/title/idle driving demo, race mode, car/setup/paint/rim and circuit selection, real preparation stages, grid countdown, pause, lap time sheet and last-lap replay. Keyboard, controller and mouse navigation; synthesized menu sounds.
- Simcade (default) or the preserved Simulation handling model, separate records, TCS/ASM 0–10 and ABS, with compatible legacy setups.
- Native 3D elevation and banking, road surfaces, mixed pine/broadleaf woods, shrubs and distant hills, corner labels, grid markings, painted sky lighting, contact-patch blob shadows plus directional shadows at Medium and High, wheel rotation/steering, suspension movement, night-gated headlights on every car, brake lights and skid marks.
- Lap checkpoints, configurable off-track/contact invalidation, best-lap ghosts, live delta, minimap, tire status, debug forces and a ten-second telemetry graph.
- All 42 original setup fields supported, with numbered aid controls in the garage, grouped in seven tabs; named setups, preset switching, defaults, import/export and deletion.
- Five cameras, quality/adaptive quality, units, keyboard/gamepad remapping, deadzone, steering response and speed-sensitive steering (separate keyboard/controller strengths).
- Synthesized RPM/throttle engine audio, tire squeal, surface noise, gear changes and impacts. Master, engine and effects levels plus mute; sound fades out when paused or in menus.
- Circuit library with bundled circuit selection and ghost import/export. Native folder selection supports existing portable setups, ghosts and records.

## Files

Default saves: `%APPDATA%/Godot/app_userdata/Racing Sim/` on Windows; `~/Library/Application Support/Godot/app_userdata/Racing Sim/` on macOS. Use **Circuits → Choose folder** to connect an existing racing data folder for portable setups, ghosts and records. Setup and ghost JSON in the original browser format is still read.

Native best laps are separated by geometry, car, setup, handling model and race rules in `records/`. A compatible per-track ghost is also maintained in `ghosts/` as a portable exchange format. Legacy ghosts in that format are read automatically in Simulation for their matching car; imported ghosts are explicitly assigned to the current configuration. Settings are stored locally regardless of the selected data folder.

## Development and verification

Open `project.godot` with Godot 4.6.2 and press F5. There are no plugins or external runtime dependencies. Physics uses the original `(x,y,height)` coordinates; rendering maps them to Godot `(x,height,y)`. The car follows the road surface; free airborne dynamics are not modeled. Car meshes and scenery are simple procedural artwork, not licensed manufacturer models. Engine audio uses vendored CC0 recordings with RPM/load crossfades; road, tire and mechanical effects remain synthesized. See THIRD-PARTY.md for the source credits.

For macOS, run `python3 godot/packaging/fetch-macos.py` then `bash godot/packaging/build-macos.sh` from the workspace root. This produces `build/macos/Racing Sim.app` and `build/RacingSim-macOS.zip`. The local Apple M4 / Metal run passed 261 exported integration checks and 7 fresh-start checks. See [Mac build and validation](docs/MACOS.md) for the complete evidence and untested cases.

On Windows, `tools/Godot.exe` is a project-local editor copy. The Windows preset uses local templates. Rebuild from this directory:

```powershell
& .\tools\Godot.exe --headless --path . --export-release "Windows Desktop" build/RacingSim.exe
```

Windows checks from this directory:

```powershell
& .\tools\Godot.exe --headless --path . --script tests/laps.gd
& .\tools\Godot.exe --headless --path . --script tests/handling.gd
& .\tools\Godot.exe --path . -- --features
& .\build\RacingSim.exe -- --features
```

- Full-lap regression drives Monza and Spa with zero off-track steps and valid recorded ghosts.
- Native integration checks cover driving, all cars/tracks, audio capture/mute/pause, remapping, garage/settings, dirty guards, JSON round trips, record storage and smaller-window layout. Screenshots and `feature-results.json` go to `tests/` for source runs and `user://native-tests/` for exported runs. Test saves/settings are isolated in `native-tests`.

The game uses Godot's Forward+ renderer with an automatic OpenGL fallback. The follow-up tests both Forward+ and OpenGL on the local RTX 4080; see the dated report for the measured full-lap matrix. Physical controller hardware has not been tested. macOS uses Metal by default; validation and build instructions are in [MACOS.md](docs/MACOS.md).

## Godot notices

Godot Engine is MIT licensed. The Windows and macOS packages include the engine license and third-party notices from the official 4.6.2 release.

## Detailed documentation

- [Player handbook](docs/PLAYER-GUIDE.md), also available chapter by chapter in Help.
- [LLM / maintainer guide](docs/LLM-GUIDE.md): source map, change recipes and invariants.
- [Architecture](docs/ARCHITECTURE.md): ownership, frame order and coordinates.
- [Data contracts](docs/DATA-CONTRACTS.md): schemas, storage paths and compatibility.
- [macOS build and validation](docs/MACOS.md): Mac setup, packaging, results and limits.
- [Testing and release](docs/TESTING.md): exact commands, thresholds, evidence and troubleshooting.

## PS2-era graphics

The default session pairs Spa-Francorchamps with the Ferrari 296 GT3. Afternoon is the default lighting preset; Afterhours offers an indigo sky with amber circuit lighting, original amber event signage and stylized glossy asphalt. Both use the shared console world/HUD/menu output chain. The 296 now has dedicated reference-built bodywork with sculpted fenders, recessed lights, hood duct, flying buttresses, silver racing wheels, tricolour sills and swan-neck wing. The presentation follows researched PS2-era constraints with original content; it does not emulate the GS chip or an electrical NTSC signal. Wet-looking surfaces retain the existing driving grip. See [art direction](docs/ART-DIRECTION.md) and the [296 model authoring guide](docs/CAR-MODEL.md).

See [handling models](docs/PHYSICS.md) and the [dated delivery report](docs/PS2-SIMCADE-REPORT.md) for measured results and screenshot paths.

Follow-up research, licenses, screen flow, comparison rounds and full-lap acceptance: [PS2 follow-up report](docs/PS2-FOLLOWUP-REPORT.md), [reference study](docs/PS2-REFERENCE.md), [download ledger](THIRD-PARTY.md).
