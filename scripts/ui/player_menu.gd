extends CanvasLayer

## Unified, tabbed player menu in the Stardew/Kynseed mould, owned by `UIManager`
## (reach it as `UIManager.menu`). One overlay replaces the old separate Inventory,
## Quest-journal and Relationships panels.
##
## Open with `Tab`; the legacy keys jump straight to a tab — `I` Inventory,
## `J` Quests, `L` Social — and toggle the menu shut if that tab is already up.
## `Esc` closes. Gameplay pauses while open.
##
## Tabs:
##   Inventory — bag grid + an equipped-gear paper-doll and a live stat readout.
##               Click a bag item to equip/use; click a doll slot to unequip.
##   Character — level, XP, and the derived combat stats.
##   Quests    — active quests with objective progress, plus a completed count.
##   Social    — NPCs met and their heart totals.

enum Tab { INVENTORY, CHARACTER, QUESTS, SOCIAL, MAP }

const TAB_NAMES := {
	Tab.INVENTORY: "Inventory",
	Tab.CHARACTER: "Character",
	Tab.QUESTS: "Quests",
	Tab.SOCIAL: "Social",
	Tab.MAP: "Map",
}

## Bag grid width and slot pixel size (kept compact for the 480x270 viewport).
const COLUMNS := 6
const SLOT := 34.0

## Quest category -> Quests-tab heading. A var (not const) since the keys are
## another class's enum.
var _category_names := {
	Quest.Category.MAIN: "Main Story",
	Quest.Category.CONTRACT: "Contracts",
	Quest.Category.RESCUE: "Rescues",
	Quest.Category.TASK: "Tasks",
}

## Paper-doll rows: [equipment slot, label]. Weapon is handled separately. A var
## (not const) because the entries reference another class's enum.
var _doll_slots := [
	[ArmorItem.ArmorSlot.OFFHAND, "Off-hand"],
	[ArmorItem.ArmorSlot.HEAD, "Head"],
	[ArmorItem.ArmorSlot.BODY, "Body"],
	[ArmorItem.ArmorSlot.LEGS, "Legs"],
	[ArmorItem.ArmorSlot.FEET, "Feet"],
]

var _player: Node = null
var _inventory: Inventory = null
var _equipment: Equipment = null
var _stats: Stats = null
var _health: Health = null

var _open: bool = false
var _tab: int = Tab.INVENTORY

var _tab_bar: HBoxContainer
var _content: MarginContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_shell()
	visible = false

