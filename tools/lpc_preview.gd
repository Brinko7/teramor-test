extends SceneTree

## Headless composite of the LPC paper-doll (focus-independent visual check): stacks
## body/legs/feet/torso/hair for a few poses into a preview strip. LPC rows are
## up=0, left=1, down=2, right=3.

func _init() -> void:
	var base := "res://assets/lpc/char/"
	var layers := ["body", "eyes", "eyebrows", "nose", "legs", "feet", "torso", "hair"]
	# [anim, lpc_row, frame_idx]  — front-facing close-ups to judge the face
	var poses := [
		["idle", 2, 0], ["walk", 2, 1], ["walk", 2, 4], ["slash", 2, 1],
	]
	var cw := 64
	var gap := 6
	var strip := Image.create(poses.size() * (cw + gap) + gap, cw + gap * 2, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.40, 0.49, 0.40, 1.0))
	for i in range(poses.size()):
		var p: Array = poses[i]
		var cell := Image.create(cw, cw, false, Image.FORMAT_RGBA8)
		for layer in layers:
			var path: String = base + str(layer) + "/" + str(p[0]) + ".png"
			var abs: String = ProjectSettings.globalize_path(path)
			if not FileAccess.file_exists(abs):
				continue
			var img := Image.load_from_file(abs)
			if img == null:
				continue
			var reg := img.get_region(Rect2i(int(p[2]) * cw, int(p[1]) * cw, cw, cw))
			if reg.get_format() != Image.FORMAT_RGBA8:
				reg.convert(Image.FORMAT_RGBA8)
			cell.blend_rect(reg, Rect2i(0, 0, cw, cw), Vector2i(0, 0))
		strip.blit_rect(cell, Rect2i(0, 0, cw, cw), Vector2i(gap + i * (cw + gap), gap))
	strip.resize(strip.get_width() * 6, strip.get_height() * 6, Image.INTERPOLATE_NEAREST)
	strip.save_png(ProjectSettings.globalize_path("res://_lpc_preview.png"))
	print("wrote _lpc_preview.png")
	quit()
