extends CanvasLayer

## Global inventory/equipment screen. Toggled with the "inventory" action.
## Binds to whichever node is in the "player" group when opened, reads its
## Inventory and Equipment children, and lets the player equip/use items by
## clicking a slot. Pauses gameplay while open.

const COLUMNS := 6

@onready var _panel: PanelContainer = $Panel
@onready var _grid: GridContainer = $Panel/Margin/VBox/Grid
@onready var _equip_label: Label = $Panel/Margin/VBox/EquipLabel

var _player: Node = null
var _inventory: Inventory = null
var _equipment: Equipment = null
var _open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_grid.columns = COLUMNS
	_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _open:
		_close()
	else:
		_open_screen()

func _open_screen() -> void:
	_bind_player()
	if _inventory == null:
		return
	_open = true
	_panel.visible = true
	_refresh()
	get_tree().paused = true

func _close() -> void:
	_open = false
	_panel.visible = false
	get_tree().paused = false

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_inventory = null
		_equipment = null
		return
	_inventory = _player.get_node_or_null("Inventory")
	_equipment = _player.get_node_or_null("Equipment")

func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	if _inventory == null:
		return
	for i in range(_inventory.slots.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.expand_icon = true
		var item: Item = _inventory.get_item(i)
		if item != null:
			btn.icon = item.icon
			var count: int = _inventory.get_count(i)
			btn.text = str(count) if count > 1 else ""
			btn.tooltip_text = item.name
			btn.pressed.connect(_on_slot_pressed.bind(i))
		else:
			btn.disabled = true
		_grid.add_child(btn)
	_update_equip_label()

func _update_equip_label() -> void:
	if _equipment == null:
		_equip_label.text = ""
		return
	var weapon: WeaponItem = _equipment.get_weapon()
	var weapon_name: String = weapon.name if weapon != null else "(none)"
	_equip_label.text = "Weapon: %s    Defense: %d" % [weapon_name, _equipment.total_defense()]

func _on_slot_pressed(index: int) -> void:
	var item: Item = _inventory.get_item(index)
	if item == null:
		return
	if item is WeaponItem:
		var prev: WeaponItem = _equipment.equip_weapon(item as WeaponItem)
		_inventory.remove_at(index, 1)
		if prev != null:
			_inventory.add_item(prev, 1)
	elif item is ArmorItem:
		var prev_armor: ArmorItem = _equipment.equip_armor(item as ArmorItem)
		_inventory.remove_at(index, 1)
		if prev_armor != null:
			_inventory.add_item(prev_armor, 1)
	elif item is ConsumableItem:
		if (item as ConsumableItem).use(_player):
			_inventory.remove_at(index, 1)
	_refresh()
