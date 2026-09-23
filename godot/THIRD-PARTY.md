# Third-party download ledger

The shipped game runs offline. Reference images under `reference/` are ignored and explicitly excluded from the export; they are never used as runtime textures. This ledger records the follow-up downloads separately from already-vendored assets.

## Shipped font

Rajdhani Medium and Bold, Indian Type Foundry (Latin design Shiva Nalleperumal; Devanagari Satya Rajpurohit and Jyotish Sonowal), SIL Open Font License 1.1. [Upstream](https://github.com/itfoundry/rajdhani). Downloaded from Google Fonts at pinned revision `e44c4b011a820c2cbe2fd2cfa8052037d7edb571` on 2026-09-21:

- [Rajdhani-Medium.ttf](https://raw.githubusercontent.com/google/fonts/e44c4b011a820c2cbe2fd2cfa8052037d7edb571/ofl/rajdhani/Rajdhani-Medium.ttf)
- [Rajdhani-Bold.ttf](https://raw.githubusercontent.com/google/fonts/e44c4b011a820c2cbe2fd2cfa8052037d7edb571/ofl/rajdhani/Rajdhani-Bold.ttf)
- [OFL.txt](https://raw.githubusercontent.com/google/fonts/e44c4b011a820c2cbe2fd2cfa8052037d7edb571/ofl/rajdhani/OFL.txt)

Use: original front-end, HUD and editor typography. Files and SHA-256 hashes are in `assets/fonts/sources.json`; unmodified license is `assets/fonts/OFL.txt` and shipped beside the executable as `build/RAJDHANI-OFL.txt`.

## Study-only imagery

Downloaded 2026-09-21. Authors/rightsholders: Sony/Polyphony Digital for GT4; Electronic Arts/EA Black Box for NFSU2. License: copyrighted reference imagery, no redistribution license. Use: local comparisons explicitly requested by the user; never committed or shipped. Every image URL, local filename and source page is listed in [PS2-REFERENCE.md](docs/PS2-REFERENCE.md#downloaded-reference-inventory): four official GT4 gallery JPGs, the Retroplace GT4 title PNG, the PS Parts NFSU2 road JPG and the WhichCar NFSU2 night JPG. No game archive, extracted game asset or executable was downloaded.

## Additional CC0 photographs (2026-09-21)

- **Kloofendal 48d partly cloudy pure sky**, Greg Zaal (photography), Jarod Guest (sky edits). [Asset page](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky), [1K HDR download](https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/1k/kloofendal_48d_partly_cloudy_puresky_1k.hdr). Use: downsampled, tone-mapped 256×128 RGB555 sky and reflection maps, with original horizon treatment.
- **Pine Tree 01 twig diffuse and alpha**, Rob Tuytel (photography), Rico Cilliers (modeling). [Asset page](https://polyhaven.com/a/pine_tree_01), [diffuse PNG](https://dl.polyhaven.org/file/ph-assets/Models/png/1k/pine_tree_01/pine_tree_01_twig_diff_1k.png), [alpha PNG](https://dl.polyhaven.org/file/ph-assets/Models/png/1k/pine_tree_01/pine_tree_01_twig_alpha_1k.png). Use: an original arrangement of photographed branches on a 128×256, 16-colour tree card. No downloaded tree geometry.

Both are CC0 1.0. Original bytes and hashes are recorded in `assets/cc0-source/sources.json`. The [unmodified CC0 legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt) is vendored in `assets/licenses/CC0-1.0.txt` and copied beside the executable. Raw build sources are excluded from the executable; converted runtime textures are packed into it. Pillow 12.3.0 was already available in the bundled build runtime; no package installation or Blender was needed.

## Previously present assets

Poly Haven CC0 texture sets `asphalt_track`, `grass_ground`, `gravel_floor`, `concrete_floor_02`: source links and uses remain in `assets/textures/README.md`. Existing Godot engine MIT license and third-party notices remain beside the executable. New build outputs derived from the CC0 textures retain their source provenance.

No addon or Blender has been downloaded or incorporated at this stage. Any subsequent download must extend this ledger and include its license text before shipping.

## Recorded engine bank (2026-09-21)

Both recordings below are offered under **CC0 1.0** on their author pages. Public HQ MP3 previews were downloaded, without an account or restricted original downloads. Original bytes, exact URLs and SHA-256 hashes are vendored in `assets/audio-source/sources.json`. The existing unmodified `assets/licenses/CC0-1.0.txt` / `build/CC0-1.0.txt` covers these downloads too.

- **Ferrari_motor_idle**, **jtvdb**: [author page](https://freesound.org/people/jtvdb/sounds/857147/), [download](https://cdn.freesound.org/previews/857/857147_14592662-hq.mp3). Author identifies a Ferrari but does not know the exact model. Used for the edited idle layer.
- **Acceleration 1.wav**, **biholao**: [author page](https://freesound.org/people/biholao/sounds/370278/), [download](https://cdn.freesound.org/previews/370/370278_6820745-hq.mp3). Described by the author as Ferrari acceleration; model and RPM unspecified. Used for low/mid/high engine layers.

Edits: mono conversion, removal of DC/wind rumble, selected excerpts, pitch stabilization, seamless overlap, level matching and filtered off-throttle variants. `assets/audio/bank-manifest.json` records exact excerpts, tuned RPM anchors, output hashes and PCM measurements. These are sound-designed game voices, not authenticated recordings of the 296 GT3 or each selectable car. No endorsement by the recordists or manufacturer is implied. Only eight edited WAV loops ship; raw MP3 sources stay in the build workspace. Godot 4.6.2 decodes them and the already-present NumPy 2.3.5 runtime builds the loops; no codec/package was downloaded.

## Circuit geometry and elevation data

- **Spa-Francorchamps & Nürburgring Nordschleife**:
  - Centerline geometry: OpenStreetMap contributors, Open Database License (ODbL 1.0, https://opendatacommons.org/licenses/odbl/).
  - Elevation: EU-DEM v1.1 (Copernicus Land Monitoring Service) and SRTM 30m (NASA, public domain), accessed via OpenTopoData.
  - Derived documents in `tracks/` and `trackgen/` are made available under the ODbL.

