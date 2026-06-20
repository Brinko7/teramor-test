extends Node

## Autoload `SeasonManager`. The calendar's announcer: it turns TimeManager's
## derived season/day into player-facing beats — a banner when a new season
## arrives and a banner (plus optional Story flag) on authored festival days.
##
## Season math itself lives in TimeManager (season is derived from the day). This
## manager only *reacts*, like CampManager/HeartEventManager, so it's registered
## after UIManager and can drive the notification banner.
##
## It listens to `TimeManager.day_changed` and acts only on a natural one-day
## advance (the sleep flow). Loads and new-game resets jump the day counter by
## more than one (or back to 1), so they sync state silently — you don't get a
## season/festival toast just for loading a save.

const FESTIVALS_DIR := "res://resources/festivals/"

## Flavour line under each season's arrival banner.
const SEASON_BLURB := {
	&"spring": "Thaw and first green. The soil wakes — time to sow.",
	&"summer": "Long, warm days. The fields run gold.",
	&"autumn": "Amber light and harvest. The year turns inward.",
	&"winter": "Cold and quiet. The ground sleeps; the camp gathers in.",
}

var _festivals: Array = []      # all Festival, load order
var _last_day: int = 1
var _last_season: int = 0

func _ready() -> void:
	_load_festivals()
	_last_day = TimeManager.get_day()
	_last_season = TimeManager.get_season()
	TimeManager.day_changed.connect(_on_day_changed)

func _load_festivals() -> void:
	var dir := DirAccess.open(FESTIVALS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean: String = file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var fest := load(FESTIVALS_DIR + clean) as Festival
				if fest != null and fest.id != &"":
					_festivals.append(fest)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_day_changed(day: int) -> void:
	var natural: bool = day == _last_day + 1   # a real sleep, not a load/reset jump
	var season: int = TimeManager.get_season()
	if natural and season != _last_season:
		_announce_season(season)
	if natural:
		_check_festival()
	_last_day = day
	_last_season = season

func _announce_season(season: int) -> void:
	var name: String = TimeManager.season_name(season)
	var blurb: String = String(SEASON_BLURB.get(TimeManager.season_id(season), ""))
	UIManager.notify(name, blurb)

func _check_festival() -> void:
	var season_id: StringName = TimeManager.get_season_id()
	var dos: int = TimeManager.get_day_of_season()
	for fest: Festival in _festivals:
		if fest.matches(season_id, dos):
			UIManager.notify(fest.title, fest.subtitle)
			if fest.set_flag != &"":
				Story.set_flag(fest.set_flag)

## All loaded festivals (used by the validator / future calendar UI).
func get_festivals() -> Array:
	return _festivals
