# macOS build and validation

> **Rebuild note (2026-09-23):** the macOS preset exports the v2 game. `tools/macos.zip` is the template, and the release zip keeps the app binary executable. The flows below (Circuits, Choose folder, the feature suite) describe the legacy game. The v2 game saves under `Racing Sim/v2/` and has not yet been run on a Mac.

The native Godot game has a universal macOS export containing arm64 (Apple Silicon) and x86_64 (Intel). It uses Forward+ with Metal and retains the project's OpenGL fallback. The browser game is separate and unchanged.

## Play

Open `godot/build/macos/Racing Sim.app`, or double-click `Play Racing Sim.command` in the workspace root. The distributable is `godot/build/RacingSim-macOS.zip`; it includes the app and engine/asset notices. The exported app runs offline without Python, Godot or Xcode installed.

Control shortcuts work across dialogs and menus. Apple keyboards may need Fn/Globe for F11 (fullscreen); fullscreen is also available in Settings.

Saves default to `~/Library/Application Support/Godot/app_userdata/Racing Sim/`. Choose folder in Circuits can connect the existing portable data folders. The app bundle is read-only game content, never a save destination. Verification uses `native-tests` beneath the same application data directory, separate from normal saves.

## Rebuild

From the workspace root, with Python 3 installed:

```sh
python3 godot/packaging/fetch-macos.py
bash godot/packaging/build-macos.sh
```

The fetcher downloads the official Godot 4.6.2 universal editor into `godot/tools/Godot.app` and extracts only `templates/macos.zip` from that release's export-template archive into `godot/tools/macos.zip`. It leaves existing tools in place. No system installation or Python packages are required. The build script checks the editor version, imports assets, exports, verifies the ad-hoc signature and packages the app with notices. `GODOT_BIN` can override the editor executable.

Without Python, download the macOS universal editor and export templates from the [official 4.6.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.6.2-stable). Extract `Godot.app` into `godot/tools/`; extract the template archive's `templates/macos.zip` into `godot/tools/` without unpacking that inner ZIP. Then run the build command above. Xcode developer tools are not needed for Godot's built-in ad-hoc signer.

This is a local ad-hoc signed build, not a Developer ID/notarized public release. A downloaded copy may require System Settings → Privacy & Security → Open Anyway. See [Godot's macOS distribution documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html). Public notarization requires the owner's Apple signing credentials and is a separate release step.

## Verify

From `godot/`:

```sh
GODOT_BIN="$PWD/tools/Godot.app/Contents/MacOS/Godot"
"$GODOT_BIN" --headless --path . --script scripts/game.gd --check-only
"$GODOT_BIN" --headless --path . --script tests/handling.gd
"$GODOT_BIN" --headless --path . --script tests/dynamics.gd
"$GODOT_BIN" --headless --path . --script tests/dynamics.gd -- --simcade
"$GODOT_BIN" --headless --path . --script tests/validation.gd
"$GODOT_BIN" --headless --path . --script tests/laps.gd
"$GODOT_BIN" --headless --path . --script tests/laps.gd -- --simcade
"$GODOT_BIN" --headless --path . --script tests/showcase_laps.gd
"build/macos/Racing Sim.app/Contents/MacOS/Racing Sim" -- --features
```

The feature suite requires a graphical login session; do not add `--headless`. It exercises rendered UI, audio PCM, driving, save round trips and full-lap frontend flows. Inspect stderr as well as `~/Library/Application Support/Godot/app_userdata/Racing Sim/native-tests/feature-results.json`. For the fallback renderer, repeat with `--rendering-method gl_compatibility` before `--`.

## Recorded validation — 2026-09-22

Host: Apple M4, macOS 27.2 (26B5086k), Godot 4.6.2 stable. Rendered tests used Metal 4.0 / Forward+. These are results from this machine, not cross-hardware guarantees.

| Check | Recorded result |
|---|---|
| Export and signature | Universal arm64 + x86_64; `codesign --verify --deep --strict` passed |
| Exported feature suite | 261 checks, zero failures; no engine/script errors in the log |
| Exported fresh-default title review | 7 checks, zero failures |
| Source script parsing | Passed |
| Native handling | 23 checks, zero failures |
| Simulation vehicle dynamics | 34 checks, zero failures |
| Circuit import | 9 checks, zero failures |
| Geometry validation | 103 checks, zero failures |
| Four-circuit Simulation laps | All passed; zero off-track steps and barrier contacts |
| Changed GDScript formatting | Passed gdformat 4.5.0, line length 110 |
| Root Mac launcher | Opened the exported app successfully |

Simulation laps were Ridgeback 96.12 s, Oval 42.78 s, Monza 260.31 s and Spa 323.00 s. These are automated regression laps, not competitive benchmarks. The handling suite initially failed because it wrote the removed `car.parity` property; the stale setup/comparison was removed and native assertions passed on rerun.

The separate extended `showcase_laps.gd` run was stopped before completion. It recorded valid Simulation-pad and Simcade-pad laps, but this is not a pass for the full suite. The separate headless Simcade dynamics and four-circuit lap commands were not reached. The exported feature suite completed its own frontend driving flows. The commands above describe how to run all suites; they do not claim every listed command completed in this session.

Exported JSON reports and screenshots are under `~/Library/Application Support/Godot/app_userdata/Racing Sim/native-tests/`, including `feature-results.json` and `title-results.json`. Local logs are `/tmp/racingsim-macos-*.log`; temporary logs may disappear and subsequent runs replace reports. The app was rebuilt after formatting and documentation updates; the full feature suite was not repeated after those nonbehavioral changes.

## Remaining validation and release limits

- The macOS CI workflow has not yet run on GitHub. CI covers export and headless tests, not rendered acceptance.
- Intel hardware and the Mac OpenGL fallback have not been exercised. Both architectures are packaged; only Apple Silicon / Metal was run locally.
- Physical controller behavior, trackpad feel and subjective audible output quality remain untested. Audio PCM checks do not establish those results.
- No complete Mac performance matrix was measured. Existing Windows RTX 4080 timing reports remain Windows-only evidence.
- The app is ad-hoc signed; Developer ID signing and public notarization have not been performed.
