extends CanvasLayer

## Self-contained XP/level HUD. Finds the player's Stats node, shows the current
## level and an XP progress bar. Refreshes on level-up (via Events) and polls the
## XP fraction each frame so partial-XP gains from kills animate smoothly.

@onready var level_label: Label = $Root/LevelLabel
@onready var xp_bar: ProgressBar = $Root/XPBar

var _stats: Stats = null

func _ready() -> void:
	Events.player_leveled_up.connect(_on_player_leveled_up)
	_resolve_stats()
	_refresh()

func _resolve_stats() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]
	if player.has_node("Stats"):
		_stats = player.get_node("Stats") as Stats

func _process(_delta: float) -> void:
	if _stats == null:
		_resolve_stats()
		if _stats == null:
			return
	xp_bar.value = _stats.xp_progress() * 100.0

func _on_player_leveled_up(_new_level: int) -> void:
	_refresh()

func _refresh() -> void:
	if _stats == null:
		return
	level_label.text = "Lv %d" % _stats.level
	xp_bar.value = _stats.xp_progress() * 100.0
