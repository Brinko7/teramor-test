extends Node

## Autoload `WeatherManager`. Each day has a mood. Like the season, the weather is
## **derived from the day counter** (a deterministic, season-weighted roll), so it
## costs the save file nothing and a load reproduces the same sky. Systems react to
## `weather_changed` rather than polling: WeatherFX paints it, day_night dims for it,
## and FarmManager lets the rain water the crops.
##
## Registered after SeasonManager (it reads the season to weight the roll).

enum Weather { CLEAR, RAIN, FOG, SNOW }

const NAMES := {Weather.CLEAR: "Clear", Weather.RAIN: "Rain", Weather.FOG: "Fog", Weather.SNOW: "Snow"}
const IDS := {Weather.CLEAR: &"clear", Weather.RAIN: &"rain", Weather.FOG: &"fog", Weather.SNOW: &"snow"}

## Per-season [weather, weight] tables — the climate of each season. Winter trades
## rain for snow; autumn is the foggiest; summer the clearest.
const WEIGHTS := {
	&"spring": [[Weather.CLEAR, 55], [Weather.RAIN, 30], [Weather.FOG, 15]],
	&"summer": [[Weather.CLEAR, 70], [Weather.RAIN, 20], [Weather.FOG, 10]],
	&"autumn": [[Weather.CLEAR, 45], [Weather.RAIN, 30], [Weather.FOG, 25]],
	&"winter": [[Weather.CLEAR, 50], [Weather.SNOW, 40], [Weather.FOG, 10]],
}

signal weather_changed(weather: int)

var _weather: int = Weather.CLEAR

func _ready() -> void:
	_weather = _roll(TimeManager.get_day(), TimeManager.get_season())
	TimeManager.day_changed.connect(_on_day_changed)

func _on_day_changed(_day: int) -> void:
	var w: int = _roll(TimeManager.get_day(), TimeManager.get_season())
	if w != _weather:
		_weather = w
		weather_changed.emit(_weather)

# --- Queries ----------------------------------------------------------------

func get_weather() -> int:
	return _weather

func weather_name() -> String:
	return String(NAMES.get(_weather, "Clear"))

func weather_id() -> StringName:
	return IDS.get(_weather, &"clear")

func is_rainy() -> bool:
	return _weather == Weather.RAIN

func is_snowy() -> bool:
	return _weather == Weather.SNOW

func is_foggy() -> bool:
	return _weather == Weather.FOG

## Precipitation that soaks the soil — rain waters crops for free (snow doesn't).
func waters_crops() -> bool:
	return _weather == Weather.RAIN

# --- Roll -------------------------------------------------------------------

## Deterministic season-weighted pick: the same (day, season) always yields the
## same sky, so weather survives save/load without being stored.
func _roll(day: int, season: int) -> int:
	var season_id: StringName = TimeManager.season_id(season)
	var table: Array = WEIGHTS.get(season_id, WEIGHTS[&"spring"])
	var total: int = 0
	for entry: Array in table:
		total += int(entry[1])
	if total <= 0:
		return Weather.CLEAR
	var pick: int = abs(hash(day * 101 + season)) % total
	var acc: int = 0
	for entry: Array in table:
		acc += int(entry[1])
		if pick < acc:
			return int(entry[0])
	return Weather.CLEAR
