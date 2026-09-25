# Reference board

Real photographs and real game screenshots, collected for Look-0. Private research/reference use,
owner-approved. No game geometry, font, logo, texture, sound or code is extracted from a reference
game; these are for visual comparison only (texel density, contrast, enclosure, colour) and are
excluded from export (`docs/*` is in every export preset's `exclude_filter`).

**This board is incomplete relative to the Look-0 brief.** Two things blocked collection mid-session:
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
