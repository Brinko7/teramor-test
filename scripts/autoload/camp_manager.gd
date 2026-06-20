extends Node

## Autoload `CampManager`. The recruited-camp roster, the chores they do for you,
## and the camp improvements you buy with what they bring in.
##
## Befriend a camp member (Relationships hearts) and, once you've reached their
## `recruit_hearts`, recruit them through dialogue — up to the camp's recruit cap.
## A recruited member takes a daily ROLE:
##   farmhand   — waters the farm + carries the ripe harvest to the stash
##   forager    — brings back wild goods (herbs, mushrooms, deadfall)
##   woodcutter — stocks building materials (wood, stone)
##   cook       — turns stash produce into Camp Stew (a healing meal)
## Each dawn (the in-game day rolls over) the *active* roster does its chores and a
## short report says what they brought in.
##
## The take from those chores is the camp economy: spend stash goods on CAMP
## UPGRADES (resources/camp/upgrades/*.tres) that raise the recruit cap, let each
## farmhand work more rows, or boost gather yields — so a small camp grows into a
## thriving one.
##
## A pure data manager in the FarmManager / Relationships mould: it owns state +
## signals, and the player menu's Camp tab renders the roster, the upgrades, and
## last night's report. Registered **after** FarmManager so its day handler runs
## *after* FarmManager has matured the watered crops — the farmhand then harvests
## what just ripened and re-waters the rest for the next night.
##
## Implements the SaveManager "persistent" contract.

signal roster_changed
signal upgrades_changed
signal chores_reported(lines: Array)

const ROLE_FARMHAND := &"farmhand"
const ROLE_FORAGER := &"forager"
const ROLE_WOODCUTTER := &"woodcutter"
const ROLE_COOK := &"cook"

## Effect keys an upgrade may grant (see CampUpgrade.effect).
const EFFECT_RECRUIT_SLOTS := &"recruit_slots"
const EFFECT_PLOTS := &"plots_per_farmhand"
const EFFECT_YIELD := &"yield"

const UPGRADES_DIR := "res://resources/camp/upgrades/"

## Base camp capabilities, before any upgrades.
const BASE_RECRUIT_CAP := 2
const BASE_PLOTS_PER_FARMHAND := 8

## A forager's nightly haul: item path -> base count per forager.
const FORAGE_TABLE := {
	"res://resources/items/herb.tres": 2,
	"res://resources/items/wild_mushroom.tres": 1,
	"res://resources/items/wood.tres": 3,
}
## A woodcutter's nightly haul of building materials.
const MATERIAL_TABLE := {
	"res://resources/items/wood.tres": 4,
	"res://resources/items/stone.tres": 2,
}
## Produce a cook will turn into stew, and the recipe (per stew).
const COOK_PRODUCE := ["turnip", "wheat"]
const STEW_PATH := "res://resources/items/produce/camp_stew.tres"
const PRODUCE_PER_STEW := 2
const STEWS_PER_COOK := 2

# npc_id (String) -> {name: String, role: String, active: bool}
var _members: Dictionary = {}
var _last_report: Array = []
## id (StringName) -> CampUpgrade (the catalog)
var _upgrades: Dictionary = {}
var _upgrade_order: Array[StringName] = []
## Owned upgrade ids.
var _owned: Dictionary = {}

func _ready() -> void:
	add_to_group("persistent")
	_load_upgrades()
	TimeManager.day_changed.connect(_on_day_changed)

