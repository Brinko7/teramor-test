extends SceneTree

## Load-time smoke test after the signpost root-type change (Node2D -> Area2D) and
## the combat-signal signature changes. Instantiates the signpost-bearing world
## scenes and the player, processing a few frames so their _ready runs. We only
## fail on hard SCRIPT/parse errors (printed to stderr) and on null loads here;
## gameplay push_warnings from booting a world bare are expected and ignored.

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	for path in [
		"res://scenes/world/settlement.tscn",
		"res://scenes/world/town.tscn",
		"res://scenes/entities/player.tscn",
	]:
		var packed = load(path)
		if packed == null:
			_err("failed to load %s" % path)
			continue
		var inst = packed.instantiate()
		if inst == null:
			_err("failed to instantiate %s" % path)
			continue
		get_root().add_child(inst)
		await process_frame
		await process_frame
		# Confirm every signpost in the scene became an interactable Area2D.
		for sign in _find_signposts(inst):
			if not (sign is Area2D):
				_err("%s: a signpost did not load as Area2D" % path)
		inst.queue_free()
		await process_frame
	if _fail == 0:
		print("RESULT: PASS - world scenes + player instantiate; signposts are Area2D")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()

func _find_signposts(node: Node) -> Array:
	var out: Array = []
	if node.get_script() != null and node.get_script().resource_path.ends_with("signpost.gd"):
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_signposts(c))
	return out
