extends SceneTree

## Headless smoke test for the cozy-tools + fishing pass: the new tool/fish items
## load, farming works as tool verbs (hoe tills, seed plants, can waters), gather
## nodes are tool-gated (axe vs pickaxe), and a fishing spot yields a fish.
##
## Run: godot --headless -s tools/validate_tools.gd
## (load() after awaits, real player instance for realistic Inventory plumbing.)

const TOOLS := {
	"pickaxe": "res://resources/items/tools/pickaxe.tres",
	"axe": "res://resources/items/tools/axe.tres",
	"fishing_rod": "res://resources/items/tools/fishing_rod.tres",
}
const FISH := ["res://resources/items/river_fish.tres", "res://resources/items/lake_bass.tres"]

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	# 1) Tool + fish items load with the right shape.
	for kind in TOOLS:
		var t = load(TOOLS[kind])
		if t == null or String(t.get("tool_kind")) != kind:
			_err("tool item %s missing or wrong tool_kind" % kind)
	for path in FISH:
		if load(path) == null:
			_err("fish item failed to load: %s" % path)

	# Access autoloads via /root, never the global name — the latter isn't
	# registered when this -s script compiles (frame-0 trap).
	var fm = get_root().get_node_or_null("FarmManager")
	if fm == null:
		_err("FarmManager autoload missing")
		_finish()
		return

	var player = load("res://scenes/entities/player.tscn").instantiate()
	get_root().add_child(player)
	await process_frame
	await process_frame

	# 2) Farming as tool verbs: hoe tills, seed plants, watering can waters.
	var plot = load("res://scenes/entities/props/farm_plot.tscn").instantiate()
	get_root().add_child(plot)
	await process_frame
	var pid: String = plot.plot_id
	if plot.use_tool(&"watering_can", player):
		_err("watering bare ground should do nothing")
	if not plot.use_tool(&"hoe", player) or not fm.is_tilled(pid):
		_err("hoe did not till bare ground")
	var seed = load("res://resources/items/seeds/turnip_seeds.tres")
	if seed == null or not plot.try_plant(seed.crop, player) or not fm.has_crop(pid):
		_err("seed did not plant on tilled soil")
	if not plot.use_tool(&"watering_can", player) or not fm.is_watered(pid):
		_err("watering can did not water the planted crop")

	# 3) Gather nodes are tool-gated: wood wants an axe, not a pickaxe.
	var node = load("res://scenes/entities/gather_node.tscn").instantiate()
	get_root().add_child(node)
	node.configure(load("res://resources/items/wood.tres"), 2, Color.WHITE, &"axe")
	await process_frame
	if node.use_tool(&"pickaxe", player):
		_err("a pickaxe should not fell a wood node")
	var q0: int = node.quantity
	if not node.use_tool(&"axe", player):
		_err("an axe should fell a wood node")
	if node.quantity >= q0:
		_err("chopping did not deplete the wood node")

	# 4) Fishing yields a fish into the bag.
	var spot = load("res://scenes/entities/fishing_spot.tscn").instantiate()
	get_root().add_child(spot)
	await process_frame
	if not spot.use_tool(&"fishing_rod", player):
		_err("fishing rod did not start a cast")
	var inv = player.get_node_or_null("Inventory")
	var before: int = _fish_count(inv)
	spot._resolve_catch(player)
	if _fish_count(inv) <= before:
		_err("fishing did not add a fish to the bag")

	player.queue_free()
	plot.queue_free()
	node.queue_free()
	spot.queue_free()
	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - cozy tools: farm verbs, tool-gated gather, fishing all work")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()

func _fish_count(inv) -> int:
	if inv == null:
		return 0
	return inv.count_of(&"river_fish") + inv.count_of(&"lake_bass")
