extends Area2D
class_name GatherNode

## A harvestable resource node — an ore vein, crystal cluster or herb bush. Press
## interact to collect one `yield_item`; it depletes after `quantity` harvests and
## goes inert. The mining/foraging analogue of a farm plot. The area generator
## scatters these from a biome's gather list; instances can also be hand-placed.

const PICKUP_SCENE := preload("res://scenes/entities/item_pickup.tscn")

@export var yield_item: Item
@export var quantity: int = 3
## The tool needed to work this node: &"pickaxe" for ore/stone/crystal veins,
## &"axe" for wood. Blank means hand-gatherable (herbs/forage — press E).
@export var required_tool: StringName = &""

var _depleted: bool = false

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	add_to_group("interactable")

func configure(item: Item, qty: int, tint: Color = Color.WHITE, tool: StringName = &"") -> void:
	yield_item = item
	quantity = qty
	required_tool = tool
	if _sprite != null:
		_sprite.modulate = tint

## Tool contract (F with a tool selected): only the right tool works a gated vein.
func use_tool(kind: StringName, player: Node) -> bool:
	if required_tool != &"" and kind != required_tool:
		return false
	return _harvest_one(player)

## Interact contract (E): hand-gatherable nodes only; gated veins need their tool.
func interact(player: Node) -> void:
	if required_tool != &"":
		return
	_harvest_one(player)

## Take one yield to the bag (drop it if the bag is full). Returns whether anything
## was harvested.
func _harvest_one(player: Node) -> bool:
	if _depleted or quantity <= 0 or yield_item == null:
		return false
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return false
	# Add to the bag; if it's full, drop the harvest at our feet instead.
	if inv.add_item(yield_item, 1) > 0:
		var pickup := PICKUP_SCENE.instantiate() as ItemPickup
		pickup.configure(yield_item, 1)
		pickup.global_position = global_position + Vector2(0, 6)
		get_parent().add_child(pickup)
	quantity -= 1
	_strike_flash()
	if quantity <= 0:
		_deplete()
	return true

func _strike_flash() -> void:
	if _sprite == null:
		return
	var base: Color = _sprite.modulate
	_sprite.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", base, 0.15)

func _deplete() -> void:
	_depleted = true
	if _sprite != null:
		_sprite.modulate = Color(0.4, 0.4, 0.4)
		_sprite.scale = Vector2(0.7, 0.7)
	set_deferred("monitoring", false)
