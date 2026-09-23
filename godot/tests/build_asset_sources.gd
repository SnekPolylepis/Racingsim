extends SceneTree
const Assets = preload("res://scripts/retro_assets.gd")


func _initialize():
	Assets.generating = true
	DirAccess.make_dir_recursive_absolute("res://assets/generated-originals")
	for night in [false, true]:
		for reflection in [false, true]:
			Assets.panorama(night, reflection)
	for pine in [false, true]:
		Assets.tree(pine)
	for kind in ["crowd", "armco", "tyre"]:
		Assets.painted(kind)
	for key in Assets.cache:
		var image = Assets.cache[key].get_image()
		image.clear_mipmaps()
		image.save_png("res://assets/generated-originals/" + key + ".png")
	var sky = Image.load_from_file("res://assets/cc0-source/sky.hdr")
	print("HDR source sample ", sky.get_format(), " ", sky.get_pixel(100, 100))
	sky.convert(Image.FORMAT_RGBF)
	sky.resize(256, 128, Image.INTERPOLATE_LANCZOS)
	print("HDR resized sample ", sky.get_pixel(30, 30))
	for night in [false, true]:
		for reflection in [false, true]:
			var out = Image.create(256, 128, false, Image.FORMAT_RGB8)
			for y in 128:
				for x in 256:
					var c = sky.get_pixel(x, y)
					c = Color(c.r / (c.r + .65), c.g / (c.g + .65), c.b / (c.b + .65)).linear_to_srgb()
					if night:
						c = c * Color(.20, .21, .30)
						c = c.lerp(Color("625546"), .3 * sin(PI * float(y) / 128))
					if y > 65 - 2 * sin(float(x) * .23) - sin(float(x) * .57):
						c = Color("15232c") if night else Color("596e60")
					if y > 78:
						c = Color("101924") if night else Color("494a40")
					if reflection and y > 46 and y < 50 and x % 61 < 32:
						c = Color("d4deeb")
					out.set_pixel(x, y, c)
			out.save_png("res://assets/generated-originals/sky" + str(night) + str(reflection) + ".png")
	print("Generated " + str(Assets.cache.size()) + " original source textures")
	quit()
