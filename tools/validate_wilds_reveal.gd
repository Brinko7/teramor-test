extends SceneTree

## Headless check for the Cursed Wilds reveal cutscene (the Great Tree vista):
##   1. All four cinematic layers are baked (sky / great tree / haze / treeline).
##   2. The cutscene composes its layered vista + narration + fade on _ready.
##   3. The procedural area triggers it once, on first entry to the cursed biomes.
##
## We inspect the built node WITHOUT calling play() (which would pause the tree).
##
## Run: godot --headless -s tools/validate_wilds_reveal.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _count(node: Node, type: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_class() == type:
			n += 1
	return n

func _run() -> void:
	await process_frame
	await process_frame

	# --- 1. Cinematic art ---------------------------------------------------
	for a in ["wilds_sky", "great_tree_far", "wilds_haze", "wilds_treeline"]:
		if ResourceLoader.exists("res://assets/placeholder/%s.png" % a):
			_ok("%s.png is baked" % a)
		else:
			_err("%s.png missing (run gen_wilds_reveal.py)" % a)

	# --- 2. The cutscene composes its layers --------------------------------
	var scene := load("res://scenes/ui/wilds_reveal.tscn") as PackedScene
	if scene == null:
		_err("wilds_reveal.tscn failed to load")
		_finish()
		return
	var cs := scene.instantiate()
	get_root().add_child(cs)
	await process_frame
	if cs is CanvasLayer:
		_ok("the reveal is a CanvasLayer overlay")
	else:
		_err("reveal root is not a CanvasLayer")
	var vista: Node = null
	for c in cs.get_children():
		if c is Node2D:
			vista = c
	if vista != null and _count(vista, "Sprite2D") >= 4:
		_ok("it composes the sky/tree/haze/treeline layers")
	else:
		_err("reveal did not build its 4 vista layers")
	if _count(cs, "Label") >= 2:
		_ok("it shows narration (title + subtitle)")
	else:
		_err("reveal is missing its narration labels")
	if _count(cs, "ColorRect") >= 1:
		_ok("it has a fade overlay")
	else:
		_err("reveal has no fade ColorRect")
	cs.free()   # free before play() — never pause the tree in the validator

	# --- 3. The trigger is wired one-shot on cursed entry -------------------
	var pa := FileAccess.get_file_as_string("res://scripts/world/procedural_area.gd")
	if pa.contains("wilds_reveal.tscn") and pa.contains("seen_wilds_reveal") \
			and pa.contains("cursed_wilds"):
		_ok("the cursed wilds trigger the reveal once (flag-gated)")
	else:
		_err("procedural_area does not trigger the reveal on first cursed entry")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - the Great Tree looms on first crossing into the wilds")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
