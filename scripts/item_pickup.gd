extends Area2D
class_name ItemPickup

## A world-droppable item. When the player walks over it, the item is added to
## their Inventory and the pickup despawns. Set `item`/`count` before adding to
## the tree, or call configure().

@export var item: Item
@export var count: int = 1

@onready var _sprite: Sprite2D = $Sprite2D

func configure(new_item: Item, new_count: int = 1) -> void:
	item = new_item
	count = new_count
	if is_inside_tree():
		_refresh_icon()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_icon()

func _refresh_icon() -> void:
	if item != null and item.icon != null:
		_sprite.texture = item.icon

func _on_body_entered(body: Node) -> void:
	if item == null or not body.is_in_group("player"):
		return
	var inv: Inventory = body.get_node_or_null("Inventory")
	if inv == null:
		return
	var leftover: int = inv.add_item(item, count)
	if leftover <= 0:
		queue_free()
	else:
		count = leftover
