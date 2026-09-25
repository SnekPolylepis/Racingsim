# Textures

All textures in this folder are from [Poly Haven](https://polyhaven.com) and are released under **CC0** (public domain); no attribution is required, but credit is given here anyway.

| Folder | Poly Haven asset | Resolution | Used for |
|---|---|---|---|
| `asphalt_track` | https://polyhaven.com/a/asphalt_track | 2K | Road surface (`shaders/road.gdshader`) |
| `grass_ground` | https://polyhaven.com/a/grass_ground | 1K | Grass and terrain (`shaders/ground.gdshader`) |
| `gravel_floor` | https://polyhaven.com/a/gravel_floor | 1K | Painted gravel runoff (`shaders/ground.gdshader`) |
| `concrete_floor_02` | https://polyhaven.com/a/concrete_floor_02 | 1K | Curbs, pit and grandstand concrete |
| `chicago/brick_wall_003` | https://polyhaven.com/a/brick_wall_003 | 1K | Warm stone and glazed-brick Loop streetfronts |
| `chicago/red_brick_03` | https://polyhaven.com/a/red_brick_03 | 1K | Older masonry blocks near the river |
| `chicago/concrete_floor_damaged_01` | https://polyhaven.com/a/concrete_floor_damaged_01 | 1K | Loop sidewalk stone |
| `chicago/large_square_pattern_01` | https://polyhaven.com/a/large_square_pattern_01 | 1K | Riverwalk and lakefront pavers |

Maps per set: `_diff` (albedo, sRGB), `_nor_gl` (OpenGL-convention normal map, which Godot expects) and `_rough` (roughness). Downloaded September 2026.

Chicago sets use their original 1K source maps without downsampling. They are CC0 1.0 from
Poly Haven; the water movement is an original time-driven shader (`shaders/chicago_water.gdshader`),
not a downloaded texture. See `THIRD-PARTY.md` for set-specific credits and packaged licensing.
