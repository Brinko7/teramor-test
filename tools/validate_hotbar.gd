extends SceneTree

## Headless validation for the item hotbar + Q ability radial (task #32/#43). Run:
##   godot --headless --path <project> -s res://tools/validate_hotbar.gd
##
## Asserts the whole control scheme hangs together off-tree:
##   * every input action the scheme relies on is mapped (hotbar 1-0, wheel
##     cycle, use, the Q radial gate, and the four ability casts);
##   * the player's ItemHotbar controller selects/clamps/wraps and that
##     use_active() spends a consumable and decrements the bag;
##   * the bottom-centre HUD finds the player's bag + hotbar and binds to them;
##   * the Q ability radial starts hidden (it is only shown while Q is held).

const PLAYER := "res://scenes/entities/player.tscn"
const HUD := "res://scenes/ui/item_hotbar.tscn"
const RADIAL := "res://scenes/ui/ability_hotbar.tscn"
const POTION := "res://resources/items/health_potion.tres"

const REQUIRED_ACTIONS := [
	"hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
	"hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_10",
	"hotbar_prev", "hotbar_next", "use_item",
	"ability_menu", "ability_1", "ability_2", "ability_3", "ability_4",
]

var _fail := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== hotbar validation ===")
	_check_actions()

	var player := _instance(PLAYER)
	if player == null:
		_done()
		return
	root.add_child(player)
	await process_frame

	var hotbar := player.get_node_or_null("ItemHotbar")
	var inv := player.get_node_or_null("Inventory")
	if hotbar == null:
		_err("player has no ItemHotbar child")
	if inv == null:
		_err("player has no Inventory child")
	if hotbar != null and inv != null:
		_check_controller(hotbar, inv, player)

	await _check_hud(player)
	await _check_radial()

	_done()

## --- input map --------------------------------------------------------------

func _check_actions() -> void:
	for action in REQUIRED_ACTIONS:
		if InputMap.has_action(action):
			print("  [ok] action %s mapped" % action)
		else:
			_err("input action missing: %s" % action)

## --- ItemHotbar controller --------------------------------------------------

func _check_controller(hotbar: Node, inv: Node, player: Node) -> void:
	var size: int = int(hotbar.get("SIZE"))
	if size != 10:
		_err("ItemHotbar.SIZE = %d, want 10" % size)

	hotbar.call("select", 3)
	_eq(int(hotbar.get("selected")), 3, "select(3)")
	hotbar.call("select", 99)
	_eq(int(hotbar.get("selected")), size - 1, "select(99) clamps high")
	hotbar.call("select", -5)
	_eq(int(hotbar.get("selected")), 0, "select(-5) clamps low")

	hotbar.call("cycle", 1)
	_eq(int(hotbar.get("selected")), 1, "cycle(+1) from 0")
	hotbar.call("select", 0)
	hotbar.call("cycle", -1)
	_eq(int(hotbar.get("selected")), size - 1, "cycle(-1) wraps to last")

	# Spend a consumable from the active slot and confirm the bag drops one.
	var potion := load(POTION) as Item
	if potion == null:
		_err("cannot load %s" % POTION)
		return
	inv.set("announce_collection", false)  # keep the Events/quest bus out of it
	inv.call("load_state", {"slots": []})  # clear the starting kit for a clean slot 0
	inv.call("add_item", potion, 2)
	hotbar.call("select", 0)
	_eq(int(inv.call("get_count", 0)), 2, "bag seeded with 2 potions")

	var used: bool = hotbar.call("use_active", player)
	if not used:
		_err("use_active() returned false on a consumable in the active slot")
	_eq(int(inv.call("get_count", 0)), 1, "use_active() decremented the stack")

	# Empty active slot must be a no-op.
	hotbar.call("select", 5)
	if bool(hotbar.call("use_active", player)):
		_err("use_active() on an empty slot returned true")
	else:
		print("  [ok] use_active() on empty slot is a no-op")

## --- HUD binding ------------------------------------------------------------

func _check_hud(player: Node) -> void:
	var hud := _instance(HUD)
	if hud == null:
		return
	root.add_child(hud)
	# _try_connect binds immediately if the player is already grouped; give it a
	# couple of its 0.2s retry windows just in case.
	await process_frame
	await create_timer(0.5).timeout

	var bound_inv = hud.get("_inv")
	var bound_hotbar = hud.get("_hotbar")
	if bound_inv == null or bound_hotbar == null:
		_err("item hotbar HUD did not bind to the player's bag/hotbar")
	elif bound_hotbar != player.get_node_or_null("ItemHotbar"):
		_err("HUD bound to the wrong ItemHotbar")
	else:
		print("  [ok] HUD bound to the player's bag + hotbar")

## --- Q ability radial -------------------------------------------------------

func _check_radial() -> void:
	var radial := _instance(RADIAL)
	if radial == null:
		return
	root.add_child(radial)
	await process_frame
	await process_frame  # let _process run with no input held

	var ring = radial.get("_root")
	if ring == null:
		_err("ability radial built no _root control")
	elif bool(ring.visible):
		_err("ability radial is visible with Q not held (should be hidden)")
	else:
		print("  [ok] ability radial hidden until Q is held")

## --- helpers ----------------------------------------------------------------

func _instance(path: String) -> Node:
	var ps := load(path) as PackedScene
	if ps == null:
		_err("cannot load %s" % path)
		return null
	return ps.instantiate()

func _eq(got: int, want: int, what: String) -> void:
	if got == want:
		print("  [ok] %s -> %d" % [what, got])
	else:
		_err("%s = %d, want %d" % [what, got, want])

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _done() -> void:
	if _fail == 0:
		print("\nRESULT: PASS — hotbar controller, HUD binding, radial gating all hold")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)