# --- Open / close -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("player_menu"):
		_toggle(_tab)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_jump_to(Tab.INVENTORY)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		_jump_to(Tab.QUESTS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("relationships"):
		_jump_to(Tab.SOCIAL)
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

## Toggle the whole menu, opening on `tab`.
func _toggle(tab: int) -> void:
	if _open:
		_close()
	else:
		open(tab)

## A legacy hotkey: open on its tab, switch to it, or toggle the menu shut if that
## tab is already showing.
func _jump_to(tab: int) -> void:
	if _open and _tab == tab:
		_close()
	elif _open:
		_switch_tab(tab)
	else:
		open(tab)

func open(tab: int = Tab.INVENTORY) -> void:
	if not _bind_player():
		return
	_tab = tab
	_open = true
	visible = true
	get_tree().paused = true
	_connect_sources()
	_rebuild_tab_bar()
	_refresh()

func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	_disconnect_sources()

func _bind_player() -> bool:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	_inventory = _player.get_node_or_null("Inventory") as Inventory
	_equipment = _player.get_node_or_null("Equipment") as Equipment
	_stats = _player.get_node_or_null("Stats") as Stats
	_health = _player.get_node_or_null("Health") as Health
	return _inventory != null and _equipment != null and _stats != null

# --- Live refresh wiring ----------------------------------------------------

## [signal, callable] pairs connected while the menu is open. Each source signal
## just triggers a rebuild of the current tab; the callables differ only in arity
## so they match each signal's argument count.
var _bindings: Array = []

func _connect_sources() -> void:
	_bindings = [
		[_inventory.changed, _r0],
		[_equipment.changed, _r0],
		[_stats.stats_changed, _r0],
		[QuestManager.quest_started, _r1],
		[QuestManager.quest_progressed, _r1],
		[QuestManager.quest_ready, _r1],
		[QuestManager.quest_completed, _r1],
		[QuestManager.tracked_changed, _r1],
		[Relationships.points_changed, _r2],
		[Relationships.hearts_changed, _r2],
		[Relationships.npc_met, _r2],
		[WorldMap.location_discovered, _r1],
		[WorldMap.current_changed, _r1],
	]
	if _health != null:
		_bindings.append([_health.health_changed, _r2])
	for b: Array in _bindings:
		var sig: Signal = b[0]
		var cb: Callable = b[1]
		if not sig.is_connected(cb):
			sig.connect(cb)

func _disconnect_sources() -> void:
	for b: Array in _bindings:
		var sig: Signal = b[0]
		var cb: Callable = b[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_bindings.clear()

func _refresh_if_open() -> void:
	if _open:
		_refresh()

func _r0() -> void: _refresh_if_open()
func _r1(_a: Variant) -> void: _refresh_if_open()
func _r2(_a: Variant, _b: Variant) -> void: _refresh_if_open()

# --- Shell / tabs -----------------------------------------------------------

func _build_shell() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(0.98))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size = Vector2(360, 0)
	margin.add_child(vbox)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(_tab_bar)

	vbox.add_child(HSeparator.new())

	_content = MarginContainer.new()
	_content.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(_content)

	var prompt := UITheme.make_label("[Tab] Close", 9, UITheme.PROMPT)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(prompt)

func _rebuild_tab_bar() -> void:
	for child: Node in _tab_bar.get_children():
		child.queue_free()
	for tab: int in [Tab.INVENTORY, Tab.CHARACTER, Tab.QUESTS, Tab.SOCIAL, Tab.MAP]:
		var btn := Button.new()
		btn.text = TAB_NAMES[tab]
		btn.add_theme_font_size_override("font_size", 10)
		btn.disabled = tab == _tab  # the active tab reads as selected
		btn.pressed.connect(_switch_tab.bind(tab))
		_tab_bar.add_child(btn)

func _switch_tab(tab: int) -> void:
	_tab = tab
	_rebuild_tab_bar()
	_refresh()

func _refresh() -> void:
	for child: Node in _content.get_children():
		child.queue_free()
	match _tab:
		Tab.INVENTORY:
			_content.add_child(_build_inventory())
		Tab.CHARACTER:
			_content.add_child(_build_character())
		Tab.QUESTS:
			_content.add_child(_build_quests())
		Tab.SOCIAL:
			_content.add_child(_build_social())
		Tab.MAP:
			_content.add_child(_build_map())

# --- Inventory tab ----------------------------------------------------------

func _build_inventory() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Bag grid (left).
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	for i in range(_inventory.slots.size()):
		grid.add_child(_make_bag_slot(i))
	row.add_child(grid)

	row.add_child(VSeparator.new())

	# Paper-doll + stats (right).
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.add_child(UITheme.make_label("Equipped", 11, UITheme.ACCENT))
	side.add_child(_make_doll_slot("Weapon", _equipment.get_weapon(), _on_unequip_weapon))
	for entry: Array in _doll_slots:
		var slot: int = entry[0]
		side.add_child(_make_doll_slot(entry[1], _equipment.get_armor(slot), _on_unequip_armor.bind(slot)))
	side.add_child(HSeparator.new())
	side.add_child(_make_stat_panel())
	row.add_child(side)
	return row

func _make_bag_slot(index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT, SLOT)
	btn.expand_icon = true
	var item: Item = _inventory.get_item(index)
	if item != null:
		btn.icon = item.icon
		var count: int = _inventory.get_count(index)
		btn.text = str(count) if count > 1 else ""
		btn.tooltip_text = _item_tooltip(item)
		btn.pressed.connect(_on_bag_slot.bind(index))
	else:
		btn.disabled = true
	return btn

func _make_doll_slot(label: String, item: Item, on_click: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 22)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 10)
	btn.clip_text = true
	if item != null:
		btn.icon = item.icon
		btn.expand_icon = false
		btn.text = "%s: %s" % [label, item.name]
		btn.tooltip_text = _item_tooltip(item)
		btn.pressed.connect(on_click)
	else:
		btn.text = "%s: —" % label
		btn.disabled = true
	return btn

