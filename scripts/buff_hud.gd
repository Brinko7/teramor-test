extends CanvasLayer

## HUD readout of the player's active food buffs. Sits under the purse on the right
## edge and lists each active buff with its remaining time, refreshing on the Buffs
## component's `changed` signal and ticking the countdown each frame. Instanced per
## world scene (like the coin/health HUD) so it never bleeds onto menu screens; it
## binds to the player via the `"player"` group and hides itself when no buff is up.

const STAT_NAMES := ["Melee", "Ranged", "Spell", "Defense", "Max HP", "Speed", "Regen"]

var _buffs: PlayerBuffs = null
var _panel: PanelContainer = null
var _box: VBoxContainer = null

func _ready() -> void:
	layer = 80
	_build()
	_bind.call_deferred()

func _bind() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node
	_buffs = p.get_node_or_null("Buffs") as PlayerBuffs
	if _buffs != null:
		_buffs.changed.connect(_refresh)
		_refresh()

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_right = -6.0
	_panel.offset_top = 34.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UITheme.panel_style(0.85)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_panel.add_child(_box)

func _process(_delta: float) -> void:
	# The buff list ticks down continuously; refresh the readout so the timers move.
	if _buffs != null and _buffs.has_any():
		_refresh()

func _refresh() -> void:
	if _buffs == null or _panel == null:
		return
	for child in _box.get_children():
		child.queue_free()
	var actives := _buffs.get_active()
	_panel.visible = not actives.is_empty()
	for b in actives:
		var label := Label.new()
		var settings := LabelSettings.new()
		settings.font_size = 11
		settings.font_color = UITheme.ACCENT
		label.label_settings = settings
		var stat: int = int(b["stat"])
		var name: String = STAT_NAMES[stat] if stat < STAT_NAMES.size() else "?"
		label.text = "%s  %ds" % [name, int(ceil(float(b["remaining"])))]
		_box.add_child(label)
