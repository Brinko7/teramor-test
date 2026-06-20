extends StaticBody2D
class_name ChoppableTree

## A tree that can be felled with the axe for wood. Default choppable; the area
## generator marks **border** trees `choppable = false` so chopping can't breach the
## frame. Uses the proximity tool contract (`use_tool`) — no Area2D needed, the
## player's tool search scans the "interactable" group by position. Hand-pickable
## interaction (E) is intentionally not offered; a tree wants the axe.

const WOOD := preload("res://resources/items/wood.tres")
const PICKUP_SCENE := preload("res://scenes/entities/item_pickup.tscn")

@export var choppable: bool = true
@export var wood_yield: int = 2

var _chopped: bool = false

func _ready() -> void:
	if choppable:
		add_to_group("interactable")

## Tool contract: only the axe fells a tree, once.
func use_tool(kind: StringName, player: Node) -> bool:
	if _chopped or not choppable or kind != &"axe":
		return false
	_chopped = true
	remove_from_group("interactable")
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	for i in wood_yield:
		_drop_wood(inv)
	_fell()
	return true

func _drop_wood(inv: Inventory) -> void:
	# Into the bag first; if it's full, drop a log at the stump.
	if inv != null and inv.add_item(WOOD, 1) == 0:
		return
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	pickup.configure(WOOD, 1)
	pickup.global_position = global_position + Vector2(randf_range(-8.0, 8.0), 6.0)
	get_parent().call_deferred("add_child", pickup)

## Topple and fade, then free — collision off immediately so it stops blocking.
func _fell() -> void:
	var col := get_node_or_null("CollisionShape2D")
	if col != null:
		col.set_deferred("disabled", true)
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null:
		var topple: float = deg_to_rad(78.0) * (1.0 if randf() < 0.5 else -1.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(spr, "rotation", topple, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(spr, "modulate:a", 0.0, 0.65)
	get_tree().create_timer(0.75).timeout.connect(queue_free)
