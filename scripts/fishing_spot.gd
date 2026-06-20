extends Area2D
class_name FishingSpot

## A fishable patch of water — dropped at pond features by the area generator (and
## hand-placeable). Face it with the **fishing rod** selected and use it (F), or walk
## up and interact (E) while carrying a rod: a short cast resolves into a random catch
## from `catch_table`, added to your bag. The relaxing end of the gather loop.
##
## Implements the shared tool contract (`use_tool(kind, player)`) and the interact
## contract, both on collision layer 32 / the "interactable" group.

## Fish (Items) this spot can yield. Authored on the scene; the generator may override.
@export var catch_table: Array[Item] = []
## Seconds the line is out before a catch resolves.
@export var cast_time: float = 1.1

var _busy: bool = false

func _ready() -> void:
	add_to_group("interactable")

func configure(table: Array[Item]) -> void:
	if not table.is_empty():
		catch_table = table

## Tool contract: only the fishing rod works, and not while a line is already out.
func use_tool(kind: StringName, player: Node) -> bool:
	if kind != &"fishing_rod" or _busy:
		return false
	_cast(player)
	return true

## Interact contract: cast if the player is carrying a rod, so you can fish without
## first selecting it on the hotbar.
func interact(player: Node) -> void:
	if _busy:
		return
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	if inv != null and inv.count_of(&"fishing_rod") > 0:
		_cast(player)

func _cast(player: Node) -> void:
	_busy = true
	Events.tool_used.emit(&"cast", global_position)
	get_tree().create_timer(maxf(0.1, cast_time)).timeout.connect(_resolve_catch.bind(player))

## Pull in a random fish (also callable directly by tests). Adds it to the bag, or
## drops it at the spot if the bag is full.
func _resolve_catch(player: Node) -> void:
	_busy = false
	if catch_table.is_empty() or player == null or not is_instance_valid(player):
		return
	var fish: Item = catch_table[randi() % catch_table.size()]
	if fish == null:
		return
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	if inv != null:
		inv.add_item(fish, 1)
	Events.tool_used.emit(&"reel", global_position)
	if Engine.is_editor_hint() == false and has_node("/root/UIManager"):
		UIManager.notify("Caught a %s" % fish.name, "")
