# Chicago city prep (rb/CHI-assets-prep, 2026-09-25)

Staging area for a future Chicago-city task, built while reviewing `rb/CHI-01-chicago` (not modified —
see that branch's own `trackgen/data/chicago/README.md`). Downloaded models/textures and a wider
downtown OSM roadmap are at `../../assets/cc0-source/chicago/` (see that folder's README for what's
there and why). This folder holds the two things that aren't downloaded source material.

## `drafts/`

Two unintegrated sketches, not referenced by any scene, generator, gate or `.tscn` — written to match
this repo's existing conventions (`night_glow.gdshader`'s afterhours toggle, `road_scatter.gd`'s
`@tool`/`@export`/`bake()` house style) so a future task can adapt rather than reinvent them, not to be
dropped in as-is:

- **`neon_marquee.gdshader`** — a pulsing tube-neon emissive shader for Loop storefront/theatre marquee
  signage at night, since the current `night_glow.gdshader` only does a flat emission toggle (no pulse,
  no colour-masked tubing). Untested against the renderer.
- **`steam_grate.gd`** — a `GPUParticles3D`-based sidewalk steam vent, for Lower/Upper Wacker's tunnel
  grates and Loop manholes. Deliberately does not follow `RoadScatter`'s MultiMesh-scatter pattern
  (particle emitters can't share one node the way static cards share one MultiMesh); a real integration
  should place a handful by hand at named stations, not scatter hundreds. Untested against the renderer.

Neither has been run in Godot. Verify them (headless `--check-only` for the script, a windowed look for
the shader) before relying on either.
