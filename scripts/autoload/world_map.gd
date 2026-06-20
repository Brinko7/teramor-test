extends Node

## Autoload `WorldMap`. Registry of the game's named locations plus which the
## player has discovered and where they currently are. Loads every WorldLocation
## .tres under res://resources/world/locations/ at startup, so adding a place is
## "author one .tres". Implements the SaveManager "persistent" contract.

signal location_discovered(location_id: StringName)
signal current_changed(location_id: StringName)

const LOCATIONS_DIR := "res://resources/world/locations/"

## Human-readable kingdom/region names + the order they read on the map, from the
## safe home region outward to the deep frontier. Regions absent here fall back to
## their raw id and sort last.
const REGION_NAMES := {
	&"hollenmark": "The Hollenmark — Third Kingdom",
	&"plint": "Kingdom of Plint",
	&"terakin": "Terakin",
	&"cursed_wilds": "The Cursed Wilds",
}
const REGION_ORDER: Array[StringName] = [&"hollenmark", &"plint", &"terakin", &"cursed_wilds"]

## id -> WorldLocation
var _locations: Dictionary = {}
## id -> true
var _discovered: Dictionary = {}
## Where the player currently is (&"" when in transit / a wild area).
var _current_id: StringName = &""
## Id a journey/fast-travel has committed to, so a shared destination scene (e.g.
## the town template) can tag itself as the right place on arrival. Consumed once.
var _pending_arrival: StringName = &""

func _ready() -> void:
	add_to_group("persistent")
	_load_locations()
	_seed_defaults()

func _load_locations() -> void:
	var dir := DirAccess.open(LOCATIONS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var loc := load(LOCATIONS_DIR + clean) as WorldLocation
				if loc != null and loc.id != &"":
					_locations[loc.id] = loc
		file_name = dir.get_next()
	dir.list_dir_end()

func _seed_defaults() -> void:
	for id: Variant in _locations.keys():
		if (_locations[id] as WorldLocation).discovered_by_default:
			_discovered[id] = true

# --- Queries ----------------------------------------------------------------

func get_location(location_id: StringName) -> WorldLocation:
	return _locations.get(location_id, null)

func is_discovered(location_id: StringName) -> bool:
	return bool(_discovered.get(location_id, false))

func is_rumored(location_id: StringName) -> bool:
	var loc := get_location(location_id)
	return loc != null and loc.rumored and not is_discovered(location_id)

func get_current() -> StringName:
	return _current_id

## Discovered locations the player can currently fast-travel to (everything
## discovered except where they already are).
func get_travel_options() -> Array:
	var out: Array = []
	for id: Variant in _locations.keys():
		if is_discovered(id) and id != _current_id:
			out.append(_locations[id])
	return out

## Every location the world surfaces on the map — discovered places plus rumored
## ones (named distant goals) — grouped by region in REGION_ORDER. Returns an
## ordered Array of { region: StringName, name: String, locations: Array }.
func get_map_regions() -> Array:
	var buckets: Dictionary = {}  # region -> Array[WorldLocation]
	for id: Variant in _locations.keys():
		var loc := _locations[id] as WorldLocation
		if not (is_discovered(id) or loc.rumored):
			continue
		var region: StringName = loc.region
		if not buckets.has(region):
			buckets[region] = []
		buckets[region].append(loc)
	var ordered: Array = []
	var seen: Dictionary = {}
	for region: StringName in REGION_ORDER:
		if buckets.has(region):
			ordered.append(_region_entry(region, buckets[region]))
			seen[region] = true
	for region: Variant in buckets.keys():
		if not seen.has(region):
			ordered.append(_region_entry(region, buckets[region]))
	return ordered

func _region_entry(region: StringName, locations: Array) -> Dictionary:
	locations.sort_custom(func(a: WorldLocation, b: WorldLocation) -> bool: return a.tier < b.tier)
	return {
		"region": region,
		"name": String(REGION_NAMES.get(region, String(region) if region != &"" else "The Wilds")),
		"locations": locations,
	}

# --- Mutations --------------------------------------------------------------

func discover(location_id: StringName) -> void:
	if not _locations.has(location_id) or _discovered.has(location_id):
		return
	_discovered[location_id] = true
	location_discovered.emit(location_id)

func set_current(location_id: StringName) -> void:
	_current_id = location_id
	current_changed.emit(location_id)

## Commit the place a journey/fast-travel is heading to, before the scene swaps.
## A destination scene that can represent more than one location (the town
## template) reads this on load via claim_arrival so it tags itself correctly.
func stage_arrival(location_id: StringName) -> void:
	_pending_arrival = location_id

## Called by a location scene's root on load: returns the staged arrival id (if a
## journey committed one) else `fallback` — its own canonical id. Discovers and
## marks it current. Consumes the staged value so the next plain transition uses
## its fallback.
func claim_arrival(fallback: StringName) -> StringName:
	var id: StringName = _pending_arrival if _pending_arrival != &"" else fallback
	_pending_arrival = &""
	discover(id)
	set_current(id)
	return id

func reset() -> void:
	_discovered.clear()
	_current_id = &""
	_seed_defaults()

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "world_map"

func save_state() -> Dictionary:
	var discovered_out: Array = []
	for id: Variant in _discovered.keys():
		discovered_out.append(String(id))
	return {"discovered": discovered_out, "current": String(_current_id)}

func load_state(data: Dictionary) -> void:
	_discovered.clear()
	for id in data.get("discovered", []):
		_discovered[StringName(id)] = true
	_seed_defaults()
	_current_id = StringName(data.get("current", ""))
	current_changed.emit(_current_id)
