extends CanvasLayer

## Bottom-centre item hotbar: ten slots mirroring the first ten bag slots, bound
## to keys 1–0. Shows each item's icon and stack count, the slot's key number,
## and a gold border on the held slot. Built in code (like hud_coins) and
## instanced per world scene; refreshes on the bag's `changed` and the
## ItemHotbar's `selection_changed`.

const SLOT: float = 22.0
const SEP: int = 2

var _inv: Inventory = null
var _hotbar: ItemHotbar = null

var _slots: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat

func _ready() -> void:
	layer = 81
	_style_normal = UITheme.panel_style(0.8, 2)
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(UITheme.PANEL_BG, 0.95)
	_style_selected.set_border_width_all(2)
	_style_selected.border_color = UITheme.GOLD
	_style_selected.set_corner_radius_all(2)
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

	for i in range(ItemHotbar.SIZE):
		row.add_child(_make_slot(i))

func _make_slot(index: int) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _style_normal)

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 2.0
	icon.offset_top = 2.0
	icon.offset_right = -2.0
	icon.offset_bottom = -2.0
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	# Slot key: 1..9 then 0 for the tenth.
	var key := Label.new()
	key.text = str((index + 1) % 10)
	var ksettings := LabelSettings.new()
	ksettings.font_size = 7
	ksettings.font_color = Color(0.95, 0.92, 0.82, 1)
	ksettings.outline_size = 2
	ksettings.outline_color = Color(0, 0, 0, 0.8)
	key.label_settings = ksettings
	key.position = Vector2(2, -3)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(key)

	var count := Label.new()
	var csettings := LabelSettings.new()
	csettings.font_size = 7
	csettings.font_color = UITheme.PARCHMENT
	csettings.outline_size = 2
	csettings.outline_color = Color(0, 0, 0, 0.85)
	count.label_settings = csettings
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -2.0
	count.offset_bottom = 1.0
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)

	_slots.append(slot)
	_icons.append(icon)
	_counts.append(count)
	return slot

func _try_connect() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	_inv = player.get_node_or_null("Inventory")
	_hotbar = player.get_node_or_null("ItemHotbar")
	if _inv == null or _hotbar == null:
		get_tree().create_timer(0.2).timeout.connect(_try_connect)
		return
	if not _inv.changed.is_connected(_refresh):
		_inv.changed.connect(_refresh)
	if not _hotbar.selection_changed.is_connected(_on_selection_changed):
		_hotbar.selection_changed.connect(_on_selection_changed)
	_refresh()

func _on_selection_changed(_index: int) -> void:
	_refresh()

func _refresh() -> void:
	if _inv == null or _hotbar == null:
		return
	for i in range(ItemHotbar.SIZE):
		var item: Item = _inv.get_item(i)
		_icons[i].texture = item.icon if item != null else null
		var count: int = _inv.get_count(i)
		_counts[i].text = str(count) if count > 1 else ""
		_slots[i].add_theme_stylebox_override(
			"panel", _style_selected if i == _hotbar.selected else _style_normal)
