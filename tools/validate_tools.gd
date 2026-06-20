extends SceneTree

## Headless smoke test for the cozy-tools + fishing pass and its targeting fix.
## Exercises the REAL F-press path end to end: select a tool/seed on the hotbar,
## stand next to a plot, and `_use_held_on_facing()` — proximity targeting, no
## mouse-aim needed. Plus tool-gated gather, choppable trees, and fishing.
##
## Run: godot --headless -s tools/validate_tools.gd
## (load() after awaits, autoloads via /root — frame-0-trap-safe.)

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _select_tool(player, kind: StringName) -> bool:
	var inv = player.get_node("Inventory")
	var hb = player.get_node("ItemHotbar")
	for i in range(10):
		var it = inv.get_item(i)
		if it is ToolItem and (it as ToolItem).tool_kind == kind:
			hb.select(i)
			return true
	return false

func _select_seed(player) -> bool:
	var inv = player.get_node("Inventory")
	var hb = player.get_node("ItemHotbar")
	for i in range(10):
		if inv.get_item(i) is SeedItem:
			hb.select(i)
			return true
	return false

func _run() -> void:
	await process_frame
	await process_frame
	var fm = get_root().get_node_or_null("FarmManager")
	if fm == null:
		_err("FarmManager autoload missing")
		_finish()
		return

	# Items load with the right shape.
	for kind in ["pickaxe", "axe", "fishing_rod"]:
		var t = load("res://resources/items/tools/%s.tres" % kind)
		if t == null or String(t.get("tool_kind")) != kind:
			_err("tool item %s missing/wrong tool_kind" % kind)

	var player = load("res://scenes/entities/player.tscn").instantiate()
	get_root().add_child(player)
	player.global_position = Vector2.ZERO
	await process_frame
	await process_frame

	# --- The bug fix: F farms a NEARBY plot by proximity (no precise mouse aim) ---
	var plot = load("res://scenes/entities/props/farm_plot.tscn").instantiate()
	get_root().add_child(plot)
	plot.global_position = Vector2(16, 0)  # within TOOL_REACH, not under the cursor
	await process_frame
	await process_frame
	var pid: String = plot.plot_id

	if not _select_tool(player, &"hoe"):
		_err("hoe not found on the hotbar")
	player._use_held_on_facing()
	if not fm.is_tilled(pid):
		_err("F + hoe did not till a nearby plot (proximity dispatch broken)")

	if not _select_seed(player):
		_err("seed not found on the hotbar")
	player._use_held_on_facing()
	if not fm.has_crop(pid):
		_err("F + seed did not plant on the tilled plot")

	if not _select_tool(player, &"watering_can"):
		_err("watering can not found on the hotbar")
	player._use_held_on_facing()
	if not fm.is_watered(pid):
		_err("F + watering can did not water the crop")

	# --- Gather nodes are tool-gated: an ore vein wants a pickaxe ---
	var vein = load("res://scenes/entities/gather_node.tscn").instantiate()
	get_root().add_child(vein)
	vein.global_position = Vector2(400, 0)
	vein.configure(load("res://resources/items/stone.tres"), 2, Color.WHITE, &"pickaxe")
	await process_frame
	if vein.use_tool(&"axe", player):
		_err("an axe should not work a stone vein")
	var q0: int = vein.quantity
	if not vein.use_tool(&"pickaxe", player) or vein.quantity >= q0:
		_err("a pickaxe should mine a stone vein")

	# --- Trees are choppable with the axe, for wood ---
	var tree = load("res://scenes/entities/props/tree.tscn").instantiate()
	get_root().add_child(tree)
	tree.global_position = Vector2(600, 0)
	await process_frame
	if not tree.is_in_group("interactable"):
		_err("a choppable tree should be an interactable")
	var inv = player.get_node("Inventory")
	var wood_before: int = inv.count_of(&"wood")
	if not tree.use_tool(&"axe", player):
		_err("the axe did not fell the tree")
	if inv.count_of(&"wood") <= wood_before:
		_err("felling the tree yielded no wood")

	# --- Fishing yields a fish ---
	var spot = load("res://scenes/entities/fishing_spot.tscn").instantiate()
	get_root().add_child(spot)
	spot.global_position = Vector2(800, 0)
	await process_frame
	var fish_before: int = inv.count_of(&"river_fish") + inv.count_of(&"lake_bass")
	spot._resolve_catch(player)
	if inv.count_of(&"river_fish") + inv.count_of(&"lake_bass") <= fish_before:
		_err("fishing did not add a fish to the bag")

	player.queue_free()
	plot.queue_free()
	vein.queue_free()
	spot.queue_free()
	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - tools: proximity F-dispatch farms, tool-gated gather, choppable trees, fishing")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