func _make_stat_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var weapon: WeaponItem = _equipment.get_weapon()
	var atk: int = _stats.attack_power() + (weapon.damage if weapon != null else 0)
	var defense: int = _stats.defense_power() + _equipment.total_defense()
	var hp: String = "%d/%d" % [_health.health, _health.max_health] if _health != null else "—"
	box.add_child(UITheme.make_label("Level %d" % _stats.level, 10, UITheme.TEXT))
	box.add_child(UITheme.make_label("HP   %s" % hp, 10, UITheme.TEXT))
	box.add_child(UITheme.make_label("ATK  %d" % atk, 10, UITheme.TEXT))
	box.add_child(UITheme.make_label("DEF  %d" % defense, 10, UITheme.TEXT))
	box.add_child(UITheme.make_label("Spell %d" % _stats.spell_power(), 10, UITheme.TEXT))
	return box

## Equip a weapon/armor (swapping with any current piece), or use a consumable.
func _on_bag_slot(index: int) -> void:
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

func _on_unequip_weapon() -> void:
	var weapon: WeaponItem = _equipment.get_weapon()
	if weapon == null:
		return
	# Only unequip if the bag has room, so gear is never destroyed.
	if _inventory.add_item(weapon, 1) > 0:
		return
	_equipment.unequip_weapon()

func _on_unequip_armor(slot: int) -> void:
	var piece: ArmorItem = _equipment.get_armor(slot)
	if piece == null:
		return
	if _inventory.add_item(piece, 1) > 0:
		return
	_equipment.unequip_armor(slot)

## Item name/description plus its combat stats, with the currently-equipped piece
## shown for comparison.
func _item_tooltip(item: Item) -> String:
	var lines: Array[String] = [item.name]
	if item.description != "":
		lines.append(item.description)
	if item is WeaponItem:
		var w := item as WeaponItem
		lines.append("DMG %d  (%s)" % [w.damage, "Ranged" if w.is_ranged() else "Melee"])
		var cur: WeaponItem = _equipment.get_weapon()
		if cur != null and cur != w:
			lines.append("Equipped: DMG %d" % cur.damage)
	elif item is ArmorItem:
		var a := item as ArmorItem
		lines.append("DEF %d%s" % [a.defense, "  Block %d" % a.block if a.block > 0 else ""])
		var cur_a: ArmorItem = _equipment.get_armor(a.armor_slot)
		if cur_a != null and cur_a != a:
			lines.append("Equipped: DEF %d" % cur_a.defense)
	elif item is ConsumableItem:
		var c := item as ConsumableItem
		if c.heal > 0:
			lines.append("Heals %d HP" % c.heal)
	if item.value > 0:
		lines.append("Value %d g" % item.value)
	return "\n".join(lines)

# --- Character tab ----------------------------------------------------------

func _build_character() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(UITheme.make_label("Level %d" % _stats.level, 14, UITheme.ACCENT))

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = _stats.xp_progress() * 100.0
	bar.custom_minimum_size = Vector2(220, 12)
	bar.show_percentage = false
	box.add_child(bar)
	box.add_child(UITheme.make_label("XP  %d / %d" % [_stats.xp, _stats.xp_to_next], 9, UITheme.PROMPT))

	box.add_child(HSeparator.new())
	var weapon: WeaponItem = _equipment.get_weapon()
	var atk: int = _stats.attack_power() + (weapon.damage if weapon != null else 0)
	var defense: int = _stats.defense_power() + _equipment.total_defense()
	box.add_child(UITheme.make_label("Max HP   %d" % _stats.max_hp, 11, UITheme.TEXT))
	box.add_child(UITheme.make_label("Attack   %d" % atk, 11, UITheme.TEXT))
	box.add_child(UITheme.make_label("Defense  %d" % defense, 11, UITheme.TEXT))
	box.add_child(UITheme.make_label("Spell    %d" % _stats.spell_power(), 11, UITheme.TEXT))
	return box

# --- Quests tab -------------------------------------------------------------

