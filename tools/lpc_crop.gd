extends SceneTree

## Crop tileable 32x32 ground tiles out of the LPC tilesets (Godot has a real PNG
## decoder, which our stdlib pipeline doesn't) so the prototype ground can region-
## repeat them. Trees/props use region_rect on the full tileset directly, no crop.

func _init() -> void:
	var dir := "res://assets/lpc/tiles/"
	_crop(dir + "grass.png", Rect2i(32, 130, 32, 32), dir + "grass_tile.png")
	_crop(dir + "grass.png", Rect2i(16, 150, 32, 32), dir + "grass_tile_b.png")
	_crop(dir + "dirt.png", Rect2i(32, 130, 32, 32), dir + "dirt_tile.png")
	print("LPC crop done")
	quit()

func _crop(src: String, rect: Rect2i, dst: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img == null:
		push_error("could not load " + src)
		return
	var tile := img.get_region(rect)
	tile.save_png(ProjectSettings.globalize_path(dst))
	print("wrote ", dst, " ", tile.get_size())
