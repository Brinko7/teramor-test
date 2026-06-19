extends Node

## Autoload `WorldMap`. Registry of the game's named locations plus which the
## player has discovered and where they currently are. Loads every WorldLocation
## .tres under res://resources/world/locations/ at startup, so adding a place is
## "author one .tres". Implements the SaveManager "persistent" contract.

signal location_discovered(location_id: StringName)
signal current_changed(location_id: StringName)

const LOCATIONS_DIR := "res://resources/world/locations/"

## id -> WorldLocation
var _locations: Dictionary = {}
## id -> true
var _discovered: Dictionary = {}
## Where the player currently is (&"" when in transit / a wild area).
var _current_id: StringName = &""

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

# --- Mutations --------------------------------------------------------------

func discover(location_id: StringName) -> void:
	if not _locations.has(location_id) or _discovered.has(location_id):
		return
	_discovered[location_id] = true
	location_discovered.emit(location_id)

func set_current(location_id: StringName) -> void:
	_current_id = location_id
	current_changed.emit(location_id)

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
