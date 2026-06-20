extends Node

## Autoload `TimeManager`. Stardew-style clock: in-game minutes advance in
## discrete 10-minute steps as real time passes, wrapping into a day counter.
## Other systems (NPC schedules, farming growth, the clock HUD, day/night tint)
## react to its signals rather than polling. Time only advances while the player
## is in a gameplay scene and the tree isn't paused (open menus freeze the clock).
##
## Implements the SaveManager "persistent" contract.

signal time_changed(minutes: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal period_changed(period: int)
signal season_changed(season: int)
signal exhausted()

## Coarse parts of the day, used for the day/night tint and NPC schedules.
enum Period { MORNING, AFTERNOON, EVENING, NIGHT }

## The calendar. Four seasons of DAYS_PER_SEASON days each make a year. Season,
## day-of-season and year are *derived* from the running day counter (1-based),
## so the calendar needs nothing new in the save file — the day already persists.
enum Season { SPRING, SUMMER, AUTUMN, WINTER }
const DAYS_PER_SEASON := 28
const SEASONS_PER_YEAR := 4
const DAYS_PER_YEAR := DAYS_PER_SEASON * SEASONS_PER_YEAR
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
## Lower-case ids used by content (CropData.seasons, Festival.season).
const SEASON_IDS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

## A fresh day starts at 06:00; the player collapses at 02:00 (26:00) the next
## morning if still awake.
const DAY_START := 6 * 60     # 360  (06:00)
const DAY_END := 26 * 60      # 1560 (02:00 next day)

## In-game minutes advanced per tick, and the real seconds between ticks
## (~7 real seconds per 10 in-game minutes, matching Stardew's pace).
const STEP_MINUTES := 10
const REAL_SECONDS_PER_GAME_MINUTE := 0.7
const SECONDS_PER_STEP := REAL_SECONDS_PER_GAME_MINUTE * STEP_MINUTES

var _minutes: int = DAY_START
var _day: int = 1
var _accum: float = 0.0
var _period: int = Period.MORNING
var _season: int = Season.SPRING
var _exhausted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("persistent")
	_period = _compute_period(_minutes)
	_season = _compute_season(_day)

func _process(delta: float) -> void:
	# Only run the clock inside a gameplay scene (a player exists).
	if get_tree().get_first_node_in_group("player") == null:
		return
	if _minutes >= DAY_END:
		_flag_exhausted()
		return
	_accum += delta
	while _accum >= SECONDS_PER_STEP:
		_accum -= SECONDS_PER_STEP
		_step()

func _step() -> void:
	var prev_hour: int = _minutes / 60
	_minutes = mini(_minutes + STEP_MINUTES, DAY_END)
	time_changed.emit(_minutes)
	var hour: int = _minutes / 60
	if hour != prev_hour:
		hour_changed.emit(hour)
	_update_period()
	if _minutes >= DAY_END:
		_flag_exhausted()

func _flag_exhausted() -> void:
	if not _exhausted:
		_exhausted = true
		exhausted.emit()

# --- Queries ----------------------------------------------------------------

func get_day() -> int:
	return _day

func get_time_minutes() -> int:
	return _minutes

func get_hour() -> int:
	return _minutes / 60

func get_minute() -> int:
	return _minutes % 60

func get_period() -> int:
	return _period

func is_night() -> bool:
	return _period == Period.NIGHT

# --- Calendar (season / day-of-season / year, all derived from the day) ------

func get_season() -> int:
	return _compute_season(_day)

## 1-based day within the current season (1..DAYS_PER_SEASON).
func get_day_of_season() -> int:
	return ((maxi(1, _day) - 1) % DAYS_PER_SEASON) + 1

## 1-based year (day 1 is Year 1).
func get_year() -> int:
	return ((maxi(1, _day) - 1) / DAYS_PER_YEAR) + 1

func get_season_name() -> String:
	return season_name(get_season())

func season_name(season: int) -> String:
	return SEASON_NAMES[clampi(season, 0, SEASON_NAMES.size() - 1)]

## Lower-case season id (content matches against this; see CropData/Festival).
func season_id(season: int) -> StringName:
	return SEASON_IDS[clampi(season, 0, SEASON_IDS.size() - 1)]

func get_season_id() -> StringName:
	return season_id(get_season())

## "Spring 5" — gains ", Year 2" once past the first year.
func format_date() -> String:
	var label: String = "%s %d" % [get_season_name(), get_day_of_season()]
	var yr: int = get_year()
	if yr > 1:
		label += ", Year %d" % yr
	return label

func _compute_season(day: int) -> int:
	return ((maxi(1, day) - 1) / DAYS_PER_SEASON) % SEASONS_PER_YEAR

## Re-derive the cached season from the day and announce a crossing.
func _update_season() -> void:
	var s: int = _compute_season(_day)
	if s != _season:
		_season = s
		season_changed.emit(_season)

## "7:30 AM" style 12-hour clock string.
func format_time() -> String:
	var h24: int = (_minutes / 60) % 24
	var m: int = _minutes % 60
	var ampm: String = "AM" if h24 < 12 else "PM"
	var h12: int = h24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, ampm]

func _compute_period(minutes: int) -> int:
	var h: int = (minutes / 60) % 24
	if h >= 6 and h < 12:
		return Period.MORNING
	if h >= 12 and h < 18:
		return Period.AFTERNOON
	if h >= 18 and h < 21:
		return Period.EVENING
	return Period.NIGHT

func _update_period() -> void:
	var p: int = _compute_period(_minutes)
	if p != _period:
		_period = p
		period_changed.emit(_period)

# --- Day advance ------------------------------------------------------------

## Advance to 06:00 of the next day. The sleep/bed handler calls this and then
## runs its own restore/save side-effects; day-advance consumers (crops, etc.)
## react to `day_changed`.
func sleep() -> void:
	_day += 1
	_minutes = DAY_START
	_accum = 0.0
	_exhausted = false
	day_changed.emit(_day)
	time_changed.emit(_minutes)
	_update_period()
	_update_season()

## Reset to Day 1, 06:00 for a brand-new game.
func reset() -> void:
	_day = 1
	_minutes = DAY_START
	_accum = 0.0
	_exhausted = false
	_period = _compute_period(_minutes)
	_season = _compute_season(_day)
	day_changed.emit(_day)
	time_changed.emit(_minutes)
	period_changed.emit(_period)
	season_changed.emit(_season)

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "time"

func save_state() -> Dictionary:
	return {"day": _day, "minutes": _minutes}

func load_state(data: Dictionary) -> void:
	_day = int(data.get("day", 1))
	_minutes = int(data.get("minutes", DAY_START))
	_accum = 0.0
	_exhausted = _minutes >= DAY_END
	_period = _compute_period(_minutes)
	_season = _compute_season(_day)
	day_changed.emit(_day)
	time_changed.emit(_minutes)
	period_changed.emit(_period)
	season_changed.emit(_season)
