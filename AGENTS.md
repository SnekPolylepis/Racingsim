# Racing Sim: entry point for coding agents

This workspace is a native Windows and macOS racing game built in Godot 4.6.2. All source, assets, data, tests and documentation live in `godot/`.

**A rebuild is in progress** (6-DOF chassis, authored 3D tracks, in-game editor removed). Several models work on it in turn. Read `godot/docs/REBUILD-PLAN.md` and the latest entries in `godot/docs/REBUILD-LOG.md` before anything else, and follow the plan's working protocol (§9). Inside a rebuild task the plan overrides older docs.

Otherwise, start with `godot/docs/LLM-GUIDE.md`, then the relevant architecture, data-contract or testing document linked there. Launch through `Play Racing Sim.cmd` on Windows or `Play Racing Sim.command` on macOS. The exported executable is generated; edit source and rebuild it.

Native packaging targets Windows x64 and macOS universal (Apple Silicon/Intel). Read `godot/docs/MACOS.md` for Mac build instructions and recorded validation limits; architecture availability does not establish hardware validation.

A browser implementation (`racing-sim.html`) was removed on 2026-09-22. It remains in git history if you need to consult it, but it is not part of the project and should not be revived, referenced as a physics reference, or treated as a compatibility target. Native physics is authoritative.

Preserve user files in root `tracks/`, `setups/` and `ghosts/`, and in connected save folders. These are a portable save location the game can be pointed at through **Circuits → Choose folder**; the game's own default save directory is under `%APPDATA%` / `Application Support`. Native tests use a separate `user://native-tests` directory. Do not treat generated test files as user defaults.

Keep documentation synchronized with actual source, and distinguish recorded test results from guarantees. Dated evidence in `godot/docs/CHANGELOG.md`, `PS2-SIMCADE-REPORT.md` and `MACOS.md` is a record of runs that happened; correct it only when it was wrong when written, not to match later changes.

No delegation or approval requirements are introduced by this file.
