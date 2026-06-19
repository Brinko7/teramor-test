extends Area2D
class_name GatherNode

## A harvestable resource node — an ore vein, crystal cluster or herb bush. Press
## interact to collect one `yield_item`; it depletes after `quantity` harvests and
## goes inert. The mining/foraging analogue of a farm plot. The area generator
## scatters these from a biome's gather list; instances can also be hand-placed.

const PICKUP_SCENE := preload("res://scenes/entities/item_pickup.tscn")

@export var yield_item: Item
@export var quantity: int = 3

var _depleted: bool = false

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	add_to_group("interactable")

func configure(item: Item, qty: int, tint: Color = Color.WHITE) -> void:
	yield_item = item
	quantity = qty
	if _sprite != null:
		_sprite.modulate = tint

func interact(player: Node) -> void:
	if _depleted or quantity <= 0 or yield_item == null:
		return
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return
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
