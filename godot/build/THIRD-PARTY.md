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

Poly Haven CC0 texture set `asphalt_pit_lane` (2K albedo, roughness and OpenGL normal; https://polyhaven.com/a/asphalt_pit_lane) in `assets/textures_hd/asphalt_pit_lane/`, albedo desaturated to 35 %: the TrackAsset road surface (Look-8).

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

## Verified P5-01 sources for future circuits (not downloaded)

Checked 2026-09-22; no data from these sources has been downloaded, committed or shipped. See [P5-01 source notes](docs/rebuild/data-sources-P5-01.md) for access, resolution and survey caveats. Recheck each licence when fetching data, and record the access date, exact files and any modifications before using derived data.

- **Nordschleife:** [LVermGeo Rheinland-Pfalz open data](https://lvermgeo.rlp.de/geodaten-geoshop/open-data): DGM1 terrain, DOM1 surface model, laser point clouds and DOP20 orthophotos. Licence: Datenlizenz Deutschland – Namensnennung – Version 2.0 (dl-de/by-2-0). Attribution for modified data: `©GeoBasis-DE / LVermGeoRP<year>, dl-de/by-2-0, www.lvermgeo.rlp.de [Daten bearbeitet]`; replace `<year>` with the year of data access.
- **Spa-Francorchamps:** Service public de Wallonie [MNT 1 m 2021–2022](https://geoportail.wallonie.be/catalogue/fe13bc84-e371-46ca-9632-8ad4139f1ee5.html) terrain and [Orthophotos 2023 Été](https://geoportail.wallonie.be/catalogue/ad55c2ce-62ad-4c3c-b3cf-8fbc270a6b6e.html). Both are CC BY 4.0. Attribute SPW, each dataset's catalogue title and source URL, and indicate modifications. Record the final attribution in the game's credits when derived data first ships.

## Spa authored TrackAsset v0 (P6-01; downloaded 2026-09-23)

- **Centreline:** © OpenStreetMap contributors, [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Fresh raw way/node JSON were obtained from the official OSM API after three Overpass endpoints failed. The GP raceway ways were joined in their one-way racing direction, projected to local metres, resampled to about 10 m and rotated to an approximate start line before La Source. Geometry was not scaled to force the nominal lap length. The raw extract and derived centreline database, including its derivation script, are distributed under ODbL in `trackgen/data/spa/`; [OSM attribution](https://www.openstreetmap.org/copyright).
- **Elevation:** Service public de Wallonie (SPW) - **Relief de la Wallonie - Modèle Numérique de Terrain (MNT) 2021-2022 (2024-01-23)**, © SPW 2021-2022, [source catalogue](https://geoportail.wallonie.be/catalogue/a004e570-99d6-4fe5-b83d-49b774409278.html), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Licence rechecked on download day. The public MapServer's 0.5 m LiDAR ground model was sampled via its numeric identify API, producing a compact **20 m terrain crop** and independently sampled road heights about every 20 m. Modifications: coordinate conversion, cropping, resampling, road median/Gaussian smoothing, curvature constraint and subtraction of the start-line height. Raw numeric responses and the derived float32 grid are preserved. This is not a full-resolution LiDAR mesh. Buildings, vegetation and bridges are absent from the source terrain.

- **Polish (P6-01, downloaded 2026-09-23):** road cross-sections from the same SPW MNT 2021-2022 0.5 m ground model (39,843 points across the road every ~10 m; `cross-sections.json`, `fetch_sections.py`) give the crossfall banking. Service public de Wallonie (SPW) - **Orthophotos 2023 Été**, © SPW, [source catalogue](https://geoportail.wallonie.be/catalogue/ad55c2ce-62ad-4c3c-b3cf-8fbc270a6b6e.html), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): 70 tiles of 140 m at 0.25 m/px exported along the circuit (`ortho-tiles.json`, `fetch_ortho.py`), used only to measure road half-widths to the white track-limit lines and kerb positions (`road-profile.json`, `analyse_road.py`). Modifications: colour classification along lines perpendicular to the OSM centreline, median smoothing, linear fits. The images themselves are not distributed.

Exact requests, SHA-256 hashes, source limitations, the heightmap header and source measurements are recorded in [the Spa data README](trackgen/data/spa/README.md) and `trackgen/data/spa/sources.json`. Unmodified ODbL and CC BY licence texts are vendored under `trackgen/data/spa/licenses/`. The drive scene shows the abbreviated OSM/SPW attribution supplied by the generated TrackAsset; this ledger supplies the full titles, source links and modification details.

## Mazda MX-5 / Miata NA car exterior

"Mazda Miata MX-5 NA" by Lexyc16: https://sketchfab.com/3d-models/mazda-miata-mx-5-na-d51fcd44b74f4daf8012c41e0400c041. Licensed under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/. The model was reoriented, resized, stripped of the source wheels/display plane/unneeded interior mesh, repainted from the game preset and combined with game wheel and lamp assemblies. Full source attribution and the author's original `license.txt` are in `assets/cars/mx5na/` and `THIRD-PARTY.md` in the source distribution. No author endorsement is implied.
