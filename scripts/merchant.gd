extends Area2D

## A trader. Implements the shared INTERACT contract (collision layer 32, the
## "interactable" group, plus `interact(player)`). Interacting opens the global
## ShopUI with this merchant's wares; the player buys stock at full value and
## sells from their bag at a fraction. Stock is authored per-instance in the
## editor as an Array[Item], so new shops need no new code.

@export var shop_name: String = "Trader"
@export var stock: Array[Item] = []
@export var sprite_tint: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	add_to_group("interactable")
	var sprite := $Sprite2D as Sprite2D
	if sprite != null:
		sprite.modulate = sprite_tint

## Called by the player when interacted with.
func interact(_player) -> void:
	ShopUI.open(stock, shop_name)
