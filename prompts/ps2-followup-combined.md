# Follow-up: internet access, 1:1 PS2 graphics and UI, and the benchmark (Ferrari 296 GT3 at Spa)

This amends the overhaul prompt you're working from. Where the two conflict, this message wins. Everything else from the original still applies: the simcade handling work, the tests, the constraints on physics/editor/save files, and the docs.

## 1. You now have internet access. Use it.

Use the web for anything that gets the vision done:

- **Research:** Godot 4.6 docs, shader techniques, PS2 hardware/graphics write-ups, dev postmortems, and technical breakdowns of PS2 racers. Look things up before guessing.
- **Plugins and addons:** Godot Asset Library or GitHub addons (post-processing, CRT/NTSC filters, foliage, decals, lens flares, UI helpers, anything useful). This overrides "no plugins" in AGENTS.md and the README.
- **Textures, models, fonts, sounds:** download what you need. Prefer CC0 sources (Poly Haven, ambientCG, Kenney, Quaternius, OpenGameArt CC0). CC-BY and MIT/OFL are fine with attribution. Never use GPL, NC, "editorial use only", or anything with unclear licensing.
- **Build tools:** Python/npm image tools, texture downscalers and palette quantizers, for the build pipeline only (keep them in `tools/` or build scripts, not runtime).

Rules that still hold:

- **The shipped game stays fully offline.** Vendor everything into `godot/` (`addons/`, `assets/`) and pack it into the exe. No runtime downloads, telemetry or network calls.
- **Record every download** in `godot/THIRD-PARTY.md`: name, URL, author, license and use. Ship the required license texts in `build/`.
- **Pin addon versions** and commit them. Confirm each works with Godot 4.6.2 and the OpenGL fallback.
- **Blender: allowed, but only if it really needs it.** It isn't installed on this machine. Try `.glb`, `.gltf` or `.fbx` models, code-built geometry and Godot tools first. If Blender is genuinely needed (e.g., to convert or clean a model or bake textures), install a portable copy into `tools/blender/` (git-ignored), drive it with scripts so the step can be re-run, and commit only the exported `.glb`/textures. The game must never need Blender to open, build or run. Note in the report what it was used for. The Ferrari 296 stays the model in `ferrari_296.gd` unless Blender makes it clearly more PS2-authentic. In that case, keep the procedural version as a fallback and keep the `snapshot()/blend()` pose interface.

## 2. Graphics target: 1:1 with a real PS2-era racer

The original prompt said "evoke the look, not emulate the hardware." **Change of plan: the target is now a 1:1 match.** A frame of this game placed next to a real Gran Turismo 4 screenshot (Afternoon) or NFS Underground 2 screenshot (Afterhours), both upscaled the same way, should be hard to tell apart as "not a PS2 game."

The content stays ours. The look copies the platform, not the product: no ripped or extracted textures, models, logos, fonts, HUD/menu art, icons, wording or liveries from any game. Reference images are for study only and never get committed or shipped.

### Research first (write it down)

Before changing rendering, research and document in `godot/docs/PS2-REFERENCE.md`, with sources:

- **Output:** 640×448/512×448, field vs frame rendering, 480i interlacing, the deflicker filter, GT4's 480p/1080i and 16:9 handling.
- **Colour:** framebuffer vs texture bit depths, dithering behaviour, CRT/composite gamma and colour.
- **Textures:** 4 MB VRAM, 4/8-bit palettised (CLUT) textures, typical sizes, bilinear filtering, how mipmapping was and wasn't used.
- **Geometry:** approximate car and scene polycounts for GT4-era racers, LOD distances, fog use.
- **Effects:** vertex lighting, env-map car reflections, GT4 bloom/glare, heat haze, sun flare, light trails, NFSU2 bloom/wet roads/motion blur, and how shadows were done (blob, projected, baked).
- **Front end:** GT4/NFSU2 screen flow, layout grids, selection cursor and highlight behaviour, transitions, loading screens, button-prompt bars, and menu sound design.

Put reference screenshots/frames from public sources (press shots, wikis, captures of real hardware or accurate emulation) in a **git-ignored** `godot/reference/` folder, and list their sources in PS2-REFERENCE.md.

### Implement to match, with numbers

Turn the research into concrete settings and drop anything from the original prompt that contradicts real hardware.

- **Resolution:** true internal resolution (e.g., 640×448 at 4:3, with GT4-style 16:9 handling). "480p component" is the clean default. Add an optional **480i mode** (field rendering + deflicker + interlace artefacts) and an optional **CRT/composite** output filter (NTSC chroma bleed, slight blur, mask).
- **Textures:** palettise and quantise textures in a build step to PS2-style formats (4/8-bit CLUT where appropriate, 16-bit elsewhere) at period-accurate sizes.
- **Geometry and fog:** hit period polycount budgets and LODs, and match draw distance and fog to the references.
- **Lighting and effects:** match GT4's car reflection look (env-map sheen, specular sweep) and its bloom/glare. For Afterhours, match NFSU2: bloom, wet-road reflections, streaking lights, motion blur.

## 3. The UI goes 1:1 PS2 too

