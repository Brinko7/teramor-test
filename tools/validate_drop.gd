extends SceneTree

## Validates the inventory item-drop (#52): the edited scripts compile, and a
## dropped stack round-trips through a world ItemPickup back into an Inventory —
## i.e. "right-click to drop and clear space, walk back over it to recover" works.
##
## Loads after awaiting frames so class_name/autoload deps resolve.

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _run() -> void:
	await process_frame
	await process_frame

	# 1) the scripts touched this session compile cleanly.
	for path in [
		"res://scripts/ui/player_menu.gd",
		"res://scripts/npc.gd",
		"res://scripts/transition_zone.gd",
		"res://scripts/autoload/scene_manager.gd",
		"res://scripts/world/procedural_area.gd",
	]:
		if load(path) == null:
			_err("failed to compile %s" % path)

	# 2) drop -> ground pickup -> recovered into the bag.
	var item := load("res://resources/items/raw_meat.tres") as Item
	if item == null:
		_err("missing test item raw_meat.tres")
		_done()
		return
	var player := Node2D.new()
	player.add_to_group("player")
	var inv = load("res://scripts/inventory.gd").new()
	inv.name = "Inventory"
	inv.announce_collection = false  # avoid the Events autoload in this bare tool
	player.add_child(inv)
	get_root().add_child(player)
	await process_frame  # inv._ready resizes slots

	var pickup = load("res://scenes/entities/item_pickup.tscn").instantiate()
	pickup.configure(item, 5)
	get_root().add_child(pickup)
	await process_frame

	pickup._on_body_entered(player)  # simulate walking onto the dropped stack
	var got: int = inv.count_of(item.id)
	if got != 5:
		_err("dropped stack did not return to the bag (got %d/5)" % got)

	_done()

func _done() -> void:
	if _fail == 0:
		print("RESULT: PASS - edited scripts compile; dropped stack recovers into the bag")
	else:
		print("RESULT: FAIL - %d issue(s)" % _fail)
	quit()
