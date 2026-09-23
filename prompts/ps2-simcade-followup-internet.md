# Follow-up: internet access + 1:1 PS2 look

This amends the overhaul prompt you're working from. Where the two conflict, this message wins. Everything else in it still applies: the handling work, tests, the constraints on physics/editor/save files, and the docs.

## 1. You now have internet access. Use it.

Use the web for anything that gets the vision done:

- **Research:** Godot 4.6 docs, shader techniques, PS2 hardware and graphics write-ups, GDC/dev postmortems, and Digital Foundry-style breakdowns of PS2 racers. Look things up before guessing.
- **Plugins and addons:** Godot Asset Library or GitHub addons (post-processing, CRT/NTSC filters, MultiMesh foliage, decals, lens flares, anything useful). This overrides "no plugins" from AGENTS.md and the README.
- **Textures, models, fonts, sounds:** download what you need. Prefer CC0 sources (Poly Haven, ambientCG, Kenney, Quaternius, OpenGameArt CC0). CC-BY and MIT/OFL are fine with attribution. Never use GPL/NC/"editorial use only" assets or anything with unclear licensing.
- **Tools:** pip/npm/Python image tools, texture downscalers and palette quantizers, if they help the build pipeline. Keep them in `tools/` or `trackgen/`-style build scripts, not runtime.

Rules that still hold:

- **The shipped game stays fully offline.** Everything gets vendored into `godot/` (addons in `godot/addons/`, assets in `godot/assets/`) and packed into the exe. No runtime downloads, telemetry or network calls.
- **Record every downloaded thing** in `godot/THIRD-PARTY.md`: name, source URL, author, license and what it's used for. Ship the needed license texts next to the exe in `build/`.
- **Pin addon versions** and commit them. Check that each addon supports Godot 4.6.2 and the OpenGL fallback before relying on it.
- **Blender and hand-modelled scenes stay out.** Downloaded CC0 models are allowed, but the Ferrari 296 stays the procedural model from `ferrari_296.gd`.

## 2. Graphics target: 1:1 with a real PS2-era racer

The earlier prompt said "evoke the look, not emulate the hardware." **Change of plan: the target is now a 1:1 match.** A screenshot of this game placed next to a real Gran Turismo 4 screenshot (day) or NFS Underground 2 screenshot (Afterhours night), both upscaled the same way, should be hard to tell apart as "not a PS2 game."

The content stays ours. The look copies the platform, not the product: no ripped or extracted textures, models, logos, fonts, HUD artwork or liveries from any game. Reference images are for study only and never ship in the repo.

### Research first (write this down)

Before changing rendering, research and document in `godot/docs/PS2-REFERENCE.md` (with sources) what the PS2 Graphics Synthesizer and period racers actually produced:

- Output resolutions and modes: 640×448/512×448, field vs frame rendering, 480i interlacing, the deflicker/flicker filter, GT4's 480p/1080i modes.
- Colour: 32-bit framebuffer vs 16-bit textures, dithering behaviour, gamma/brightness curves on CRT/composite output.
- Textures: 4 MB VRAM, 4-bit/8-bit palettised (CLUT) textures, typical sizes, bilinear filtering, how mipmapping was and wasn't used.
- Geometry budgets: approximate car and scene polycounts for GT4-era racers, LOD distances, fog use.
- Lighting and effects: vertex lighting, fake env-map car reflections, GT4's bloom/glare, heat haze, light trails, sun flare, NFSU2's heavy bloom/wet road/motion blur, and how shadows were done (blob, projected, baked).
- Mood: colour grading and composition tendencies (GT4 daylight, NFSU2 night).

Collect reference screenshots/frames from public sources (press shots, wikis, YouTube captures of real hardware or accurate emulation) into a **git-ignored** `godot/reference/` folder, with a source list in PS2-REFERENCE.md. Do not commit the images.

### Implement to match, with numbers

Turn the research into concrete settings and remove anything from the first prompt that contradicts real hardware:

- Render at the true internal resolution (e.g., 640×448 for 4:3, with the matching 16:9 anamorphic handling GT4 used). Add an optional **480i mode**: field rendering + deflicker + scanline/interlace artefacts. Add an optional **CRT/composite output** filter (NTSC chroma bleed, slight blur, mask). Keep a clean "480p component" option, which should be the default.
- Palettise and quantise textures to real PS2-style formats in a build step (4/8-bit CLUT where appropriate, 16-bit elsewhere), at period-accurate sizes.
- Hit period polycount budgets for scenery LODs, and match draw distance and fog to the references.
- Match GT4's car reflection look (env-map sheen, the specular sweep) and its bloom/glare behaviour. Match NFSU2 for Afterhours: bloom, wet-road reflections, streaking lights, motion blur.
- Build the HUD and menus in period style with an OFL/CC0 font that fits the era. It must be original design and stay crisp in the `Native UI` layer (the only deliberate deviation from 1:1, for usability). Add an optional "authentic UI" toggle that renders the HUD at internal resolution too.

### Prove it

- Add a `--compare` mode or script that renders our frames at matching camera setups (chase cam on a straight, a corner, a car showroom shot, night on a lit straight) and produces side-by-side sheets with the reference images in `godot/reference/` (git-ignored output).
- Iterate at least **three rounds**: compare, list the differences you see (resolution, colour, bloom, textures, geometry density, sky, fog, car sheen, HUD), fix them, re-render. Log each round's findings and changes in PS2-REFERENCE.md.
- Stop only when you'd honestly call it a match, or when a remaining gap is only closable with ripped assets. If that's the case, say which gap.

## 3. Report back

Add to your final report:

- Everything downloaded, with licenses.
- The research summary.
- The before/after and side-by-side sheets (paths).
- Remaining differences from the references, ranked.
- Frame times at each render mode, on Forward+ and on the OpenGL fallback.
