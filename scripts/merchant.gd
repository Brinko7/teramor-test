extends Area2D

## A trader. Implements the shared INTERACT contract (collision layer 32, the
## "interactable" group, plus `interact(player)`). Interacting **during business
## hours** opens the global ShopUI with this merchant's wares; outside hours the
## keeper is off the clock — a red "closed" card shows on the counter and the
## trade is politely refused. Stock is authored per-instance in the editor as an
## Array[Item], so new shops need no new code.

@export var shop_name: String = "Trader"
@export var stock: Array[Item] = []
@export var sprite_tint: Color = Color(1, 1, 1, 1)

## Business hours on the 24h clock: trading is allowed while
## `open_hour <= hour < close_hour`. The counter status card flips with these,
## and `hour_changed` keeps it live if the player lingers past closing.
@export var open_hour: int = 8
@export var close_hour: int = 18
@export_multiline var closed_line: String = "We're shut for now — the post opens at first light and closes by dusk. Come back then."
## Optional OPEN/CLOSED placard (a Sprite2D using shop_sign.png, hframes=2). Kept
## a sibling rather than a child so it y-sorts to the counter front instead of
## inheriting the keeper's depth behind it.
@export var status_sign_path: NodePath

@onready var _sprite: Sprite2D = $Sprite2D
var _sign: Sprite2D = null

func _ready() -> void:
	add_to_group("interactable")
	if _sprite != null:
		_sprite.modulate = sprite_tint
	if not status_sign_path.is_empty():
		_sign = get_node_or_null(status_sign_path) as Sprite2D
	TimeManager.hour_changed.connect(_on_hour_changed)
	_refresh()

func _on_hour_changed(_hour: int) -> void:
	_refresh()

## Within posted business hours?
func is_open() -> bool:
	var h: int = TimeManager.get_hour()
	return h >= open_hour and h < close_hour

## Flip the counter card to match the clock (frame 0 = open/green, 1 = closed/red).
func _refresh() -> void:
	if _sign != null:
		_sign.frame = 0 if is_open() else 1

## Called by the player when interacted with.
func interact(_player) -> void:
	if not is_open():
		UIManager.dialogue.start(PackedStringArray([closed_line]), shop_name)
		return
	UIManager.shop.open(stock, shop_name)
