# Spa v0 and the TrackAsset dev drive scene

P6-01 is an owner-directed first playable build on `rb/P6-01-spa`. It uses the new 6-DOF car and authored TrackAsset tools. This branch is pushed for review without merging to main or replacing the exported game.

## Drive from this worktree

Open PowerShell in `C:\Users\Zain's PC\Desktop\RacingSim-spa\godot` and run:

```powershell
.\tools\Godot.exe --path . res://scenes/proving/track_drive.tscn
```

To reach both dev entries through the source game's main menu, run:

```powershell
.\tools\Godot.exe --path .
```

Choose **Drive Spa (dev)** or **Drive proving ground (dev)**. The root `Play Racing Sim.cmd` launches the existing export, so it will not show these new source-only entries until a later export.

The same scene accepts a generated circuit id or an explicit TrackAsset scene:

~~~powershell
.\tools\Godot.exe --path . res://scenes/proving/track_drive.tscn -- --track=proving_ground
.\tools\Godot.exe --path . res://scenes/proving/track_drive.tscn -- --track-scene=res://tracks3d/spa/spa.scn
~~~

Driving uses WASD / arrows or the existing gamepad controls. **R** resets to grid slot 1, **C** cycles cars, **M** switches Simulation/Simcade, **F1** toggles the HUD, **F2** switches chase/free-fly camera, and **Esc** returns to the source game's main menu. Free-fly pauses the car: move with WASD, Q/E down/up, Shift for faster movement, and hold the right mouse button to look.

## Scope of the check

The owner requested only the game-script parse, the Spa generator bake and validation, and a 20-second headless Ferrari 296 BotLine drive. Those results and the source data limitations are recorded in the P6-01 DONE entry of [REBUILD-LOG.md](../REBUILD-LOG.md). No full-lap, exported-build, broad regression, or visual playtest result is implied.

Source acquisition and processing are recorded in [the data README](../../trackgen/data/spa/README.md) and [THIRD-PARTY.md](../../THIRD-PARTY.md).
