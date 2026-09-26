# Reference board

Real photographs and real game screenshots, collected for Look-0. Private research/reference use,
owner-approved. No game geometry, font, logo, texture, sound or code is extracted from a reference
game; these are for visual comparison only (texel density, contrast, enclosure, colour) and are
excluded from export (`docs/*` is in every export preset's `exclude_filter`).

**This board was incomplete when first pushed; see "Added in review" at the end for the GT4 Nordschleife and NFSU frames that complete it.** Two things blocked collection mid-session:
mobygames.com and gamefaqs.gamespot.com serve a Cloudflare JS challenge to non-browser requests (curl
gets a "Just a moment..." page, not the screenshot), so the working path was the Wayback Machine's
archived copies of those galleries — and partway through, `web.archive.org` itself went temporarily
offline ("Internet Archive services are temporarily offline", their own status page). That stopped
collection before NFS Underground, GT4's Nordschleife specifically, a second European circuit, and any
close-up texture shots were reached. What's here is everything collected before that outage; the gaps
are carried as `needs owner` in `godot/docs/rebuild/QUEUE.md` (row `Look-0-refs`) rather than invented.

## Real-world Nordschleife (how the road sits in the ground)

All CC-licensed Flickr photos, found via the Openverse API (openverse.org), fetched directly — not
through Wayback, and unaffected by the outage above.

| File | Source | What it teaches |
|---|---|---|
| `real-nordschleife-flugplatz.jpg` | [Flickr, CC BY-NC 2.0](https://www.flickr.com/photos/discoloop/3657350815) — search "Nordschleife Flugplatz" | The Flugplatz crest: a painted red/white kerb at the apex, low corrugated armco right at the grass edge, a mown verge maybe 2 m wide, then dense spruce wall starting immediately. The road banks away over the crest with no runoff beyond the barrier — a ditch/drop is implied, not paved. |
| `real-nordschleife-adenauer-forst.jpg` | [Flickr, CC BY-NC-SA 2.0](https://www.flickr.com/photos/discoloop/8813987341) — "In the forest, near Flugplatz" | A GT4-liveried Cayman mid-corner: shows how close the tree canopy actually leans over the armco (no gap — trunks are within 1-2 car widths of the barrier), and the road's mid-grey matte surface in flat overcast light (no gloss, no specular highlight on wet-looking tarmac that is in fact dry). |
| `real-nordschleife-brunnchen.jpg` | [Flickr, CC BY-SA 2.0, cosmic_spanner](https://www.flickr.com/photos/17385972@N00/217184650) — "Zakspeed Capri through Brünnchen" | The Brünnchen double-apex from above: track-edge lettering painted on the tarmac, a single chain-link/armco line maybe a car-width off the road, then unbroken forest on both sides up a slope — there is no graduated barrier→grass→forest band here, forest starts almost at the fence. |
| `real-nordschleife-overview-autumn.jpg` | [Flickr, CC BY-NC-ND 2.0, Lowfloater Photography](https://live.staticflickr.com/5499/10500851403_8fb4218588_b.jpg), titled "Blick auf das Caracciola-Karussell" | Kept as a generic overview, **not** as the Karussell: the image itself shows a high vantage over a forest section in autumn colour with a "SAVE THE RING" campaign watermark and a castle-topped hill silhouette, not the Karussell's banked concrete bowl — the uploader's title doesn't match the visible content, so the corner claim is dropped rather than repeated. Still useful for horizon/enclosure at canopy height. |
| `real-nordschleife-overview-vintage.jpg` | [Flickr, CC BY-ND 2.0, *fotopiti*](https://www.flickr.com/photos/fotopiti/4814357669) — captioned only "Nordschleife 2010"; the Dorint hotel visible in the background places this near the GP-Strecke/start-finish area, not a numbered corner | A wide, deliberately vintage-filtered shot: still useful for the general proportion of forest-to-road-to-buildings near the paddock, but the colour grade in the photo itself is not a lighting reference (it's a post-process filter, not how the track actually looks). |
| `real-nordschleife-panorama-banking.jpg` | [Flickr, CC BY-SA 2.0](https://www.flickr.com/photos/17385972@N00/3759019483) — "Panorama"; exact corner not identified by the source caption | A banked corner under a double rainbow: shows the camber of a mid-speed corner, a footbridge crossing the track, and how tight the tree line sits against the outside kerb even on a section wide enough for a run-off apron. |

Honesty note: two of the six (`overview-autumn`, `overview-vintage`) are **not** confirmed to be
Hatzenbach, Flugplatz, T13 or Aremberg specifically — Flickr search relevance is not corner
identification. They're kept because the enclosure/horizon information they carry is real and useful;
the filenames say "overview", not a corner name, so nothing here overclaims. `Flugplatz`,
`Adenauer Forst` and `Brünnchen` are confirmed either by the photographer's own caption (Adenauer Forst,
Brünnchen) or by the search term matching the image content on inspection (Flugplatz). T13 and Aremberg
specifically were not obtained: Aremberg candidates found were dusk/night races too dark to read any
surface or barrier detail, and were dropped rather than included as filler.

## PS2 gameplay (game screenshots)

Sourced from MobyGames' PS2 screenshot galleries via the Wayback Machine (MobyGames itself blocks
non-browser requests). Only two were retrieved before the Archive outage, both from Gran Turismo 4's
default contributor screenshot set — **neither is confirmed to be the Nordschleife**; MobyGames'
gallery captions for this set are UI-only ("Driver's seat view", "Photo drive"), not track names.

| File | Source | What it teaches |
|---|---|---|
| `gt4-unidentified-cockpit-view.jpg` | [MobyGames, GT4 PS2 screenshot #4219a6c4](https://www.mobygames.com/game/17689/gran-turismo-4/screenshots/ps2/) via Wayback Machine, captioned "Driver's seat view" | A narrow stone-walled European road (not the Nordschleife's forest — track not identified), driver's-eye HUD: the minimap style, lap/position readout in the corners, and the low native resolution of the road and wall textures at typical driving distance — this is the actual in-game texel density GT4 shipped with, before any nostalgia-driven upscaling assumption. |
| `gt4-unidentified-photomode-car.jpg` | [MobyGames, GT4 PS2 screenshot](https://www.mobygames.com/game/17689/gran-turismo-4/screenshots/ps2/) via Wayback Machine, captioned "Photo drive; that one was saved on USB flash drive" | GT4's photo-mode lighting: a warm key light on the car body against a cooler, desaturated background with autumn foliage — the car itself carries far more contrast and saturation than the environment behind it, which reads as a flat mid-value. Confirms the "warm key, cool weak fill" balance ART-DIRECTION.md's daylight rule now cites. |

Not collected (blocked by the outage, not by choice): NFS Underground night screenshots (open street,
tunnel, wet-road reflections), a GT4 Nordschleife shot specifically labelled by corner, a second GT4
European circuit (GT4 does **not** include Spa — confirmed by search; Circuit de la Sarthe/Le Mans is
the in-game substitute, per the task's own fallback instruction, but no screenshot of it was reached),
and any close-up asphalt/kerb/armco texture shot.

## Reproducing this board

1. Retry the Wayback Machine once `https://web.archive.org` is reachable again (`curl -sS -o /dev/null
   -w '%{http_code}' https://web.archive.org` should read `200`/`301`/`302`, not a connection reset).
2. `tests/v2/track_screenshots.gd`'s companion script `docs/art/reference/wb_fetch.py`-style pattern
   (query the CDX API for the gallery URL, fetch the closest snapshot with `.../web/<timestamp>id_/<url>`,
   `--compressed`) — the gallery HTML embeds `cdn.mobygames.com/*.webp` thumbnails with figcaptions;
   the ones worth keeping are captioned with a track/corner name, not a UI screen name.
3. For NFS Underground specifically: `https://www.mobygames.com/game/11175/need-for-speed-underground/screenshots/ps2/`.
4. For a confirmed-Nordschleife GT4 shot: search MobyGames' *other* contributor screenshot sets for this
   game (the default set on the gallery's first page is one contributor's UI/menu tour, not a lap).

## Added in review (Claude Opus 5.5, 2026-09-24): GT4 Nordschleife and NFS Underground

This closes the gaps listed above. Found through Bing Images in a real browser, which avoids the Cloudflare block. The frames are YouTube video thumbnails (1280x720 captures of the video), plus one official GT4 press screenshot. For private reference only, owner-approved. Frames marked "upscaled" come from PCSX2 emulator footage rendered above native resolution, so judge texture *content* from them, not sharpness. The frames marked "native" are native PS2 captures.

| File | Source | What it teaches |
|---|---|---|
| `gt4-nordschleife-official-press-overview.jpg` | [Kikizo GT4 screenshot blowout, Oct 2004](https://games.kikizo.com/news/200410/014m.asp) (official Polyphony press image) | From above: a narrow road with white edge lines on both sides, fan graffiti painted on the tarmac, grass strips, armco each side, dense mixed forest to the verge, forested hills filling the horizon. |
| `gt4-nordschleife-chase-kerbs-armco.jpg` | [YouTube ClrK0DIC7BI](https://www.youtube.com/watch?v=ClrK0DIC7BI), GT4 Special Licence Nordschleife | Double and triple armco rails on dark posts right beside a narrow grass strip. Flat red/white kerb blocks. Matte grey road with visible repairs. Tall mixed trees overhead. |
| `gt4-nordschleife-chase-edge-lines.jpg` | [YouTube UJR5cvpC3s4](https://www.youtube.com/watch?v=UJR5cvpC3s4), PS2 online GT4 | A continuous white edge line and a white line on the inside of the bend. Long armco. A forest band at the far edge; bright photographic sky. |
| `gt4-nordschleife-bonnet-forest-wall.jpg` | [YouTube rzsapliZMcU](https://www.youtube.com/watch?v=rzsapliZMcU), GT4 AC 427 (PCSX2) | Bonnet view: a matte road with large darker repair patches and tyre marks, armco on both sides, and a continuous photographic forest wall. No horizon visible. |
| `gt4-nordschleife-bonnet-straight-upscaled.jpg` | [YouTube AncHuQLMZHY](https://www.youtube.com/watch?v=AncHuQLMZHY), GT4 4K (PCSX2, upscaled) | A straight with a grass slope rising on the left, armco, and distant forested hills. |
| `gt4-nordschleife-chase-kerb-apex.jpg` | [YouTube 1ITKCYROfmQ](https://www.youtube.com/watch?v=1ITKCYROfmQ) | Split chase view: kerb placement at the apex, road width relative to the car. |
| `gt4-car-detail-slr.jpg` | [YouTube g9YY5l_8Mjc](https://www.youtube.com/watch?v=g9YY5l_8Mjc), GT4 driving mission | GT4 car detail (Mercedes SLR): smooth panels, glass reflections, wheel and lamp detail. The standard our car bodies are judged against. |
| `nfsu-night-wide-road-barriers.jpg` | [GameRant, "Best PS2 racing games"](https://gamerant.com/) (article image) | A night highway: concrete barriers with chevrons, lit stadium and buildings, a blue-black sky, and light reflections on the road. |
| `nfsu-night-wet-street-reflections.jpg` | [YouTube 1KNuEdvLu8Y](https://www.youtube.com/watch?v=1KNuEdvLu8Y), NFSU Underground mode (PS2) | The signature NFSU look: a wet road with long specular light streaks, lit tower skyline, teal/orange palette. |
| `nfsu-night-start-city-native.jpg` | [MobyGames NFSU PS2 demo screenshot](https://www.mobygames.com/game/11175/need-for-speed-underground/screenshots/ps2/) (native) | Native PS2 resolution: dense lit city wall, neon, palm trees, the start line. |
| `nfsu-night-neon-street.jpg` | [YouTube 4w1OV_TkRFU](https://www.youtube.com/watch?v=4w1OV_TkRFU), NFSU (PS2) | A street enclosed by lit buildings and neon signs; road markings. |
| `nfsu-night-motion-blur-native.jpg` | [MobyGames NFSU PS2 demo screenshot](https://www.mobygames.com/game/11175/need-for-speed-underground/screenshots/ps2/) (native) | Speed: heavy motion blur and streaking of lights, native PS2. |
| `nfsu-night-wet-start-grid.jpg` | [YouTube 6qFj7UtP4eE](https://www.youtube.com/watch?v=6qFj7UtP4eE), NFSU demo (PCSX2) | Wet start grid: reflections of the cars and lamps in the road, a city wall, a tree-lined avenue. |

Still missing: a GT4 Spa or Le Mans frame (GT4 has no Spa), and close-up texture shots. Spa is judged against the real-world photos and the GT4 Nordschleife rules above.

## Karussell (LOOK-16)
- `real-nordschleife-karussell-lauda-1973.jpg` and `real-nordschleife-karussell-capri-1973.jpg`: Lothar Spurzem, Wikimedia Commons, CC BY-SA 2.0 de. Both are 1973 photos in the Karussell. Inside out, they show the narrow asphalt strip, the banked concrete slab band with transverse joints, and the outer asphalt and armco.
- Geometry notes: nring.info ("Caracciola-Karussell"), Porsche Newsroom 2020 ("Banking on the Nürburgring-Nordschleife"), oversteer48.com. Near-180-degree left hairpin, concreted 1932, concrete banked ~17-20 degrees, outer asphalt ~10 degrees, radii ~15 m (concrete) and ~25 m (asphalt), 70 mm minimum ground clearance for GT3 cars.
