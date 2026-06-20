extends Node

## Autoload `FarmManager`. Owns the state of every farm plot in the game,
## keyed by a globally-unique plot id, so growth keeps advancing no matter which
## scene is loaded and the data survives a save/load round-trip (SaveManager
## rebuilds its snapshot from nodes in the *current* tree, so plot state can't
## live on a scene-local node).
##
## FarmPlot nodes are thin views: they read state from here and redraw when
## `plot_changed` fires. Growth ticks once per in-game day via TimeManager.
##
## Per-plot record: {tilled: bool, watered: bool, crop: String (CropData
## resource_path, "" if empty), days: int}.
##
## Implements the SaveManager "persistent" contract.

signal plot_changed(plot_id: String)

var _plots: Dictionary = {}

func _ready() -> void:
	add_to_group("persistent")
	TimeManager.day_changed.connect(_on_day_changed)

# --- Day advance ------------------------------------------------------------

## Each new day, watered crops grow one step (capped at maturity) and the soil
## dries out, so the player must re-water daily. Unwatered crops simply don't
## advance, and a crop out of its season pauses — there is no withering, to keep
## the loop forgiving.
func _on_day_changed(_day: int) -> void:
	var season: StringName = TimeManager.get_season_id()
	for plot_id: String in _plots:
		var p: Dictionary = _plots[plot_id]
		if String(p["crop"]) != "" and bool(p["watered"]):
			var crop := load(String(p["crop"])) as CropData
			if crop != null and crop.grows_in(season) and not crop.is_mature(int(p["days"])):
				p["days"] = int(p["days"]) + 1
		p["watered"] = false
	for plot_id: String in _plots:
		plot_changed.emit(plot_id)

# --- Actions ----------------------------------------------------------------

func till(plot_id: String) -> bool:
	var p: Dictionary = _ensure(plot_id)
	if bool(p["tilled"]):
		return false
	p["tilled"] = true
	plot_changed.emit(plot_id)
	return true

func plant(plot_id: String, crop: CropData) -> bool:
	if crop == null:
		return false
	var p: Dictionary = _ensure(plot_id)
	if not bool(p["tilled"]) or String(p["crop"]) != "":
		return false
	p["crop"] = crop.resource_path
	p["days"] = 0
	p["watered"] = false
	plot_changed.emit(plot_id)
	return true

func water(plot_id: String) -> bool:
	if not _plots.has(plot_id):
		return false
	var p: Dictionary = _plots[plot_id]
	if String(p["crop"]) == "" or bool(p["watered"]):
		return false
	p["watered"] = true
	plot_changed.emit(plot_id)
	return true

## Harvest a mature crop. Returns the CropData (so the caller can grant produce)
## or null if there's nothing ready. Regrowing crops rewind; others clear the
## plot but leave the soil tilled.
func harvest(plot_id: String) -> CropData:
	if not _plots.has(plot_id):
		return null
	var p: Dictionary = _plots[plot_id]
	if String(p["crop"]) == "":
		return null
	var crop := load(String(p["crop"])) as CropData
	if crop == null or not crop.is_mature(int(p["days"])):
		return null
	if crop.regrows:
		p["days"] = maxi(0, crop.days_to_mature() - maxi(1, crop.regrow_days))
	else:
		p["crop"] = ""
		p["days"] = 0
	p["watered"] = false
	plot_changed.emit(plot_id)
	return crop

# --- Queries ----------------------------------------------------------------

## Every plot that has any recorded state (planted, tilled, or watered at least
## once). Used by CampManager so farmhands know which plots exist to tend.
func get_plot_ids() -> Array:
	return _plots.keys()

func get_state(plot_id: String) -> Dictionary:
	return _plots.get(plot_id, {})

func is_tilled(plot_id: String) -> bool:
	return bool(_plots.get(plot_id, {}).get("tilled", false))

func is_watered(plot_id: String) -> bool:
	return bool(_plots.get(plot_id, {}).get("watered", false))

func has_crop(plot_id: String) -> bool:
	return String(_plots.get(plot_id, {}).get("crop", "")) != ""

func get_crop(plot_id: String) -> CropData:
	var path: String = String(_plots.get(plot_id, {}).get("crop", ""))
	if path == "":
		return null
	return load(path) as CropData

func get_days(plot_id: String) -> int:
	return int(_plots.get(plot_id, {}).get("days", 0))

func is_mature(plot_id: String) -> bool:
	var crop := get_crop(plot_id)
	if crop == null:
		return false
	return crop.is_mature(get_days(plot_id))

func _ensure(plot_id: String) -> Dictionary:
	if not _plots.has(plot_id):
		_plots[plot_id] = {"tilled": false, "watered": false, "crop": "", "days": 0}
	return _plots[plot_id]

# --- New game ---------------------------------------------------------------

func reset() -> void:
	_plots.clear()

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "farm"

func save_state() -> Dictionary:
	return {"plots": _plots.duplicate(true)}

func load_state(data: Dictionary) -> void:
	_plots.clear()
	var saved: Dictionary = data.get("plots", {})
	for plot_id: String in saved:
		var p: Dictionary = saved[plot_id]
		_plots[plot_id] = {
			"tilled": bool(p.get("tilled", false)),
			"watered": bool(p.get("watered", false)),
			"crop": String(p.get("crop", "")),
			"days": int(p.get("days", 0)),
		}
	for plot_id: String in _plots:
		plot_changed.emit(plot_id)
