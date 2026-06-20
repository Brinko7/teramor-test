extends Resource
class_name Festival

## One authored calendar day the player can plan around. SeasonManager loads every
## Festival .tres under resources/festivals/ and, when the date naturally rolls
## over to its season + day, pops a banner (and optionally sets a Story flag). A
## festival is pure content — author a .tres, no code.

@export var id: StringName = &""
@export var display_name: String = "Festival"

## When it lands: a TimeManager season id (&"spring"/&"summer"/&"autumn"/&"winter")
## and a 1-based day within that season (1..TimeManager.DAYS_PER_SEASON). It
## recurs every year on this date.
@export var season: StringName = &"spring"
@export var day: int = 1

## Banner shown on the morning it arrives.
@export var title: String = ""
@export var subtitle: String = ""

## Optional Story flag set the first time the festival fires (for quests/dialogue).
@export var set_flag: StringName = &""

func matches(season_id: StringName, day_of_season: int) -> bool:
	return season == season_id and day == day_of_season
