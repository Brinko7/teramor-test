extends Area2D

## A one-time loot chest scattered through generated wild areas (or hand-placed).
## Interacting grants its contents to the player's bag — anything that doesn't fit
## spills out as pickups — then the chest reads as opened and goes inert. The area
## generator fills it via configure(); a placed instance can author `loot` directly.

const PICKUP_SCENE := preload("res://scenes/entities/item_pickup.tscn")

@export var loot: Array[Item] = []

var _opened: bool = false

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	add_to_group("interactable")

func configure(items: Array) -> void:
	loot = []
	for it: Variant in items:
		if it is Item:
			loot.append(it)

func interact(player: Node) -> void:
	if _opened:
		return
	_opened = true
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	var granted: int = 0
	for it: Item in loot:
		if it == null:
			continue
		granted += 1
		var overflow: int = inv.add_item(it, 1) if inv != null else 1
		if overflow > 0:
			var pickup := PICKUP_SCENE.instantiate() as ItemPickup
			pickup.configure(it, overflow)
			pickup.global_position = global_position + Vector2(0, 6)
			get_parent().add_child(pickup)
	UIManager.notify("Treasure", "You found %d item(s)." % granted)
	if _sprite != null:
		_sprite.modulate = Color(0.55, 0.55, 0.55)  # opened
	set_deferred("monitoring", false)
