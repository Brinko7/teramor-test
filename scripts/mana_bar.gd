extends CanvasLayer

## HUD mana bar. Finds the player on _ready, connects to its Mana component's
## mana_changed signal, and updates a blue fill ColorRect over a dark background,
## plus a numeric label. Mirrors the health bar, sitting just beneath it.

const FILL_WIDTH: float = 64.0

@onready var fill: ColorRect = $Bg/Fill
@onready var label: Label = $Bg/Label

var _mana: Mana = null

func _ready() -> void:
	_try_connect()

func _try_connect() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	_mana = player.get_node_or_null("Mana")
	if _mana == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	if not _mana.mana_changed.is_connected(_on_mana_changed):
		_mana.mana_changed.connect(_on_mana_changed)
	_on_mana_changed(_mana.mana, _mana.max_mana)

func _on_mana_changed(mana: int, max_mana: int) -> void:
	var ratio: float = 0.0 if max_mana <= 0 else float(mana) / float(max_mana)
	fill.size.x = FILL_WIDTH * ratio
	label.text = "%d / %d" % [mana, max_mana]
