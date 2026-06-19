extends Node

## Autoload `Relationships`. Tracks how close the player is to each NPC.
##
## Friendship is stored as raw points; every `POINTS_PER_HEART` points is one
## heart, up to `MAX_HEARTS`. NPCs the player has spoken to at least once are
## "known" and appear in the player menu's Social tab (see `get_known`). Talking
## and gift-giving are limited per in-game day; `advance_day()` (called by the
## sleep/camp system) resets those limits.
##
## This is a pure data manager — the Social UI lives in the player menu
## (UIManager.menu) and refreshes on the signals below.
## Implements the SaveManager "persistent" contract.

signal points_changed(npc_id: StringName, points: int)
signal hearts_changed(npc_id: StringName, hearts: int)
signal npc_met(npc_id: StringName, display_name: String)

const POINTS_PER_HEART := 100
const MAX_HEARTS := 10
const MAX_POINTS := POINTS_PER_HEART * MAX_HEARTS

## Per-day affinity caps / amounts (Stardew-flavoured).
const TALK_POINTS := 15

## npc_id -> int points
var _points: Dictionary = {}
## npc_id -> display name
var _names: Dictionary = {}
## npc_id -> true if talked to since last day reset
var _talked_today: Dictionary = {}
## npc_id -> true if gifted since last day reset
var _gifted_today: Dictionary = {}
var _day: int = 1

func _ready() -> void:
	add_to_group("persistent")

# --- Queries ----------------------------------------------------------------

func get_points(npc_id: StringName) -> int:
	return int(_points.get(npc_id, 0))

func get_hearts(npc_id: StringName) -> int:
	return get_points(npc_id) / POINTS_PER_HEART

func is_known(npc_id: StringName) -> bool:
	return _names.has(npc_id)

func has_talked_today(npc_id: StringName) -> bool:
	return bool(_talked_today.get(npc_id, false))

func has_gifted_today(npc_id: StringName) -> bool:
	return bool(_gifted_today.get(npc_id, false))

# --- Mutations --------------------------------------------------------------

## Record that the player has met an NPC so it shows up in the Social tab.
func meet(npc_id: StringName, display_name: String) -> void:
	if _names.has(npc_id):
		return
	_names[npc_id] = display_name
	if not _points.has(npc_id):
		_points[npc_id] = 0
	npc_met.emit(npc_id, display_name)

## Add (or subtract) friendship points, clamped to [0, MAX_POINTS]. Emits
## points_changed always and hearts_changed when the heart count crosses.
func add_points(npc_id: StringName, amount: int) -> void:
	var before_hearts: int = get_hearts(npc_id)
	var updated: int = clampi(get_points(npc_id) + amount, 0, MAX_POINTS)
	_points[npc_id] = updated
	points_changed.emit(npc_id, updated)
	var after_hearts: int = updated / POINTS_PER_HEART
	if after_hearts != before_hearts:
		hearts_changed.emit(npc_id, after_hearts)

## Apply the once-per-day talk bonus. Returns true if it was awarded.
func try_talk(npc_id: StringName) -> bool:
	if has_talked_today(npc_id):
		return false
	_talked_today[npc_id] = true
	add_points(npc_id, TALK_POINTS)
	return true

## Mark a gift as given for the day. Caller applies the point change.
func mark_gifted(npc_id: StringName) -> void:
	_gifted_today[npc_id] = true

func advance_day() -> void:
	_day += 1
	_talked_today.clear()
	_gifted_today.clear()

## Wipe all relationship state for a brand-new game.
func reset() -> void:
	_points.clear()
	_names.clear()
	_talked_today.clear()
	_gifted_today.clear()
	_day = 1

func get_day() -> int:
	return _day

## Every NPC the player has met, as an Array of {id, name, hearts}, for the menu's
## Social tab.
func get_known() -> Array:
	var out: Array = []
	for npc_id: Variant in _names.keys():
		out.append({"id": npc_id, "name": String(_names[npc_id]), "hearts": get_hearts(npc_id)})
	return out

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "relationships"

func save_state() -> Dictionary:
	var points_out: Dictionary = {}
	for key: Variant in _points.keys():
		points_out[String(key)] = int(_points[key])
	var names_out: Dictionary = {}
	for key: Variant in _names.keys():
		names_out[String(key)] = String(_names[key])
	return {"points": points_out, "names": names_out, "day": _day}

func load_state(data: Dictionary) -> void:
	_points.clear()
	_names.clear()
	_talked_today.clear()
	_gifted_today.clear()
	var points_in: Dictionary = data.get("points", {})
	for key: Variant in points_in.keys():
		_points[StringName(key)] = int(points_in[key])
	var names_in: Dictionary = data.get("names", {})
	for key: Variant in names_in.keys():
		_names[StringName(key)] = String(names_in[key])
	_day = int(data.get("day", 1))
