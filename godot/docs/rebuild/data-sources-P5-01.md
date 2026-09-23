# P5-01: elevation and imagery sources for the real circuits

Checked 2026-09-22 against the publishers' own pages (links below). **Nothing has been downloaded or committed yet.** Re-check the licence page on the day data is actually fetched, and record the access date in the attribution.

## Summary

| Circuit | Terrain (1 m) | Imagery | Licence | Commercial use | Access |
|---|---|---|---|---|---|
| Nürburgring Nordschleife | LVermGeo RLP **DGM1** (also DOM1, laser point clouds LPG/LPO) | LVermGeo RLP **DOP20** (20 cm) | dl-de/by-2.0 | Yes, with attribution | Free direct download, Geoshop RLP |
| Spa-Francorchamps | SPW Wallonie **MNT 1 m 2021–2022** (LiDAR) | SPW **Orthophotos 2023 Été** (25 cm, RGB + NIR) | CC BY 4.0 | Yes, with attribution | Free direct download by province (Liège), or custom extract by email |
| Monza (optional) | Regione Lombardia / MiTE **DTM LiDAR 1 m** | not checked | CC BY 4.0 (per catalogue listing) | Yes, with attribution | Tiles requested by certified email (PEC) to the province; **coverage of the Monza park not confirmed** |

All three licences permit derived works in a distributed, commercial game, provided the attribution is shown (credits screen and `THIRD-PARTY.md`). They sit alongside the existing ODbL obligation for the OpenStreetMap-derived centrelines.

## Nordschleife: Rhineland-Palatinate (LVermGeo RLP)

- Open-data products: DGM1/5/10 (terrain), DOM1 (surface), bDOM, **laser point clouds** "Laserpunkte Gelände" (ground) and "Laserpunkte Objekte", DOP20 orthophotos, LoD1/LoD2 buildings.
- Licence: Datenlizenz Deutschland – Namensnennung – Version 2.0 (dl-de/by-2-0). Required attribution: `©GeoBasis-DE / LVermGeoRP<year>, dl-de/by-2-0, www.lvermgeo.rlp.de`, adding `[Daten bearbeitet]` because we modify the data.
- DGM1 specification (BKG product sheet): 1 m grid, heights to 0.01 m, **height deviation < ±0.3 m**, 1 × 1 km tiles, ETRS89 / UTM zone 32 (EPSG:25832), heights DHHN2016, GeoTIFF (LZW, may be COG). National currency "2000 to 2022, partial update for Rhineland-Palatinate": **check the acquisition date of the Nürburg tiles.**
- **Bridges are generally not part of the DGM.** Where the Nordschleife passes over or under a bridge, the terrain model shows the ground beneath. Use the ground point cloud (LPG) or DOM1 there, or model the structure by hand.

## Spa-Francorchamps: Wallonia (SPW)

- MNT 1 m 2021–2022: LiDAR flown 2021-02-19 to 2022-03-05; GeoTIFF by province (2.6–11.2 GB each; whole region 40.9 GB) or a custom extract by email within 48 h. Excludes buildings, bridges, vegetation and vehicles.
- Licence CC BY 4.0. Attribution given by the catalogue: `Service public de Wallonie (SPW) - Relief de la Wallonie - Modèle Numérique de Terrain - 1m (MNT) 2021-2022 (2024-01-23)`.
- Orthophotos 2023 Été: 25 cm, flown 2023-05-27 to 2023-06-25, 2 × 2 km tiles, GeoTIFF, CC BY 4.0.
- **Timing caveat:** the survey spans the winter of 2021–22, when parts of Spa were being rebuilt (runoff changes). Check the corners that changed against the 2023 orthophotos, and hand-author where they disagree.
- A LiDAR point-cloud campaign for 2021–22 is also listed; its licence was not checked.

## What this means for P6

- 1 m terrain resolves the road-scale shape that 25–30 m EU-DEM/SRTM could not. ±0.3 m absolute is still too noisy to drive on raw: fit the road surface to the point cloud / DGM along the centreline with cross-section smoothing, rather than sampling the grid directly.
- Keep coordinates local: reproject from UTM/Lambert to a track origin within ±5 km (§5.1).
- Store raw downloads outside git (they are gigabytes). Commit only the derived track and the licence notes. Add the attributions to `godot/THIRD-PARTY.md` and the in-game credits in the same change that first ships derived data.

## Sources

- LVermGeo RLP, Open Data: https://lvermgeo.rlp.de/geodaten-geoshop/open-data
- LVermGeo RLP, DGM products: https://lvermgeo.rlp.de/produktinformationen/geotopografie/3d-geodaten/digitale-gelaendemodelle-dgm
- Geoshop RLP, DGM1: https://geoshop.rlp.de/opendata-dgm1.html
- BKG, DGM1 product specification (PDF): https://sg.geodatenzentrum.de/public/gdz/dokumentation/deu/dgm1.pdf
- Géoportail de la Wallonie, MNT 1 m 2021–2022: https://geoportail.wallonie.be/catalogue/fe13bc84-e371-46ca-9632-8ad4139f1ee5.html
- Géoportail de la Wallonie, LiDAR 2021–2022: https://geoportail.wallonie.be/lidar
- Géoportail de la Wallonie, Orthophotos 2023 Été: https://geoportail.wallonie.be/catalogue/ad55c2ce-62ad-4c3c-b3cf-8fbc270a6b6e.html
- INSPIRE geoportal, Lombardy DTM LiDAR 1 m: https://inspire-geoportal.ec.europa.eu/srv/api/records/m_amte:299FN3:e02c7579-8031-4563-fca5-e2f1523fa7d4?language=all
- dati.gov.it, Lombardy DTM LiDAR 1 m: https://www.dati.gov.it/node/view-dataset/dataset?id=10f8891f-0102-402e-8eee-35ec244b253b (returned 404 on 2026-09-22; the licence comes from the search listing)
