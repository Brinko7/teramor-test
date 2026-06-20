extends SceneTree

## Headless check that every named map location now has a real, loadable scene that
## tags itself on the map. For each WorldLocation, loads its scene_path, instantiates
## it (the player, buildings, HUD and the LocationScene root all run _ready), and
## asserts the root claimed the right id via WorldMap.claim_arrival.
##
## Run: godot --headless -s tools/validate_locations.gd

const IDS := [
	"hollen", "mirefen", "plint", "kingsford", "terakin",
	"the_holdfast", "the_thornwall", "elven_glade", "the_great_tree",
]

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	var wm = get_root().get_node_or_null("WorldMap")
	if wm == null:
		_err("WorldMap autoload missing")
		quit()
		return

	for id in IDS:
		var loc = wm.get_location(StringName(id))
		if loc == null:
			_err("no WorldLocation for '%s'" % id)
			continue
		var path: String = loc.scene_path
		if path == "" or not ResourceLoader.exists(path):
			_err("%s has no loadable scene_path (%s)" % [id, path])
			continue
		var packed = load(path)
		if packed == null:
			_err("%s scene failed to load: %s" % [id, path])
			continue
		var inst = packed.instantiate()
		if inst == null:
			_err("%s scene failed to instantiate" % id)
			continue
		get_root().add_child(inst)
		await process_frame
		await process_frame
		# The LocationScene root claims its id on load -> becomes the current place.
		if String(wm.get_current()) != id:
			_err("%s did not tag itself on load (current = %s)" % [id, wm.get_current()])
		inst.queue_free()
		await process_frame

	if _fail == 0:
		print("RESULT: PASS - all %d named locations have a real scene that loads + self-tags" % IDS.size())
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
