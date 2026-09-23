# Follow-up 2: PS2-era UI + the benchmark (Ferrari 296 GT3 at Spa)

This adds to the overhaul prompt and the internet/1:1 follow-up. Where anything conflicts, this message wins.

Also note: Blender is not installed on this machine. Only use models that come as `.glb`, `.gltf` or `.fbx`, skip `.blend`-only assets, and don't install Blender.

## 1. The UI goes 1:1 PS2 too

Earlier I said the HUD and menus should stay crisp at native resolution. **Change: the whole front end and HUD should look and feel like a real 2003–2006 PS2 racer**, with GT4 as the main reference and NFSU2 as the reference for Afterhours. That covers layout conventions, typography style, transitions, sounds and pacing. It is still original design: no copied logos, fonts, icons, menu art or wording from any game.

- **Authentic UI is now the default.** The UI renders at the game's internal resolution through the same output chain, so it gets the same scaling, dither, and 480i/CRT effects when those modes are on. Keep a "Sharp UI" setting as an option, not the default.
- **Legibility is a requirement.** Test every screen at 1280×800 and 1920×1080. No text below what a 2004 TV game would use, meaning roughly 16 px at 448 lines. No unreadable scanline mush in the default 480p mode.
- **The circuit editor is exempt from the retro filter.** It's a tool, so it stays sharp and fully mouse/trackpad-usable. Reskin its colours and fonts to match, but don't pixelate it.
- **Research GT4/NFSU2 front ends first** and add a UI section to `PS2-REFERENCE.md` covering screen flow, layout grids, how the selection cursor and highlight move, transitions, loading screens, the button-prompt bar, and menu sound design. Put reference captures in the git-ignored `godot/reference/` folder, as before.

### Screens (every one reachable and escapable with controller only, keyboard only, or mouse)

1. **Boot:** a short original studio/logo card, then the title screen with "PRESS START". A skip button works.
2. **Main menu:** Race (Time Trial / Free Run), Garage, Circuits (library + editor), Settings, Help, Quit. Put an attract/demo loop on the title after idle: the bot drives the 296 around Spa.
3. **Car select:** a showroom turntable with a spec sheet (power, weight, drivetrain, layout), paint/rim choice where presets allow, and a setup picker.
4. **Circuit select:** a track map, length, corner count, elevation profile, best lap/ghost for the current car+setup+handling model, and the time-of-day choice.
5. **Loading screen:** period-style, with tip text and the circuit map. It must reflect real loading, not a fake timer.
6. **Pre-race / grid:** a camera sweep, then control handed over with a countdown or rolling start.
7. **In-race HUD:** tach and gear, speed, lap/time/delta, sector splits, minimap, and tyre/aid indicators (TCS/ASM/ABS). The pause menu covers Resume, Restart, Garage, Settings, Help, and Quit to menu.
8. **Results / time sheet:** after a session or on quit, show lap times with sector splits, best/invalid flags, top speed, and options for Retry / Change car / Change circuit / Main menu. Include a simple replay of the last lap if it's feasible without touching physics (ghost-data playback is fine). Otherwise leave it out and say so.
9. **Settings:** everything that already exists (controls/remap, audio, display, render resolution, time of day, handling model, aids, units, UI mode), laid out GT-style with a live preview where cheap.
10. **Help:** the existing PLAYER-GUIDE chapters, restyled.

### Navigation rules

- A focus cursor must always be visible, with no dead ends and no focus traps. Back/B/Esc always goes up one level.
- Show a button-prompt bar on every screen, and switch the prompts between keyboard and controller glyphs based on the last input used. The glyphs are original, not copied from Sony or Microsoft.
- UI sounds: cursor move, confirm, back, error. They must be original and synthesized, or downloaded under CC0.
- Mouse and trackpad work everywhere as a secondary input.
- No screen may lose unsaved circuit edits. Keep the existing dirty guards.

## 2. The benchmark: Ferrari 296 GT3 at Spa

Spa + 296 GT3 is the showcase and the acceptance test. It's already the default pairing, so keep it that way. When a trade-off comes up, this combo wins.

### Visual benchmark

Match the 1:1 target at these Spa spots, in Afternoon and Afterhours, using the chase cam plus one bumper/hood cam:
- La Source hairpin
- Eau Rouge / Raidillon from the bottom
- Kemmel straight at speed
- Les Combes
- Pouhon
- Blanchimont
- Bus Stop chicane
- The start/finish straight with the grid

Also include showroom shots of the 296 (front 3/4, rear 3/4, profile).

Produce side-by-side sheets against references for each spot and run the three-round compare-and-fix loop from the last message *on this set specifically*.

### Playability benchmark (automate it and record the results)

- **Full flow, controller-only inputs**, simulated through the input layer: boot → title → main menu → car select (296) → circuit select (Spa) → load → grid → a full valid lap by the bot → pause → results → back to main menu. Repeat keyboard-only. Both runs finish with no errors in stderr. Put this in the feature suite and run it against the exported exe.
- **Laps:** the bot completes valid laps of Spa in the 296 in both Simcade and Simulation with zero off-track steps and zero barrier contacts. Report lap times and top speed on Kemmel.
- **Drivability:** in Simcade with default aids, a human-style scripted test (keyboard digital inputs, slightly late braking into La Source and the Bus Stop, a full-throttle exit from Raidillon) doesn't spin and stays on track.
- **Performance:** on a full Spa lap in the 296 at each render mode (480p default, 720p, Native), in Afternoon and Afterhours, on Forward+ and the OpenGL fallback, report average and 1 % low frame times. The target is locked 60 fps+ on the RTX 4080 at every setting, with no hitching at load or at LOD transitions.

## 3. Report back (in addition to the earlier report)

- UI flow diagram
- Screenshots of every screen
- Benchmark sheets for all Spa spots
- The playability results table
- The performance table
- A ranked list of what still doesn't look or feel PS2-authentic on the 296-at-Spa combo

Only say it's done when the benchmark passes.