func _build_quests() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(320, 0)

	var active: Array = QuestManager.get_active_quests()
	if active.is_empty():
		box.add_child(UITheme.make_label("No active quests.", 10, UITheme.MUTED))
	else:
		# Group under category headings, in a fixed order.
		for category: int in [Quest.Category.MAIN, Quest.Category.CONTRACT, Quest.Category.RESCUE, Quest.Category.TASK]:
			var group: Array = active.filter(
				func(e: Dictionary) -> bool: return (e["quest"] as Quest).category == category)
			if group.is_empty():
				continue
			box.add_child(UITheme.make_label(_category_names[category], 11, UITheme.ACCENT))
			for entry: Dictionary in group:
				box.add_child(_quest_row(entry))

	var done: int = QuestManager.get_completed_count()
	if done > 0:
		box.add_child(HSeparator.new())
		box.add_child(UITheme.make_label("Completed: %d" % done, 10, UITheme.PROMPT))
	return box

## One quest entry: a title row with a Track button, then per-objective progress
## (or a turn-in prompt).
func _quest_row(entry: Dictionary) -> Control:
	var quest: Quest = entry["quest"]
	var progress: Array = entry["progress"]
	var ready: bool = entry["ready"]

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var title := UITheme.make_label(quest.title, 10, UITheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.tooltip_text = quest.description
	header.add_child(title)

	var tracked: bool = QuestManager.get_tracked_id() == quest.id
	var track_btn := Button.new()
	track_btn.text = "Tracking" if tracked else "Track"
	track_btn.disabled = tracked
	track_btn.add_theme_font_size_override("font_size", 9)
	track_btn.pressed.connect(_on_track_pressed.bind(quest.id))
	header.add_child(track_btn)
	row.add_child(header)

	if ready:
		var prompt: String = "   Ready — turn in to %s" % String(quest.giver_id) if quest.giver_id != &"" else "   Ready to turn in!"
		row.add_child(UITheme.make_label(prompt, 9, UITheme.GOLD))
	else:
		var objectives: Array = quest.get_objectives()
		for i in range(objectives.size()):
			var obj: QuestObjective = objectives[i]
			var current: int = int(progress[i]) if i < progress.size() else 0
			row.add_child(UITheme.make_label("   • %s  %d/%d" % [obj.label(), current, obj.required_count], 9, UITheme.PROMPT))
	return row

func _on_track_pressed(quest_id: StringName) -> void:
	QuestManager.set_tracked(quest_id)

# --- Social tab -------------------------------------------------------------

func _build_social() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(240, 0)
	var known: Array = Relationships.get_known()
	if known.is_empty():
		box.add_child(UITheme.make_label("You haven't met anyone yet.", 11, UITheme.MUTED))
		return box
	for npc: Dictionary in known:
		var hearts: int = int(npc["hearts"])
		var bar: String = "%s%s" % ["♥".repeat(hearts), "♡".repeat(Relationships.MAX_HEARTS - hearts)]
		box.add_child(UITheme.make_label("%s   %s" % [String(npc["name"]), bar], 11, UITheme.TEXT))
	return box

# --- Map tab ----------------------------------------------------------------

func _build_map() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(240, 0)

	var current: StringName = WorldMap.get_current()
	var here: WorldLocation = WorldMap.get_location(current)
	box.add_child(UITheme.make_label("Location: %s" % (here.display_name if here != null else "The Wilds"), 11, UITheme.ACCENT))
	box.add_child(HSeparator.new())

	# No fast travel mid-encounter — cross to the exit instead.
	if current == &"":
		box.add_child(UITheme.make_label("You can't fast travel from the wilds.", 10, UITheme.MUTED))
		return box

	var options: Array = WorldMap.get_travel_options()
	if options.is_empty():
		box.add_child(UITheme.make_label("Nowhere discovered to travel yet.", 10, UITheme.MUTED))
		return box

	box.add_child(UITheme.make_label("Fast travel to:", 10, UITheme.TEXT))
	for loc: WorldLocation in options:
		var btn := Button.new()
		btn.text = "%s   (Tier %d)" % [loc.display_name, loc.tier]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 10)
		btn.tooltip_text = loc.blurb
		btn.pressed.connect(_on_travel_pressed.bind(loc.id))
		box.add_child(btn)
	return box

func _on_travel_pressed(location_id: StringName) -> void:
	_close()  # unpause before the scene transition
	TravelManager.fast_travel(location_id)
