extends CanvasLayer

## The camp storage screen, owned by `UIManager` (reach it as `UIManager.storage`).
## A chest prop calls `open()`;
## the panel shows two columns — the player's Bag on the left and the shared camp
## Storage (StorageManager.stash) on the right. Clicking a row moves that whole
## stack across; a destination that can't hold it all keeps the remainder behind.
## Pauses gameplay while open, like the inventory and shop screens. Built in code,
## matching the other autoload-owned panels.

var _player: Node = null
var _bag: Inventory = null
var _stash: Inventory = null
var _open: bool = false

var _panel: PanelContainer
var _title_label: Label
var _usage_label: Label
var _bag_list: VBoxContainer
var _stash_list: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build()
	visible = false

# --- Open / close -----------------------------------------------------------

func open() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_bag = _player.get_node_or_null("Inventory") as Inventory
	_stash = StorageManager.stash
	if _bag == null or _stash == null:
		return
	_open = true
	visible = true
	get_tree().paused = true
	if not _bag.changed.is_connected(_refresh):
		_bag.changed.connect(_refresh)
	if not _stash.changed.is_connected(_refresh):
		_stash.changed.connect(_refresh)
	_refresh()

func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	if _bag != null and _bag.changed.is_connected(_refresh):
		_bag.changed.disconnect(_refresh)
	if _stash != null and _stash.changed.is_connected(_refresh):
		_stash.changed.disconnect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

# --- Transfers --------------------------------------------------------------

func _deposit(item: Item) -> void:
	_move(_bag, _stash, item)

func _withdraw(item: Item) -> void:
	_move(_stash, _bag, item)

## Move an item's whole stack from `src` to `dst`, leaving behind only what
## doesn't fit. Add to the destination first, then consume exactly what landed,
## so a full destination never destroys items.
func _move(src: Inventory, dst: Inventory, item: Item) -> void:
	var have: int = src.count_of(item.id)
	if have <= 0:
		return
	var overflow: int = dst.add_item(item, have)
	var moved: int = have - overflow
	if moved > 0:
		src.consume_items(item.id, moved)

# --- UI ---------------------------------------------------------------------

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style(0.980392))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	_title_label = UITheme.make_label("Storage Chest", 12, UITheme.TAN)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_usage_label = UITheme.make_label("", 12, UITheme.TAN)
	_usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_usage_label)

	vbox.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	vbox.add_child(columns)

	_bag_list = _make_column(columns, "Bag  >")
	columns.add_child(VSeparator.new())
	_stash_list = _make_column(columns, "<  Storage")

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

func _make_column(parent: Node, heading: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	parent.add_child(col)

	col.add_child(UITheme.make_label(heading, 11, UITheme.TEXT))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(158, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list

func _refresh() -> void:
	if not _open:
		return
	_usage_label.text = "%d/%d" % [_used(_stash), _stash.capacity]
	_fill(_bag_list, _bag, _deposit, "Bag is empty.")
	_fill(_stash_list, _stash, _withdraw, "Storage is empty.")

## Rebuild one column: one button per distinct item, click bound to `on_click`.
func _fill(list: VBoxContainer, inv: Inventory, on_click: Callable, empty_text: String) -> void:
	for child: Node in list.get_children():
		child.queue_free()
	var seen: Dictionary = {}
	var any: bool = false
	for slot: Dictionary in inv.slots:
		if slot.is_empty():
			continue
		var item: Item = slot["item"]
		if seen.has(item.id):
			continue
		seen[item.id] = true
		any = true
		var count: int = inv.count_of(item.id)
		var btn := UITheme.make_row_button("%s" % item.name, "x%d" % count, item.icon)
		btn.tooltip_text = item.description
		btn.pressed.connect(on_click.bind(item))
		list.add_child(btn)
	if not any:
		list.add_child(UITheme.make_label(empty_text, 9, UITheme.MUTED))

func _used(inv: Inventory) -> int:
	var n: int = 0
	for slot: Dictionary in inv.slots:
		if not slot.is_empty():
			n += 1
	return n

