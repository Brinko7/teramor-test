extends CanvasLayer

## HUD ability hotbar. Finds the player on _ready and mirrors its AbilityCaster:
## one slot per hotbar ability (max 4), each showing the ability icon, its hotkey
## number, a depleting cooldown wipe, and a grey dim when mana is too low to cast.
## Built in code (like hud_coins) and instanced per world scene. Refreshes on the
## caster's cooldowns_changed and the Mana component's mana_changed signals.

const MAX_SLOTS: int = 4
const SLOT: float = 18.0
const SEP: int = 3

const DIM := Color(0.4, 0.4, 0.4, 1)
const COOLDOWN := Color(0, 0, 0, 0.55)

var _caster: AbilityCaster = null
var _mana: Mana = null

var _slots: Array[Control] = []
var _icons: Array[TextureRect] = []
var _overlays: Array[ColorRect] = []

func _ready() -> void:
	layer = 82
	_build()
	_try_connect()

func _build() -> void:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", SEP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for i in range(MAX_SLOTS):
		row.add_child(_make_slot(i))

func _make_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UITheme.panel_style(0.85, 2)
	slot.add_theme_stylebox_override("panel", style)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2.0
	icon.offset_top = 2.0
	icon.offset_right = -2.0
	icon.offset_bottom = -2.0
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var overlay := ColorRect.new()
	overlay.color = COOLDOWN
	overlay.anchor_left = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_top = 0.0
	overlay.anchor_bottom = 0.0
	overlay.offset_left = 1.0
	overlay.offset_right = -1.0
	overlay.offset_top = 1.0
	overlay.offset_bottom = 1.0
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay)

	var key := Label.new()
	key.text = str(index + 1)
	var settings := LabelSettings.new()
	settings.font_size = 7
	settings.font_color = Color(0.95, 0.92, 0.82, 1)
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.8)
	key.label_settings = settings
	key.position = Vector2(2, -2)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key)

	_slots.append(slot)
	_icons.append(icon)
	_overlays.append(overlay)
	return slot

func _try_connect() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	_caster = player.get_node_or_null("AbilityCaster")
	if _caster == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	_mana = player.get_node_or_null("Mana")
	if not _caster.cooldowns_changed.is_connected(_refresh):
		_caster.cooldowns_changed.connect(_refresh)
	if _mana != null and not _mana.mana_changed.is_connected(_on_mana_changed):
		_mana.mana_changed.connect(_on_mana_changed)
	_refresh()

func _on_mana_changed(_mana_value: int, _max_mana: int) -> void:
	_refresh()

func _refresh() -> void:
	if _caster == null:
		return
	var shown: int = mini(_caster.slot_count(), MAX_SLOTS)
	for i in range(MAX_SLOTS):
		var slot := _slots[i]
		if i >= shown:
			slot.visible = false
			continue
		slot.visible = true
		var ability := _caster.get_ability(i)
		_icons[i].texture = ability.icon if ability != null else null

		var ratio: float = _caster.cooldown_ratio(i)
		var overlay := _overlays[i]
		overlay.visible = ratio > 0.001
		overlay.offset_bottom = 1.0 + ratio * (SLOT - 2.0)

		var affordable: bool = ability == null or _mana == null or _mana.has_mana(ability.mana_cost)
		_icons[i].modulate = Color(1, 1, 1, 1) if affordable else DIM
