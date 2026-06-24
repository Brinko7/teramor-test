extends SceneTree

## Headless composite of the LPC sword SLASH (down-facing): the 64px body layers
## (now incl. eyes) centred inside LPC's oversized 192px frame + the 192px sword
## overlay, across the 6 swing frames. Validates the weapon arc focus-independently.

func _init() -> void:
	var base := "res://assets/lpc/char/"
	var layers := ["body", "eyes", "legs", "feet", "torso", "hair"]
	var row := 2          # LPC down
	var cell := 192
	var n := 6            # slash frames
	var hair := Color(0.42, 0.30, 0.20)
	var strip := Image.create(n * cell, cell, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.40, 0.49, 0.40, 1.0))
	var sword := Image.load_from_file(ProjectSettings.globalize_path(base + "sword/slash.png"))
	for f in range(n):
		var c := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		for layer in layers:
			var abs: String = ProjectSettings.globalize_path(base + str(layer) + "/slash.png")
			if not FileAccess.file_exists(abs):
				continue
			var img := Image.load_from_file(abs)
			var reg := img.get_region(Rect2i(f * 64, row * 64, 64, 64))
			if reg.get_format() != Image.FORMAT_RGBA8:
				reg.convert(Image.FORMAT_RGBA8)
			c.blend_rect(reg, Rect2i(0, 0, 64, 64), Vector2i(64, 64))
		if sword != null:
			var sreg := sword.get_region(Rect2i(f * 192, row * 192, 192, 192))
			if sreg.get_format() != Image.FORMAT_RGBA8:
				sreg.convert(Image.FORMAT_RGBA8)
			c.blend_rect(sreg, Rect2i(0, 0, 192, 192), Vector2i(0, 0))
		strip.blit_rect(c, Rect2i(0, 0, cell, cell), Vector2i(f * cell, 0))
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	strip.save_png(ProjectSettings.globalize_path("res://_lpc_slash.png"))
	print("wrote _lpc_slash.png")
	quit()
