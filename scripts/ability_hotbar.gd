extends CanvasLayer

## Ability radial. The number row 1–0 now drives the item hotbar, so spells live
## behind a modifier: **hold Q** and a wheel of the player's unlocked abilities
## fans out in the screen centre, each slot showing its icon, cast key (1–4), a
## depleting cooldown wipe and a grey dim when mana is too low. Tapping the key
## while the wheel is up casts (the player handles the cast + aim). Released, the
## wheel hides and the number keys belong to items again.
##
## Built in code and instanced per world scene; mirrors the player's AbilityCaster
## and refreshes on its cooldowns_changed and the Mana component's mana_changed.

const MAX_SLOTS: int = 4
const SLOT: float = 22.0
## How far each slot sits from the wheel centre.
const RADIUS: float = 28.0

const DIM := Color(0.4, 0.4, 0.4, 1)
const COOLDOWN := Color(0, 0, 0, 0.55)

var _caster: AbilityCaster = null
var _mana: Mana = null

var _root: Control = null
var _slots: Array[Control] = []
var _icons: Array[TextureRect] = []
var _overlays: Array[ColorRect] = []

func _ready() -> void:
	layer = 90
	_build()
	_try_connect()

func _process(_delta: float) -> void:
	# The wheel is visible only while the modifier is held and something is
	# castable; otherwise the number row belongs to the item hotbar.
	var show: bool = _caster != null and _caster.slot_count() > 0 \
		and Input.is_action_pressed("ability_menu")
	if show != _root.visible:
		_root.visible = show
		if show:
			_refresh()

func _build() -> void:
	# A zero-size anchor pinned to screen centre; ring slots hang off its origin.
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.offset_left = 0.0
	_root.offset_right = 0.0
	_root.offset_top = 0.0
	_root.offset_bottom = 0.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# Backing plate so the fanned slots read as one wheel.
	var plate_extent: float = RADIUS + SLOT * 0.5 + 5.0
	var plate := Panel.new()
	plate.custom_minimum_size = Vector2(plate_extent * 2, plate_extent * 2)
	plate.position = Vector2(-plate_extent, -plate_extent)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", UITheme.panel_style(0.78, int(plate_extent)))
	_root.add_child(plate)

	for i in range(MAX_SLOTS):
		var slot := _make_slot(i)
		# Slot 0 at the top, then clockwise.
		var ang: float = -PI / 2.0 + TAU * float(i) / float(MAX_SLOTS)
		slot.position = Vector2(cos(ang), sin(ang)) * RADIUS - Vector2(SLOT, SLOT) * 0.5
		_root.add_child(slot)

	var caption := UITheme.make_label("Abilities", 7, UITheme.PROMPT)
	caption.position = Vector2(-plate_extent, plate_extent + 1.0)
	caption.size = Vector2(plate_extent * 2, 10)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(caption)

func _make_slot(index: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", UITheme.panel_style(0.9, 2))

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
	settings.font_size = 8
	settings.font_color = Color(0.95, 0.92, 0.82, 1)
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.8)
	key.label_settings = settings
	key.position = Vector2(2, -3)
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
