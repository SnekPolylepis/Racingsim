# Racing Sim

A native Windows and macOS racing simulator with simulation-grade vehicle dynamics — hills, crests, banking, per-wheel load transfer and Pacejka tires — plus a built-in circuit editor, garage, telemetry and ghost laps. Built in Godot 4.6.2 with a custom 240 Hz solver rather than Godot's own vehicle physics.

The game lives in [`godot/`](godot/). It runs offline with no server, no installer and no package manager.

## Playing

- **Windows:** double-click `Play Racing Sim.cmd`, or run `godot/build/RacingSim.exe` directly.
- **macOS:** double-click `Play Racing Sim.command`, or open `godot/build/macos/Racing Sim.app`. See [Mac build and validation](godot/docs/MACOS.md).

Controls, file compatibility and what ships in the box are in [the game's README](godot/README.md). Full player instructions are in the [player handbook](godot/docs/PLAYER-GUIDE.md), which is also what in-game **Help** displays.

## Layout

```
RacingSim/
  godot/                 the game: source, assets, data, docs, tests, packaging
  Play Racing Sim.cmd    Windows launcher
  Play Racing Sim.command  macOS launcher
  tracks/   <name>.json  portable circuit files
  setups/   <name>.json  portable car setups
  ghosts/   <track>.ghost.json  portable best-lap ghosts
  prompts/               historical work prompts
  AGENTS.md              entry point for coding agents
```

The three data folders at the root are a portable save location. The game defaults to its own directory under `%APPDATA%` / `Application Support`; use **Circuits → Choose folder** to point it here instead.

## Circuits

Three are included: **Monza**, **Spa-Francorchamps** and the **Nürburgring Nordschleife**. Spa and the Nordschleife are built from OpenStreetMap survey data (© OpenStreetMap contributors, ODbL) with real DEM elevation — 7.004 km and 20.832 km respectively, the latter spanning nearly 300 m of vertical. Widths, curbs, runoff and scenery are approximations, not surveyed reproductions. The offline pipeline that builds them is documented in [`godot/trackgen/`](godot/trackgen/README.md).

You can also draw your own in the editor, or bring in a real circuit outline from GPX, GeoJSON or OSM via **Circuits → Import real circuit…**.

## Documentation

All of it lives in [`godot/docs/`](godot/docs/):

- `LLM-GUIDE.md` — code layout, change recipes and invariants (read first if you are an AI assistant)
- `PLAYER-GUIDE.md` — player handbook, also served by in-game Help
- `ARCHITECTURE.md` — ownership, frame order, coordinate conventions, state transitions
- `PHYSICS.md` — the Simulation and Simcade handling models and their tuning
- `SOLVER-MATH.md` — the full vehicle model derivation, every formula and why it is written that way
- `DATA-CONTRACTS.md` — track / setup / ghost / settings schemas and persistence
- `TESTING.md` — build commands, test suites and recorded evidence
- `MACOS.md` — Mac toolchain, universal packaging and validation limits
- `ART-DIRECTION.md`, `PS2-REFERENCE.md` — the console-era presentation and its sourced constraints
- `CHANGELOG.md` — what has been built, and known limitations

## License

Personal project by Zain. Do what you like with it.

Third-party assets and their licences are listed in [`godot/THIRD-PARTY.md`](godot/THIRD-PARTY.md). Circuit geometry derived from OpenStreetMap is available under the ODbL.
