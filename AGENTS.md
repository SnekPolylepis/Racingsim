# Racing Sim: entry point for coding agents

This workspace is a native Windows and macOS racing game built in Godot 4.6.2. All source, assets, data, tests and documentation live in `godot/`.

**The game is the rebuild** (6-DOF chassis, authored 3-D tracks, first released as v0.1.0-preview.1; the pre-rebuild game was deleted in P7-01). Several models work on it in turn. Read `godot/docs/REBUILD-PLAN.md`, the latest entries in `godot/docs/REBUILD-LOG.md` and the task queue `godot/docs/rebuild/QUEUE.md` before anything else, and follow the plan's working protocol (§9). The owner's graphics target is a PS2-era look (NFS Underground × Gran Turismo 4).

Otherwise, start with `godot/docs/LLM-GUIDE.md`, then the relevant architecture, data-contract or testing document linked there. Run from source with `godot/tools/Godot.exe --path godot`, or export (`--export-release "Windows Desktop"`); releases are published on GitHub. The exported executable is generated; edit source and rebuild it.

Native packaging targets Windows x64 and macOS universal (Apple Silicon/Intel). Read `godot/docs/MACOS.md` for Mac build instructions and recorded validation limits; architecture availability does not establish hardware validation.

A browser implementation (`racing-sim.html`) was removed on 2026-09-22. It remains in git history if you need to consult it, but it is not part of the project and should not be revived, referenced as a physics reference, or treated as a compatibility target. Native physics is authoritative.

Preserve user files in root `tracks/`, `setups/` and `ghosts/` (saves from the pre-rebuild game) and in any connected save folder. The game saves under `user://v2` (`%APPDATA%` / `Application Support`, `.../Racing Sim/v2/`); tests use `user://native-tests/v2`. Do not treat generated test files as user defaults.

Keep documentation synchronized with actual source, and distinguish recorded test results from guarantees. Dated evidence in `godot/docs/CHANGELOG.md`, `PS2-SIMCADE-REPORT.md` and `MACOS.md` is a record of runs that happened; correct it only when it was wrong when written, not to match later changes.

No delegation or approval requirements are introduced by this file.
