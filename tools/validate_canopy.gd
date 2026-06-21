extends SceneTree

## Headless check for the forest canopy (depth & vistas, pt.1):
##   1. CanopyFX is registered and built (the dapple overlay + its tile texture).
##   2. set_canopy(true/false) drives the per-frame drift on and off.
##   3. A zone change resets the canopy off (it never lingers into a town/cave).
##   4. The wooded biomes carry has_canopy; open ground and caves do not.
##
## Run: godot --headless -s tools/validate_canopy.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	# --- 1. CanopyFX exists + is built -------------------------------------
	var canopy := get_root().get_node_or_null("CanopyFX")
	if canopy != null and canopy.has_method("set_canopy"):
		_ok("CanopyFX autoload is registered")
	else:
		_err("CanopyFX autoload missing or has no set_canopy()")
		_finish()
		return
	if ResourceLoader.exists("res://assets/placeholder/canopy_dapple.png"):
		_ok("the canopy dapple tile is baked")
	else:
		_err("canopy_dapple.png is missing (run gen_canopy.py)")
	var has_sprite := false
	for child in canopy.get_children():
		if child is Sprite2D:
			has_sprite = true
	if has_sprite:
		_ok("CanopyFX built its dapple sprite")
	else:
		_err("CanopyFX has no dapple Sprite2D")

	# --- 2. set_canopy drives the drift on/off -----------------------------
	canopy.call("set_canopy", true)
	await process_frame
	if canopy.is_processing():
		_ok("set_canopy(true) starts the drift")
	else:
		_err("set_canopy(true) did not enable processing")
	canopy.call("set_canopy", false)
	await process_frame
	if not canopy.is_processing():
		_ok("set_canopy(false) stops the drift")
	else:
		_err("set_canopy(false) did not disable processing")

	# --- 3. A zone change resets it off ------------------------------------
	var music := get_root().get_node_or_null("MusicManager")
	if music != null:
		music.call("enter_zone", &"wild")
		canopy.call("set_canopy", true)
		await process_frame
		music.call("enter_zone", &"town")   # zone change -> canopy resets off
		await process_frame
		if not canopy.is_processing():
			_ok("a zone change clears the canopy (no lingering into town)")
		else:
			_err("canopy did not reset on zone change")
	else:
		_err("MusicManager autoload missing")

	# --- 4. Biome flags: wooded on, open/underground off -------------------
	for b in ["deepwood", "roadside", "cursed_wilds", "vast_edge"]:
		var bio := load("res://resources/world/biomes/%s.tres" % b) as BiomeData
		if bio != null and bio.has_canopy:
			_ok("%s has a canopy" % b)
		else:
			_err("%s should have has_canopy" % b)
	for b in ["plains", "desert", "cave"]:
		var bio := load("res://resources/world/biomes/%s.tres" % b) as BiomeData
		if bio != null and not bio.has_canopy:
			_ok("%s is open (no canopy)" % b)
		else:
			_err("%s should not have a canopy" % b)

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - dappled light drifts under the forest canopy")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
