extends Node

## Autoload `CampManager`. The recruited-camp roster and the chores they do for you.
##
## Befriend a camp member (Relationships hearts) and, once you've reached their
## `recruit_hearts`, recruit them through dialogue. A recruited member takes a daily
## ROLE: a **farmhand** keeps the farm watered and carries the ripe harvest to the
## shared stash; a **forager** walks the treeline and brings back wild goods. Each
## dawn (the in-game day rolls over) the *active* roster does its chores
## automatically, and a short report says what they brought in.
##
## A pure data manager in the FarmManager / Relationships mould: it owns state +
## signals, and the player menu's Camp tab renders the roster + last night's report.
## It connects to `TimeManager.day_changed` in `_ready`, and because this autoload
## is registered **after** FarmManager, its handler runs *after* FarmManager has
## matured the watered crops — so the farmhand harvests what just ripened, then
## re-waters every remaining crop for the next night. That ordering is the whole
## trick to the "they tend the farm while you're away" loop.
##
## Implements the SaveManager "persistent" contract.

signal roster_changed
signal chores_reported(lines: Array)

const ROLE_FARMHAND := &"farmhand"
const ROLE_FORAGER := &"forager"

## How many planted plots a single farmhand can cover in a night. More farmhands
## tend more of the field.
const PLOTS_PER_FARMHAND := 8

## A forager's nightly haul: item resource path -> count per forager. Authored
## here (not a .tres) because it's a fixed game rule — the wild goods the camp's
## treeline offers — not content reskinned per NPC.
const FORAGE_TABLE := {
	"res://resources/items/herb.tres": 2,
	"res://resources/items/wild_mushroom.tres": 1,
	"res://resources/items/wood.tres": 3,
}

# npc_id (String) -> {name: String, role: String, active: bool}
var _members: Dictionary = {}
var _last_report: Array = []

func _ready() -> void:
	add_to_group("persistent")
	TimeManager.day_changed.connect(_on_day_changed)

# --- Roster -----------------------------------------------------------------

## Enlist an NPC. Returns false if already on the roster.
func recruit(npc_id: StringName, display_name: String, role: StringName) -> bool:
	var key: String = String(npc_id)
	if _members.has(key):
		return false
	_members[key] = {"name": display_name, "role": String(role), "active": true}
	roster_changed.emit()
	return true

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

# --- Daily chores -----------------------------------------------------------

func _on_day_changed(_day: int) -> void:
	_last_report = []
	var farmhands: int = 0
	var foragers: int = 0
	for key: String in _members:
		var m: Dictionary = _members[key]
		if not bool(m["active"]):
			continue
		match String(m["role"]):
			"farmhand":
				farmhands += 1
			"forager":
				foragers += 1
	if farmhands > 0:
		_farmhands_tend(farmhands)
	if foragers > 0:
		_foragers_gather(foragers)
	if not _last_report.is_empty():
		chores_reported.emit(_last_report)
		UIManager.notify("The camp stirs", String(_last_report[0]))

## Harvest every ripe crop to the stash, then water every remaining planted crop so
## it grows tonight. Each farmhand covers up to PLOTS_PER_FARMHAND plots.
func _farmhands_tend(workers: int) -> void:
	var harvested: Dictionary = {}  # produce name -> count
	var watered: int = 0
	var tended: int = 0
	var capacity: int = workers * PLOTS_PER_FARMHAND
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

## Deposit each forager's nightly haul of wild goods into the stash.
func _foragers_gather(workers: int) -> void:
	for path: String in FORAGE_TABLE:
		var item := load(path) as Item
		if item == null:
			continue
		var amount: int = int(FORAGE_TABLE[path]) * workers
		StorageManager.stash.add_item(item, amount)
		_last_report.append("Foraged %d %s." % [amount, item.name])

# --- New game ---------------------------------------------------------------

func reset() -> void:
	_members.clear()
	_last_report = []
	roster_changed.emit()

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "camp"

func save_state() -> Dictionary:
	return {"members": _members.duplicate(true), "report": _last_report.duplicate()}

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
	_last_report = Array(data.get("report", []))
	roster_changed.emit()
