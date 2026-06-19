extends CanvasLayer

## Trading screen, owned by `UIManager` (reach it as `UIManager.shop`). A merchant
## calls `open(stock, name)`
## with its wares; the panel shows two columns — BUY the merchant's stock (at full
## `value`) and SELL from the player's bag (at `SELL_FRACTION` of value) — both
## transacting against the Wallet. Pauses gameplay while open, like the inventory
## screen. Built entirely in code, matching the other autoload-owned panels.

## Fraction of an item's value the merchant pays when buying it from the player.
const SELL_FRACTION := 0.5

var _player: Node = null
var _inventory: Inventory = null
var _stock: Array = []
var _shop_name: String = "Trader"
var _open: bool = false

var _panel: PanelContainer
var _title_label: Label
var _gold_label: Label
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build()
	visible = false

func buy_price(item: Item) -> int:
	return item.value

func sell_price(item: Item) -> int:
	return maxi(1, int(floor(item.value * SELL_FRACTION)))

# --- Open / close -----------------------------------------------------------

## `stock` is an Array[Item] the merchant offers for sale.
func open(stock: Array, shop_name: String = "Trader") -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_inventory = _player.get_node_or_null("Inventory") as Inventory
	if _inventory == null:
		return
	_stock = stock
	_shop_name = shop_name
	_open = true
	visible = true
	get_tree().paused = true
	if not _inventory.changed.is_connected(_refresh):
		_inventory.changed.connect(_refresh)
	if not Wallet.changed.is_connected(_on_wallet_changed):
		Wallet.changed.connect(_on_wallet_changed)
	_refresh()

func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	if Wallet.changed.is_connected(_on_wallet_changed):
		Wallet.changed.disconnect(_on_wallet_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

# --- Transactions -----------------------------------------------------------

func _buy(item: Item) -> void:
	var price: int = buy_price(item)
	if not Wallet.can_afford(price):
		return
	var overflow: int = _inventory.add_item(item, 1)
	if overflow > 0:
		return  # bag full: nothing added, nothing charged
	Wallet.spend(price)

func _sell(item: Item) -> void:
	if _inventory.consume_items(item.id, 1):
		Wallet.add(sell_price(item))

func _on_wallet_changed(_balance: int) -> void:
	_refresh()

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

	_title_label = UITheme.make_label("Trader", 12, UITheme.GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_gold_label = UITheme.make_label("", 12, UITheme.GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_gold_label)

	vbox.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	vbox.add_child(columns)

	_buy_list = _make_column(columns, "Buy")
	var vsep := VSeparator.new()
	columns.add_child(vsep)
	_sell_list = _make_column(columns, "Sell")

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
	scroll.custom_minimum_size = Vector2(158, 132)
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
	_title_label.text = _shop_name
	_gold_label.text = "%d g" % Wallet.get_gold()
	_refresh_buy()
	_refresh_sell()

func _refresh_buy() -> void:
	for child: Node in _buy_list.get_children():
		child.queue_free()
	if _stock.is_empty():
		_buy_list.add_child(UITheme.make_label("Nothing for sale.", 9, UITheme.MUTED))
		return
	for entry: Variant in _stock:
		var item: Item = entry
		if item == null:
			continue
		var price: int = buy_price(item)
		var btn := UITheme.make_row_button("%s" % item.name, "%d g" % price, item.icon)
		btn.disabled = not Wallet.can_afford(price)
		btn.tooltip_text = item.description
		btn.pressed.connect(_buy.bind(item))
		_buy_list.add_child(btn)

func _refresh_sell() -> void:
	for child: Node in _sell_list.get_children():
		child.queue_free()
	var seen: Dictionary = {}
	var any: bool = false
	for slot: Dictionary in _inventory.slots:
		if slot.is_empty():
			continue
		var item: Item = slot["item"]
		if seen.has(item.id):
			continue
		seen[item.id] = true
		any = true
		var count: int = _inventory.count_of(item.id)
		var btn := UITheme.make_row_button("%s x%d" % [item.name, count], "%d g" % sell_price(item), item.icon)
		btn.tooltip_text = item.description
		btn.pressed.connect(_sell.bind(item))
		_sell_list.add_child(btn)
	if not any:
		_sell_list.add_child(UITheme.make_label("Your bag is empty.", 9, UITheme.MUTED))
