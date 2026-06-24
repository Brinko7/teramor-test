extends SceneTree

## Down-facing composite on a MAGENTA background so transparency is obvious.
## Cells: full char (idle), full char (walk), body-only (idle). If the head shows
## magenta, the body sheet's head is transparent.

func _init() -> void:
	var base := "res://assets/lpc/char/"
	var cell := 64
	var cells: Array = []
	var full := ["body", "head", "eyes", "eyebrows", "nose", "legs", "feet", "torso", "hair"]
	var specs := [["idle", 0, full], ["walk", 1, full], ["idle", 0, ["body"]]]
	for spec in specs:
		var anim: String = spec[0]
		var f: int = spec[1]
		var layers: Array = spec[2]
		var c := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		c.fill(Color(1, 0, 1, 1))
		for layer in layers:
			var abs: String = ProjectSettings.globalize_path(base + str(layer) + "/" + anim + ".png")
			if not FileAccess.file_exists(abs):
				continue
			var img := Image.load_from_file(abs)
			var reg := img.get_region(Rect2i(f * cell, 2 * cell, cell, cell))   # row 2 = down
			if reg.get_format() != Image.FORMAT_RGBA8:
				reg.convert(Image.FORMAT_RGBA8)
			c.blend_rect(reg, Rect2i(0, 0, cell, cell), Vector2i(0, 0))
		cells.append(c)
	var gap := 6
	var strip := Image.create(cells.size() * (cell + gap) + gap, cell + gap * 2, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.3, 0.3, 0.3, 1.0))
	for i in range(cells.size()):
		strip.blit_rect(cells[i], Rect2i(0, 0, cell, cell), Vector2i(gap + i * (cell + gap), gap))
	strip.resize(strip.get_width() * 6, strip.get_height() * 6, Image.INTERPOLATE_NEAREST)
	strip.save_png(ProjectSettings.globalize_path("res://_lpc_full.png"))
	print("wrote _lpc_full.png  (full-idle | full-walk | body-only-idle, magenta = transparent)")
	quit()