The original prompt kept the HUD and menus crisp at native resolution. **Change: the whole front end and HUD should look and feel like a real 2003–2006 PS2 racer**, with GT4 as the main reference and NFSU2 for Afterhours. That covers layout conventions, typography style, transitions, sounds and pacing, all in original designs and an OFL/CC0 font that fits the era.

- **Authentic UI is the default.** The UI renders at the internal resolution through the same output chain, so it gets the same scaling, dither and 480i/CRT effects when those are on. "Sharp UI" is an option, not the default.
- **Legibility is a requirement.** Test every screen at 1280×800 and 1920×1080. Keep text at or above what a 2004 TV game used (roughly 16 px at 448 lines). The default 480p mode must not turn text into scanline mush.
- **The circuit editor is exempt from the retro filter.** Reskin its colours and fonts to match, but keep it sharp and fully mouse/trackpad-usable.

### Screens (every one reachable and escapable with controller only, keyboard only, or mouse)

1. **Boot:** a short original studio/logo card, then the title screen with "PRESS START". A skip button works. After idle, the title runs an attract loop: the bot drives the 296 around Spa.
2. **Main menu:** Race (Time Trial / Free Run), Garage, Circuits (library + editor), Settings, Help, Quit.
3. **Car select:** a showroom turntable with a spec sheet (power, weight, drivetrain), paint/rim choice where presets allow, and a setup picker.
4. **Circuit select:** a track map, length, corner count, elevation profile, the best lap/ghost for the current car+setup+handling model, and the time-of-day choice.
5. **Loading screen:** period-style, with tips and the circuit map. It must track real loading, not a fake timer.
6. **Pre-race / grid:** a camera sweep, then control handed over with a countdown or rolling start.
7. **In-race HUD:** tach and gear, speed, lap/time/delta, sector splits, minimap, and TCS/ASM/ABS and tyre indicators.
8. **Pause menu:** Resume, Restart, Garage, Settings, Help, Quit to menu.
9. **Results / time sheet:** lap times with sector splits, best/invalid flags, top speed, and Retry / Change car / Change circuit / Main menu. Include a last-lap replay from ghost data if it's feasible without touching physics. Otherwise leave it out and say so.
10. **Settings:** everything that already exists (controls/remap, audio, display, render resolution, output mode, time of day, handling model, aids, units, UI mode), laid out GT-style with a live preview where cheap.
11. **Help:** the existing PLAYER-GUIDE chapters, restyled.

### Navigation rules

- A focus cursor must always be visible, with no dead ends and no focus traps. Back/B/Esc always goes up one level.
- Show a button-prompt bar on every screen, with glyphs that switch between keyboard and controller based on the last input. The glyphs are original, not copied from Sony or Microsoft.
- UI sounds (move, confirm, back, error) must be synthesized or CC0.
- Mouse and trackpad work everywhere as a secondary input.
- Keep the existing unsaved-circuit dirty guards on every exit path.

## 4. The benchmark: Ferrari 296 GT3 at Spa

Spa + 296 GT3 is the showcase and the acceptance test. It stays the default pairing, and when a trade-off comes up, this combo wins.

### Visual benchmark

Match the 1:1 target at these Spa spots, in both Afternoon and Afterhours, using the chase cam plus one bumper/hood cam:
- La Source hairpin
- Eau Rouge / Raidillon from the bottom
- Kemmel straight at speed
- Les Combes
- Pouhon
- Blanchimont
- Bus Stop chicane
- The start/finish straight with the grid

Also include showroom shots of the 296 (front 3/4, rear 3/4, profile) and screenshots of every UI screen.

Add a `--compare` mode or script that renders these shots and builds side-by-side sheets against the references (git-ignored output). Run at least **three rounds** of compare → list differences (resolution, colour, bloom, textures, geometry density, sky, fog, car sheen, UI) → fix → re-render. Log each round in PS2-REFERENCE.md. Stop only when you'd honestly call it a match, or when a remaining gap could only be closed with ripped assets. In that case, name the gap.

### Playability benchmark (automate it and record the results)

- **Full flow, controller-only inputs**, simulated through the input layer: boot → title → main menu → car select (296) → circuit select (Spa) → load → grid → a full valid bot lap → pause → results → main menu. Repeat keyboard-only. Both runs must finish with no errors in stderr. Add this to the feature suite and run it against the exported exe.
- **Laps:** the bot completes valid Spa laps in the 296 in both Simcade and Simulation, with zero off-track steps and zero barrier contacts. Report lap times and top speed on Kemmel.
- **Drivability:** in Simcade with default aids, a scripted human-style run doesn't spin and stays on track. That means keyboard digital inputs, slightly late braking into La Source and the Bus Stop, and a full-throttle exit from Raidillon.
- **Performance:** measure a full Spa lap in the 296 at every render mode (480p, 720p, Native) × Afternoon/Afterhours × Forward+/OpenGL fallback, and report average and 1 % low frame times. The target is a locked 60 fps+ on the RTX 4080 at every setting, with no hitching at load or LOD transitions.

## 5. Report back (in addition to the original report)

- Everything downloaded, with licenses
- The research summary
- A UI flow diagram
- Screenshots of every screen
- Before/after and side-by-side sheets for all Spa spots
- The playability results table
- The performance table
- A ranked list of what still doesn't look or feel PS2-authentic on the 296 at Spa

Only say it's done when the benchmark passes.
