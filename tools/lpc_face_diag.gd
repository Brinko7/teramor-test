extends SceneTree

## Side-by-side face diagnostic: the pre-composed princess (clean reference) vs the
## modular player face (current layers), front-idle head, zoomed, so the difference
## is obvious. Heads only (top 40px of the 64px frame).

func _init() -> void:
	var base := "res://assets/lpc/char/"
	var row := 2          # LPC down
	var hcrop := 40       # head region height
	var cell := 64
	var cells: Array = []

	# 0: princess reference (pre-composed)
	var prin := Image.load_from_file(ProjectSettings.globalize_path("res://assets/lpc/sprites/princess.png"))
	cells.append(prin.get_region(Rect2i(0, row * cell, cell, hcrop)))

	# 1: my modular face, current layers
	var layers := ["body", "eyes", "eyebrows", "nose", "hair"]
	var c := Image.create(cell, hcrop, false, Image.FORMAT_RGBA8)
	for layer in layers:
		var abs: String = ProjectSettings.globalize_path(base + str(layer) + "/idle.png")
		if not FileAccess.file_exists(abs):
			continue
		var img := Image.load_from_file(abs)
		var reg := img.get_region(Rect2i(0, row * cell, cell, hcrop))
		if reg.get_format() != Image.FORMAT_RGBA8:
			reg.convert(Image.FORMAT_RGBA8)
		c.blend_rect(reg, Rect2i(0, 0, cell, hcrop), Vector2i(0, 0))
	cells.append(c)

	# 2: just body + eyes (no brows/nose)
	var c2 := Image.create(cell, hcrop, false, Image.FORMAT_RGBA8)
	for layer in ["body", "eyes", "hair"]:
		var abs2: String = ProjectSettings.globalize_path(base + str(layer) + "/idle.png")
		var img2 := Image.load_from_file(abs2)
		var reg2 := img2.get_region(Rect2i(0, row * cell, cell, hcrop))
		if reg2.get_format() != Image.FORMAT_RGBA8:
			reg2.convert(Image.FORMAT_RGBA8)
		c2.blend_rect(reg2, Rect2i(0, 0, cell, hcrop), Vector2i(0, 0))
	cells.append(c2)

	var gap := 6
	var strip := Image.create(cells.size() * (cell + gap) + gap, hcrop + gap * 2, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.40, 0.49, 0.40, 1.0))
	for i in range(cells.size()):
		strip.blit_rect(cells[i], Rect2i(0, 0, cell, hcrop), Vector2i(gap + i * (cell + gap), gap))
	strip.resize(strip.get_width() * 8, strip.get_height() * 8, Image.INTERPOLATE_NEAREST)
	strip.save_png(ProjectSettings.globalize_path("res://_lpc_face.png"))
	print("wrote _lpc_face.png  (princess | current | body+eyes)")
	quit()
