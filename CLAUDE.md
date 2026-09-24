# CLAUDE.md — orientation for AI coding assistants

This folder is **Racing Sim**: a native Windows and macOS racing game built in Godot 4.6.2. The whole project is in `godot/`. Also honored by other assistants; the name is just convention.

The game is the rebuilt one: a 6-DOF car (`scripts/vehicle/car_body.gd`) on authored 3-D TrackAssets (`trackgen/*.gd`), with the v2 front end, records and presentation in `scripts/game.gd`. The pre-rebuild game was deleted in P7-01 (2026-09-23). Work is still organised by `godot/docs/REBUILD-PLAN.md`, `godot/docs/REBUILD-LOG.md` and the task queue `godot/docs/rebuild/QUEUE.md`; follow the plan's working protocol (§9). The owner's graphics target is a PS2-era look (NFS Underground × Gran Turismo 4).

Start here, in order:

1. `AGENTS.md` — scope and what to preserve.
2. `godot/docs/LLM-GUIDE.md` — source map, change recipes, high-risk assumptions, verification. This is the authoritative guide; the rules below are a summary of it, not a replacement.
3. `godot/docs/ARCHITECTURE.md`, `godot/docs/DATA-CONTRACTS.md`, `godot/docs/PHYSICS.md` as needed. `godot/docs/SOLVER-MATH.md` derives the shared tyre and drivetrain equations.

Hard rules:

- Physics runs at a fixed 240 Hz. Don't remove the semi-implicit "need" clamps in the tyre/clutch/diff code.
- SI units; wheel order FL, FR, RL, RR; body frame +X forward, +Y up, +Z right; positive bank lowers the right side. Tyre `wear` grows from zero; it is not remaining tread.
- CarBody world position and velocity are 64-bit scalars (`pos_x/y/z`, `vel_x/y/z`); use `pos_y` and each wheel's `roadZ` for heights (CarBody has no `car.z`).
- Surface queries (`TrackSurface.contact`) only work inside a physics frame (`_physics_process`).
- A track generator must keep the RoadPath bank change under 0.20°/m and the terrain's tapered under-road drop, and every file it reads at runtime must be in the export presets' `include_filter` and `check_exported_v2_assets()`.
- Format with gdtoolkit after edits: `gdformat -l 110 scripts tests` from `godot/` (CI checks it).
- Don't rewrite whole files from memory. Edit the specific function.
- `res://` is read-only in an exported build. Never save beside packaged resources through that URI.

Verify before declaring done, from `godot/` (Windows shown; on macOS the binary is `tools/Godot.app/Contents/MacOS/Godot`):

```
tools/Godot.exe --headless --path . --script scripts/game.gd --check-only
powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1 -All
powershell -ExecutionPolicy Bypass -File tools/run_gates.ps1 -All -Features
```

`run_gates.ps1` runs every headless suite in `tools/gates.json` in parallel. `-Features` adds the windowed check (`tools/Godot.exe --path . -- --features`, the same as `-- --v2-present`), which needs a real window — do not add `--headless`. Before a release also export and run `RacingSim.exe --headless -- --v2-export-check`. See `godot/docs/TESTING.md` for the full matrix and `godot/docs/MACOS.md` for Mac specifics.

Data folders (`tracks/`, `setups/`, `ghosts/`) at the repo root are user files from the pre-rebuild game; don't delete or reformat them. The game saves under `user://v2`.

A browser implementation (`racing-sim.html`) was removed on 2026-09-22. It is in git history only. Don't revive it or treat it as a physics reference.
