---
name: verify
description: Check a Racing Sim change before calling it done — format, parse check, launch/drive smoke, optional gates. Use after editing any .gd file or before committing/merging.
---

# Verify a change

Run from `godot/`. Godot is `tools/Godot.exe` (Windows) or `tools/Godot.app/Contents/MacOS/Godot` (macOS); if neither exists (e.g. a cloud container), say so and do only steps 1–2 that can run.

1. **Format** (CI runs `gdformat -l 110 --check scripts tests`):
   `gdformat -l 110 <the .gd files you touched>`
2. **Parse check:**
   `tools/Godot.exe --headless --path . --script scripts/game.gd --check-only`
3. **Required bar (owner direction 2026-09-28):** the game launches, loads the track and drives without crashing. Launch windowed with `tools/Godot.exe --path .`, or run the touched track's suite headless (`tests/v2/<suite>.gd`, listed in `tools/gates.json`).
4. **Optional, when cheap or something looks off:**
   - `powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1` (only suites the branch touched)
   - `... run_gates.ps1 -All` / `-All -Features` (Features needs a real window; never add `--headless`)
   - Failed run → `python3 tools/gate_triage.py` for a likely cause.

Rules:
- Godot.exe is a GUI-subsystem binary: never trust its exit code alone; read stderr.
- Run every Godot invocation with a timeout; a timeout is a failure.
- Read your diff (`git diff origin/main...HEAD`): no conflict markers, no stray files, `.uid` sidecars committed with their scripts.
- Report failures as failures, with the output.

Full matrix: `godot/docs/TESTING.md`.
