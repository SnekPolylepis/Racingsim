# Downtown City MegaKit pieces (CHI-LOOK-02)

Source: Quaternius, "Downtown City MegaKit" (free version), https://quaternius.com , CC0 1.0 (`License.txt`).
Only the pieces listed in `tools/build_downtown_kit.gd` are used. That script bakes each glTF into one compact
`meshes/<piece>.res` (surfaces merged per our own material, glTF materials and fake-interior shaders dropped)
and writes the `mat_*.tres` materials; it reads the kit from a local folder, so it is a maintainer tool, not run
at game time. `textures/*.jpg` are the kit's 2048 px albedos reduced to 1024 px (mipmaps on, VRAM compressed).

The free kit has no storefront signs, fire escapes, water tanks, hydrants, newspaper boxes or benches; it does
have first-floor windows and walls, cornices, doors, AC units, bollards, planters, roof and stair pieces.

Used by `trackgen/chicago_kit.gd` (ground floors and cornices on buildings facing the route). Total size about
0.7 MB.
