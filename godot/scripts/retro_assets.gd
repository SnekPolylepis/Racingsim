extends RefCounted
## Baked original patterns and CC0 photograph derivatives; see THIRD-PARTY.md.
## Code-generated fallbacks keep source development usable before an asset build.
static var cache = {}
static var generating = false


static func baked(key):
	var path = "res://assets/ps2/" + key + ".png"
	return load(path) if not generating and ResourceLoader.exists(path) else null


static func panorama(night = false, reflection = false):
	var key = "sky" + str(night) + str(reflection)
	var texture = baked(key)
	if texture:
		return texture
	if cache.has(key):
		return cache[key]
	var img = Image.create(256, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 256:
			var u = float(x) / 256
			var v = float(y) / 128
			var top = Color("0b1035") if night else Color("3278b5")
			var horizon = Color("56506b") if night else Color("a3c3d4")
			var c = top.lerp(horizon, pow(clampf(v * 2, 0, 1), .65))
			var clouds = sin(u * 37 + sin(u * 18) * 2) * .015 + .33
			if absf(v - clouds) < .018 or absf(v - clouds + .11) < .008:
				c = c.lerp(Color("77758b") if night else Color("fff2d3"), .45)
			var ridge = .515 - .023 * sin(u * 31) - .018 * sin(u * 67) - .007 * sin(u * 431)
			if v > ridge:
				c = Color("1a2634") if night else Color("627974")
			if v > .58:
				c = Color("111b29") if night else Color("4b5148")
			var sun_dist = Vector2((u - .4111) * 2, v - .3444).length()
			if sun_dist < .026:
				c = c.lerp(
					Color("d3e7ff") if night else Color("fff9ce"), 1 - smoothstep(.012, .026, sun_dist)
				)
			if reflection and v > .36 and v < .39 and (x % 61 < 32):
				c = Color("e0eefa")
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	cache[key] = ImageTexture.create_from_image(img)
	return cache[key]


static func tree(pine):
	var key = "tree" + str(pine)
	var texture = baked(key)
	if texture:
		return texture
	if cache.has(key):
		return cache[key]
	var img = Image.create(128, 256, false, Image.FORMAT_RGBA8)
	var brush = FastNoiseLite.new()
	brush.seed = 742
	brush.frequency = .11
	brush.fractal_octaves = 3
	for y in 256:
		for x in 128:
			var u = float(x) / 128 - .5
			var v = float(y) / 256
			var noise = brush.get_noise_2d(x, y) * 1.5
			var inside = false
			if pine:
				var width = (.04 + v * .50) * (.80 + .2 * sin(v * 77))
				inside = v > .045 and v < .86 and absf(u) < width + noise * .016
			else:
				inside = Vector2(u * 1.9, (v - .41) * 2.6).length() < .86 + noise * .045 + .07 * sin(v * 53)
			var c = Color("274328").lerp(Color("9caa65"), clampf(.35 - u * .5 + noise * .24 - v * .17, 0, 1))
			if not inside:
				c = Color("655640")
				c.a = 1.0 if absf(u) < .028 and v > .3 and v < .98 else 0.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	cache[key] = ImageTexture.create_from_image(img)
	return cache[key]


static func painted(kind):
	var texture = baked(kind)
	if texture:
		return texture
	if cache.has(kind):
		return cache[kind]
	var img = Image.create(256, 128, false, Image.FORMAT_RGB8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 2048
	for y in 128:
		for x in 256:
			var c = Color("b0b8b4")
			if kind == "crowd":
				var block = x / 3 + (y / 5) * 83
				c = [Color("d7c2a1"), Color("a74131"), Color("c2c9d0"), Color("38607d"), Color("28343d")][
					block % 5
				]
				if y % 5 > 2 or x % 3 == 0:
					c = c.darkened(.6)
			else:
				c = c.darkened(.35 * absf(sin(float(y) / 128 * PI * 6)))
				if kind == "tyre":
					c = Color("b02d24") if x % 64 < 32 else Color("d6d0ba")
					c = c.darkened(.18 + .4 * float(y % 32 < 5))
			c = c.darkened(rng.randf() * .10)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	cache[kind] = ImageTexture.create_from_image(img)
	return cache[kind]
