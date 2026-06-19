extends CanvasLayer

## On-screen tracker for the currently tracked quest, owned by `UIManager`. Shows
## the quest title and its objective progress (or "Ready to turn in!"). Unlike the
## per-scene HUD bars, this is centrally owned and gates its own visibility: it
## appears only during gameplay — when a quest is tracked, a player is in the
## scene, and the game is not paused (so it hides behind menus/dialogue).

var _panel: PanelContainer
var _vbox: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	_build()
	QuestManager.tracked_changed.connect(_on_changed)
	QuestManager.quest_progressed.connect(_on_changed)
	QuestManager.quest_ready.connect(_on_changed)
	QuestManager.quest_completed.connect(_on_changed)
	_refresh()

func _process(_delta: float) -> void:
	var should_show: bool = QuestManager.get_tracked() != null \
		and get_tree().get_first_node_in_group("player") != null \
		and not get_tree().paused
	if _panel.visible != should_show:
		_panel.visible = should_show

func _on_changed(_quest: Quest) -> void:
	_refresh()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.offset_left = 6.0
	_panel.offset_top = 40.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var style := UITheme.panel_style(0.85)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 1)
	_vbox.custom_minimum_size = Vector2(120, 0)
	_panel.add_child(_vbox)

func _refresh() -> void:
	for child: Node in _vbox.get_children():
		child.queue_free()
	var quest: Quest = QuestManager.get_tracked()
	if quest == null:
		return
	_vbox.add_child(UITheme.make_label(quest.title, 10, UITheme.ACCENT))
	if QuestManager.is_ready(quest.id):
		_vbox.add_child(UITheme.make_label("Ready to turn in!", 9, UITheme.GOLD))
		return
	var progress: Array = QuestManager.get_objective_progress(quest.id)
	var objectives: Array = quest.get_objectives()
	for i in range(objectives.size()):
		var obj: QuestObjective = objectives[i]
		var current: int = int(progress[i]) if i < progress.size() else 0
		_vbox.add_child(UITheme.make_label("• %s  %d/%d" % [obj.label(), current, obj.required_count], 9, UITheme.TEXT))
