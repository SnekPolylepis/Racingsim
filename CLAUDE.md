# CLAUDE.md — orientation for AI coding assistants

This folder is **Racing Sim**: a native Windows and macOS racing game built in Godot 4.6.2. The whole project is in `godot/`. Also honored by other assistants; the name is just convention.

**A rebuild is in progress.** Read `godot/docs/REBUILD-PLAN.md` and the latest entries in `godot/docs/REBUILD-LOG.md` first. Inside a rebuild task, the plan overrides the rules below; follow its working protocol (§9).

Start here, in order:

1. `AGENTS.md` — scope and what to preserve.
2. `godot/docs/LLM-GUIDE.md` — source map, change recipes, high-risk assumptions, verification. This is the authoritative guide; the rules below are a summary of it, not a replacement.
3. `godot/docs/ARCHITECTURE.md`, `godot/docs/DATA-CONTRACTS.md`, `godot/docs/PHYSICS.md` as needed. `godot/docs/SOLVER-MATH.md` has the full vehicle-model derivation.

Hard rules:

- Physics runs at a fixed 240 Hz. Don't remove the semi-implicit "need" clamps in the tire/clutch/diff code. (The old "don't replace the custom solver" rule is withdrawn; the rebuild plan decides the chassis design.)
- SI units; wheel order FL, FR, RL, RR; body lateral/right is positive. Control-point bank is degrees, sampled bank and car heading are radians.
- `car.z` is suspension heave, not altitude. `car.elev` is terrain elevation. Tire `wear` grows from zero; it is not remaining tread.
- After editing track geometry call `track.rebuild()`; rebuild derived samples before anything queries them. `track.barriers` are derived and never serialized.
- Wrap editor document mutations in `begin_change()` / `commit_change()`.
- Format with gdtoolkit after edits: `gdformat -l 110 scripts tests` from `godot/` (CI checks it).
- Don't rewrite whole files from memory. Edit the specific function.
- `res://` is read-only in an exported build. Never save beside packaged resources through that URI.

Verify before declaring done, from `godot/`:

```
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/game.gd --check-only
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/laps.gd
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/handling.gd
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/dynamics.gd
tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/validation.gd
```

On Windows the binary is `tools/Godot.exe`. The rendered feature suite (`tools/Godot.app/Contents/MacOS/Godot --path . -- --features`) needs a real window — do not add `--headless`. See `godot/docs/TESTING.md` for the full matrix and `godot/docs/MACOS.md` for Mac specifics.

Data folders (`tracks/`, `setups/`, `ghosts/`) at the repo root are user files and a portable save location; don't delete or reformat them.

A browser implementation (`racing-sim.html`) was removed on 2026-09-22. It is in git history only. Don't revive it or treat it as a physics reference.
