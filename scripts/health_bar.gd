extends CanvasLayer

## HUD health bar. Finds the player on _ready, connects to its Health
## component's health_changed signal, and updates a red fill ColorRect over a
## dark background, plus a numeric label.

const FILL_WIDTH: float = 64.0

@onready var fill: ColorRect = $Bg/Fill
@onready var label: Label = $Bg/Label

var _health: Health = null

func _ready() -> void:
	_try_connect()

func _try_connect() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		# Player may not be in the tree yet; retry shortly.
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	_health = player.get_node_or_null("Health")
	if _health == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	if not _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.connect(_on_health_changed)
	_on_health_changed(_health.health, _health.max_health)

func _on_health_changed(health: int, max_health: int) -> void:
	var ratio: float = 0.0 if max_health <= 0 else float(health) / float(max_health)
	fill.size.x = FILL_WIDTH * ratio
	label.text = "%d / %d" % [health, max_health]
