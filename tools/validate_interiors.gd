extends SceneTree

## Headless smoke test for the enterable interiors (task #28). Run with:
##   godot --headless --path <project> -s res://tools/validate_interiors.gd
## Loads + instantiates the shop/tavern interiors and the edited town, then
## asserts the wiring that makes "walk in / walk out" work: the merchant moved
## into the shop, Bram + the contract board moved into the tavern, both interiors
## have a `from_town` spawn and an ExitDoor back to town, and town gained a door
## to each plus matching return spawns. Runs ON-tree so _ready() fires.

const SHOP := "res://scenes/world/shop_interior.tscn"
const TAVERN := "res://scenes/world/tavern_interior.tscn"
const TOWN := "res://scenes/world/town.tscn"

var _fail := 0

func _initialize() -> void:
	print("=== interiors validation ===")
	_check_loads([SHOP, TAVERN, TOWN, "res://scenes/world/cabin_interior.tscn"])
	_check_shop()
	_check_tavern()
	_check_town()
	if _fail == 0:
		print("\nRESULT: PASS — interiors wire up cleanly")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _check_loads(paths: Array) -> void:
	print("\n[load] parse + instantiability")
	for path in paths:
		if not ResourceLoader.exists(path):
			_err("missing scene: " + path)
			continue
		var ps := load(path) as PackedScene
		if ps == null or not ps.can_instantiate():
			_err("cannot instantiate: " + path)
		else:
			print("  [ok] " + path)

## Instantiate a scene on-tree (so _ready fires with autoloads present), hand it
## to a callback for assertions, then tear it down.
func _with_scene(path: String, fn: Callable) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		_err("load failed: " + path)
		return
	var inst := ps.instantiate()
	root.add_child(inst)
	fn.call(inst)
	inst.queue_free()

func _find(node: Node, pred: Callable) -> Node:
	if pred.call(node):
		return node
	for c in node.get_children():
		var hit := _find(c, pred)
		if hit != null:
			return hit
	return null

func _find_named(node: Node, wanted: String) -> Node:
	return _find(node, func(n): return n.name == wanted)

func _check_shop() -> void:
	print("\n[shop] merchant inside + exit home")
	_with_scene(SHOP, func(scene):
		var merch := _find(scene, func(n): return n.get("shop_name") != null and String(n.get("shop_name")) == "Cleeve's Trading Post")
		if merch == null:
			_err("shop: merchant with the trading-post stock not found inside")
		elif int((merch.get("stock") as Array).size()) < 6:
			_err("shop: merchant stock looks empty")
		_assert_spawn_and_exit(scene, "shop", "res://scenes/world/town.tscn", "to_shop")
	)

func _check_tavern() -> void:
	print("\n[tavern] keeper + board inside + exit home")
	_with_scene(TAVERN, func(scene):
		var bram := _find(scene, func(n): return n.get("speaker_name") != null and String(n.get("speaker_name")).begins_with("Bram"))
		if bram == null:
			_err("tavern: Bram the keeper not found inside")
		elif bram.get("offered_quest") == null:
			_err("tavern: Bram is missing his offered quest (find_elkar)")
		var board := _find(scene, func(n): return n.get("board_title") != null and String(n.get("board_title")).contains("Drowned Stag"))
		if board == null:
			_err("tavern: the bounty board did not move inside")
		_assert_spawn_and_exit(scene, "tavern", "res://scenes/world/town.tscn", "to_tavern")
	)

## Each interior needs a `from_town` spawn (where you land) and an ExitDoor
## transition zone pointing back to town's matching return marker.
func _assert_spawn_and_exit(scene: Node, tag: String, want_scene: String, want_spawn: String) -> void:
	var spawn := _find_named(scene, "from_town")
	if spawn == null or not (spawn is Marker2D):
		_err("%s: no `from_town` spawn marker" % tag)
	var door := _find_named(scene, "ExitDoor")
	if door == null:
		_err("%s: no ExitDoor" % tag)
		return
	if String(door.get("target_scene")) != want_scene:
		_err("%s: ExitDoor target_scene is '%s' (want %s)" % [tag, String(door.get("target_scene")), want_scene])
	if String(door.get("target_spawn")) != want_spawn:
		_err("%s: ExitDoor target_spawn is '%s' (want %s)" % [tag, String(door.get("target_spawn")), want_spawn])

func _check_town() -> void:
	print("\n[town] doors + return spawns, NPCs moved out")
	_with_scene(TOWN, func(scene):
		# Doors into each interior.
		var doors := {
			"ShopDoor": "res://scenes/world/shop_interior.tscn",
			"TavernDoor": "res://scenes/world/tavern_interior.tscn",
		}
		for dname in doors:
			var d := _find_named(scene, dname)
			if d == null:
				_err("town: missing %s" % dname)
			elif String(d.get("target_scene")) != doors[dname]:
				_err("town: %s targets '%s'" % [dname, String(d.get("target_scene"))])
			elif String(d.get("target_spawn")) != "from_town":
				_err("town: %s should spawn at from_town" % dname)
		# Return spawns for coming back out.
		for sname in ["to_shop", "to_tavern"]:
			if _find_named(scene, sname) == null:
				_err("town: missing return spawn '%s'" % sname)
		# The merchant/keeper/board should no longer stand in the plaza.
		if _find(scene, func(n): return n.get("shop_name") != null) != null:
			_err("town: a merchant is still standing outside (should be inside the shop)")
		if _find(scene, func(n): return n.get("board_title") != null) != null:
			_err("town: the bounty board is still outside (should be inside the tavern)")
	)
