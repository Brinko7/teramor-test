extends SceneTree

## Headless check for the ambient animals (living cities, pt.2):
##   1. The Critter script + the chicken/dog/bird scenes are well-formed (4x4 sheet).
##   2. A skittish flyer (bird) FLUSHES — flees the player and takes wing (vanishes)
##      when they come within flush_radius.
##   3. A skittish ground critter (chicken) scurries away but does NOT vanish.
##   4. The camp has chickens; the town has a dog and a flock of birds.
##
## Movement is driven by calling _process with a fixed delta (headless idle frames
## have near-zero delta, which would never accumulate motion).
##
## Run: godot --headless -s tools/validate_critters.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _is_critter(node: Node) -> bool:
	var s := node.get_script() as Script
	return s != null and s.resource_path.ends_with("critter.gd")

func _spawn(scene_path: String, at: Vector2, player: Node2D) -> Node2D:
	var scn := load(scene_path) as PackedScene
	var c := scn.instantiate() as Node2D
	get_root().add_child(c)
	c.global_position = at
	return c

func _run() -> void:
	await process_frame
	await process_frame

	# --- 1. Scenes are well-formed -----------------------------------------
	for pair in [["chicken", "res://scenes/entities/chicken.tscn"],
			["dog", "res://scenes/entities/dog.tscn"],
			["bird", "res://scenes/entities/bird.tscn"]]:
		var scn := load(pair[1]) as PackedScene
		if scn == null:
			_err("%s scene failed to load" % pair[0])
			continue
		var inst := scn.instantiate()
		var spr := inst.get_node_or_null("Sprite2D") as Sprite2D
		if _is_critter(inst) and spr != null and spr.hframes == 4 and spr.vframes == 4:
			_ok("%s uses the 4x4 animal sheet" % pair[0])
		else:
			_err("%s is malformed (need Critter + 4x4 Sprite2D)" % pair[0])
		inst.free()

	# --- 2 & 3. Flush + scurry behaviour -----------------------------------
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2.ZERO
	get_root().add_child(player)
	await process_frame   # let critters' _ready run after they are added below

	var bird := _spawn("res://scenes/entities/bird.tscn", Vector2(12, 0), player)
	var chicken := _spawn("res://scenes/entities/chicken.tscn", Vector2(10, 0), player)
	await process_frame
	bird.set_process(false)
	chicken.set_process(false)

	var chick_start: float = chicken.global_position.distance_to(player.global_position)
	for i in 18:
		bird._process(0.1)
		chicken._process(0.1)
	var chick_end: float = chicken.global_position.distance_to(player.global_position)

	if not bird.visible:
		_ok("the bird flushes — flees and takes wing when you get close")
	else:
		_err("bird did not flush within range")
	if chick_end > chick_start + 8.0 and chicken.visible:
		_ok("the chicken scurries away but stays grounded")
	else:
		_err("chicken did not scurry from the player (start %.1f end %.1f)" % [chick_start, chick_end])

	# --- 4. Critters are placed in the world -------------------------------
	var camp := FileAccess.get_file_as_string("res://scenes/world/settlement.tscn")
	if camp.contains("chicken.tscn"):
		_ok("the camp keeps chickens")
	else:
		_err("settlement.tscn has no chickens")
	var town := FileAccess.get_file_as_string("res://scenes/world/town.tscn")
	if town.contains("dog.tscn") and town.contains("bird.tscn"):
		_ok("Cleeve's Landing has a dog and a flock of birds")
	else:
		_err("town.tscn is missing the dog or the birds")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - the world has animals: pecking hens, an ambling dog, birds that flush")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