func _load_upgrades() -> void:
	var dir := DirAccess.open(UPGRADES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var up := load(UPGRADES_DIR + clean) as CampUpgrade
				if up != null and up.id != &"":
					_upgrades[up.id] = up
					_upgrade_order.append(up.id)
		file_name = dir.get_next()
	dir.list_dir_end()
	_upgrade_order.sort_custom(func(a, b): return _upgrades[a].sort < _upgrades[b].sort)

# --- Derived camp capabilities (base + owned upgrades) -----------------------

func _effect_total(effect: StringName) -> int:
	var total: int = 0
	for id: StringName in _owned:
		var up: CampUpgrade = _upgrades.get(id, null)
		if up != null and up.effect == effect:
			total += up.amount
	return total

func get_recruit_cap() -> int:
	return BASE_RECRUIT_CAP + _effect_total(EFFECT_RECRUIT_SLOTS)

func get_plots_per_farmhand() -> int:
	return BASE_PLOTS_PER_FARMHAND + _effect_total(EFFECT_PLOTS)

func get_yield_bonus() -> int:
	return _effect_total(EFFECT_YIELD)

# --- Roster -----------------------------------------------------------------

## Enlist an NPC. Returns false if already enlisted or the camp is at its cap.
func recruit(npc_id: StringName, display_name: String, role: StringName) -> bool:
	var key: String = String(npc_id)
	if _members.has(key) or _members.size() >= get_recruit_cap():
		return false
	_members[key] = {"name": display_name, "role": String(role), "active": true}
	roster_changed.emit()
	return true

func can_recruit() -> bool:
	return _members.size() < get_recruit_cap()

func is_recruited(npc_id: StringName) -> bool:
	return _members.has(String(npc_id))

## Toggle a member between working and resting (resting members skip chores).
func set_active(npc_id: StringName, active: bool) -> void:
	var key: String = String(npc_id)
	if _members.has(key):
		_members[key]["active"] = bool(active)
		roster_changed.emit()

func is_active(npc_id: StringName) -> bool:
	return bool(_members.get(String(npc_id), {}).get("active", false))

func get_role(npc_id: StringName) -> StringName:
	return StringName(String(_members.get(String(npc_id), {}).get("role", "")))

func get_roster() -> Array:
	var out: Array = []
	for key: String in _members:
		var m: Dictionary = _members[key]
		out.append({
			"id": StringName(key),
			"name": String(m["name"]),
			"role": StringName(String(m["role"])),
			"active": bool(m["active"]),
		})
	return out

func get_last_report() -> Array:
	return _last_report.duplicate()

func count() -> int:
	return _members.size()

# --- Upgrades ---------------------------------------------------------------

func get_upgrades() -> Array:
	var out: Array = []
	for id: StringName in _upgrade_order:
		out.append(_upgrades[id])
	return out

func is_owned(upgrade_id: StringName) -> bool:
	return _owned.has(upgrade_id)

## Can the player afford this upgrade right now (from the shared stash)?
func can_afford(upgrade_id: StringName) -> bool:
	var up: CampUpgrade = _upgrades.get(upgrade_id, null)
	if up == null or _owned.has(upgrade_id):
		return false
	for item_id: Variant in up.cost:
		if StorageManager.stash.count_of(StringName(item_id)) < int(up.cost[item_id]):
			return false
	return true

## Buy an upgrade: consume its cost from the stash, mark it owned, apply effect.
## Returns false if unaffordable or already owned.
func purchase(upgrade_id: StringName) -> bool:
	if not can_afford(upgrade_id):
		return false
	var up: CampUpgrade = _upgrades[upgrade_id]
	for item_id: Variant in up.cost:
		StorageManager.stash.consume_items(StringName(item_id), int(up.cost[item_id]))
	_owned[upgrade_id] = true
	upgrades_changed.emit()
	roster_changed.emit()  # the recruit cap may have changed
	return true

# --- Daily chores -----------------------------------------------------------

func _on_day_changed(_day: int) -> void:
	_last_report = []
	var farmhands: int = 0
	var foragers: int = 0
	var woodcutters: int = 0
	var cooks: int = 0
	for key: String in _members:
		var m: Dictionary = _members[key]
		if not bool(m["active"]):
			continue
		match String(m["role"]):
			"farmhand": farmhands += 1
			"forager": foragers += 1
			"woodcutter": woodcutters += 1
			"cook": cooks += 1
	if farmhands > 0:
		_farmhands_tend(farmhands)
	if foragers > 0:
		_gather(foragers, FORAGE_TABLE, "Foraged")
	if woodcutters > 0:
		_gather(woodcutters, MATERIAL_TABLE, "Cut")
	if cooks > 0:
		_cooks_prepare(cooks)
	if not _last_report.is_empty():
		chores_reported.emit(_last_report)
		UIManager.notify("The camp stirs", String(_last_report[0]))

## Harvest every ripe crop to the stash, then water every remaining planted crop so
## it grows tonight. Each farmhand covers up to get_plots_per_farmhand() plots.
func _farmhands_tend(workers: int) -> void:
	var harvested: Dictionary = {}  # produce name -> count
	var watered: int = 0
	var tended: int = 0
	var capacity: int = workers * get_plots_per_farmhand()
	for plot_id: String in FarmManager.get_plot_ids():
		if tended >= capacity:
			break
		if not FarmManager.has_crop(plot_id):
			continue
		tended += 1
		if FarmManager.is_mature(plot_id):
			var crop := FarmManager.harvest(plot_id)
			if crop != null and crop.produce != null:
				StorageManager.stash.add_item(crop.produce, crop.produce_count)
				harvested[crop.produce.name] = int(harvested.get(crop.produce.name, 0)) + crop.produce_count
		if FarmManager.water(plot_id):
			watered += 1
	if watered > 0:
		_last_report.append("Your farmhands watered %d plot%s." % [watered, "" if watered == 1 else "s"])
	for produce_name: String in harvested:
		_last_report.append("Brought %d %s to the stash." % [int(harvested[produce_name]), produce_name])

## Deposit a per-worker haul from a table into the stash (foragers, woodcutters).
## The smokehouse yield bonus adds to each good.
func _gather(workers: int, table: Dictionary, verb: String) -> void:
	var bonus: int = get_yield_bonus()
	for path: String in table:
		var item := load(path) as Item
		if item == null:
			continue
		var amount: int = (int(table[path]) + bonus) * workers
		StorageManager.stash.add_item(item, amount)
		_last_report.append("%s %d %s." % [verb, amount, item.name])

## Cooks turn stash produce into Camp Stew. Each cook makes up to STEWS_PER_COOK,
## each consuming PRODUCE_PER_STEW units of any COOK_PRODUCE on hand.
func _cooks_prepare(workers: int) -> void:
	var stew := load(STEW_PATH) as Item
	if stew == null:
		return
	var made: int = 0
	var budget: int = workers * STEWS_PER_COOK
	while made < budget:
		var needed: int = PRODUCE_PER_STEW
		# Spend any produce on hand toward this stew.
		for pid: String in COOK_PRODUCE:
			if needed <= 0:
				break
			var have: int = StorageManager.stash.count_of(StringName(pid))
			var take: int = mini(have, needed)
			if take > 0 and StorageManager.stash.consume_items(StringName(pid), take):
				needed -= take
		if needed > 0:
			# Not enough produce left; refund nothing was over-taken (take==have).
			break
		StorageManager.stash.add_item(stew, 1)
		made += 1
	if made > 0:
		_last_report.append("Cooked %d %s." % [made, stew.name])

# --- New game ---------------------------------------------------------------

func reset() -> void:
	_members.clear()
	_owned.clear()
	_last_report = []
	roster_changed.emit()
	upgrades_changed.emit()

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "camp"

func save_state() -> Dictionary:
	return {
		"members": _members.duplicate(true),
		"owned": _owned.keys(),
		"report": _last_report.duplicate(),
	}

func load_state(data: Dictionary) -> void:
	_members.clear()
	var saved: Dictionary = data.get("members", {})
	for key: String in saved:
		var m: Dictionary = saved[key]
		_members[key] = {
			"name": String(m.get("name", "")),
			"role": String(m.get("role", "")),
			"active": bool(m.get("active", true)),
		}
	_owned.clear()
	for id: Variant in data.get("owned", []):
		_owned[StringName(id)] = true
	_last_report = Array(data.get("report", []))
	roster_changed.emit()
	upgrades_changed.emit()
