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

## Tree cards and horizon (Look-6; downloaded 2026-09-24)

Four Poly Haven models, all **CC0 1.0** ([legal text](assets/licenses/CC0-1.0.txt)): [fir_tree_01](https://polyhaven.com/a/fir_tree_01) and [fir_sapling_medium](https://polyhaven.com/a/fir_sapling_medium) (Rob Tuytel photography, Rico Cilliers modelling), [tree_small_02](https://polyhaven.com/a/tree_small_02) and [shrub_02](https://polyhaven.com/a/shrub_02) (Rico Cilliers). The 1K glTF downloads (about 640 MB, never committed) were rendered by `tools/bake_tree_cards.gd` and packed by `tools/finish_tree_cards.py` into the single 2048 px alpha atlas `assets/trees/tree_atlas.png` (4 MB, nine cards: three spruce, two tall fir, one deciduous, two bush) that `scripts/track/road_scatter.gd` scatters as crossed cards. The hill silhouettes in the sky are painted by code (`RetroAssets.hills_panorama`) and use no download.

## Undergrowth and two more deciduous species (Look-10; downloaded 2026-09-25)

`tree_atlas.png` was regenerated (still through `tools/bake_tree_cards.gd` and `tools/finish_tree_cards.py`, same 4 MB budget) to add two more Poly Haven models, both **CC0 1.0**: [island_tree_02](https://polyhaven.com/a/island_tree_02) and [island_tree_03](https://polyhaven.com/a/island_tree_03) (Rob Tuytel scanning, Rico Cilliers cleanup). Poly Haven has no model literally named oak or birch; these are the closest broadleaf/multi-stem CC0 renders by inspection, used as generic deciduous stand-ins (`scripts/track/road_scatter.gd`'s `CARDS`/`SPECIES` calls them `oak` and `birch`). The atlas is now ten cards: three spruce, two fir, three deciduous (beech, oak, birch), two bush.

A second atlas, `assets/undergrowth/undergrowth_atlas.png` (1.8 MB), holds low vegetation for the band between and under the trees (ART-DIRECTION.md "Trackside enclosure"): five more Poly Haven CC0 1.0 models, [fern_02](https://polyhaven.com/a/fern_02) (Rob Tuytel scanning, Rico Cilliers modelling), [wild_rooibos_bush](https://polyhaven.com/a/wild_rooibos_bush) (James Ray Cock modelling, Jenelle van Heerden photography), [grass_medium_01](https://polyhaven.com/a/grass_medium_01) (Rob Tuytel photography, Rico Cilliers modelling), [shrub_04](https://polyhaven.com/a/shrub_04) (Rico Cilliers) and [pine_sapling_small](https://polyhaven.com/a/pine_sapling_small) (Rob Tuytel photography, Rico Cilliers modelling), rendered and packed the same way into 14 cards (2 fern, 3 bramble, 3 long grass, 3 flowering shrub, 3 conifer sapling). `scripts/track/road_scatter.gd`'s new `atlas_kind` export picks this atlas; `trackgen/nordschleife_s1.gd`, `trackgen/spa.gd` and `trackgen/proving_ground.gd` scatter it as `add_undergrowth()`/an `Undergrowth` RoadScatter node. Total new download for both atlases: about 155 MB of source glTF/textures, never committed.

## Chicago circuit (CHI-01)

Road scaffold © OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright;
https://opendatacommons.org/licenses/odbl/1-0/). The source and edited geographic data are available
in `godot/trackgen/data/chicago/` in https://github.com/SnekPolylepis/Racingsim .
Acquired 2026-09-25; widths, heights, corner easing and two game-only ramp connectors are authored.
Buildings, Bean interpretation, Willis Tower silhouette and Navy Pier geometry are original procedural
low-poly art; no third-party landmark model or photograph is used. See that folder's README for
the exact query, limitations and attribution.
