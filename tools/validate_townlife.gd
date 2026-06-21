extends SceneTree

## Headless check for the "living cities" pass:
##   1. The Townsfolk pedestrian + its scene are well-formed (4x8 walk sheet).
##   2. The TownsfolkCrowd spawner actually fills its PARENT with pedestrians (so
##      they y-sort against the town), positioned on the stroll waypoints.
##   3. Chimney smoke exists and is wired onto the hearth buildings.
##   4. Cleeve's Landing carries a crowd.
##
## Run: godot --headless -s tools/validate_townlife.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _is_townsfolk(node: Node) -> bool:
	var s := node.get_script() as Script
	return s != null and s.resource_path.ends_with("townsfolk.gd")

func _run() -> void:
	await process_frame
	await process_frame

	# --- 1. The pedestrian scene is well-formed ----------------------------
	var folk_scene := load("res://scenes/entities/townsfolk.tscn") as PackedScene
	if folk_scene != null:
		var folk := folk_scene.instantiate()
		var spr := folk.get_node_or_null("Sprite2D") as Sprite2D
		if _is_townsfolk(folk) and spr != null and spr.hframes == 4 and spr.vframes == 8:
			_ok("Townsfolk scene uses the 4x8 directional walk sheet")
		else:
			_err("Townsfolk scene is missing its walk-sheet Sprite2D (4x8)")
		folk.free()
	else:
		_err("townsfolk.tscn failed to load")

	# --- 2. The crowd spawner fills its parent -----------------------------
	var root := Node2D.new()
	get_root().add_child(root)
	for i in 3:
		var m := Marker2D.new()
		m.position = Vector2(i * 40, 0)
		m.add_to_group("test_stroll")
		root.add_child(m)
	var host := Node2D.new()
	host.y_sort_enabled = true
	root.add_child(host)

	var crowd_scene := load("res://scenes/entities/townsfolk_crowd.tscn") as PackedScene
	if crowd_scene != null:
		var crowd := crowd_scene.instantiate()
		crowd.set("count", 4)
		crowd.set("stroll_group", &"test_stroll")
		host.add_child(crowd)
		await process_frame
		await process_frame
		var spawned := 0
		var on_point := 0
		for c in host.get_children():
			if _is_townsfolk(c):
				spawned += 1
				if absf((c as Node2D).global_position.x - roundf((c as Node2D).global_position.x / 40.0) * 40.0) < 0.01:
					on_point += 1
		if spawned == 4:
			_ok("TownsfolkCrowd spawns its count into the parent (y-sort host)")
		else:
			_err("TownsfolkCrowd spawned %d, expected 4" % spawned)
		if on_point == 4:
			_ok("pedestrians are placed on stroll waypoints")
		else:
			_err("pedestrians not placed on waypoints (%d/4)" % on_point)
	else:
		_err("townsfolk_crowd.tscn failed to load")
	root.queue_free()

	# --- 3. Chimney smoke exists + is on the hearth buildings --------------
	var smoke := load("res://scenes/entities/props/chimney_smoke.tscn") as PackedScene
	if smoke != null:
		var inst := smoke.instantiate()
		if inst is CPUParticles2D:
			_ok("chimney_smoke.tscn is a particle effect")
		else:
			_err("chimney_smoke.tscn is not CPUParticles2D")
		inst.free()
	else:
		_err("chimney_smoke.tscn failed to load")
	var smoke_path := "res://scenes/entities/props/chimney_smoke.tscn"
	for b in ["townhouse", "tavern", "blacksmith", "cabin"]:
		var txt := FileAccess.get_file_as_string("res://scenes/entities/props/%s.tscn" % b)
		if txt.contains(smoke_path):
			_ok("%s has a smoking chimney" % b)
		else:
			_err("%s is missing chimney smoke" % b)

	# --- 4. The town carries a crowd ---------------------------------------
	var town := FileAccess.get_file_as_string("res://scenes/world/town.tscn")
	if town.contains("townsfolk_crowd.tscn") and town.contains("TownsfolkCrowd"):
		_ok("Cleeve's Landing is populated with a strolling crowd")
	else:
		_err("town.tscn has no TownsfolkCrowd")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - the town bustles: a strolling crowd and smoking chimneys")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
