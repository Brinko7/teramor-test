extends Resource
class_name CropData

## Data describing one growable crop: its growth stages, how long each takes,
## and what it yields. FarmManager tracks only an integer "days grown" per plot
## and asks this resource which sprite to show and whether it can be harvested,
## so adding a new crop is purely authoring a .tres (no code).

@export var id: StringName = &""
@export var display_name: String = "Crop"

## What a harvest yields, and how many.
@export var produce: Item
@export var produce_count: int = 1

## One texture per growth stage, ordered from just-planted to fully grown.
@export var stage_textures: Array[Texture2D] = []
## Days spent in each stage before advancing to the next. Should hold
## stage_textures.size() - 1 entries (the final stage is mature, no duration).
@export var stage_days: Array[int] = []

## Crops like tomatoes keep producing: harvesting rewinds growth by regrow_days
## instead of clearing the plot.
@export var regrows: bool = false
@export var regrow_days: int = 2

## Total days from planting to first harvest.
func days_to_mature() -> int:
	var total: int = 0
	for d: int in stage_days:
		total += d
	return total

## Growth-stage index for a crop that has grown `days` days, clamped to the
## last available sprite.
func stage_for_days(days: int) -> int:
	var stage: int = 0
	var acc: int = 0
	for i: int in range(stage_days.size()):
		acc += stage_days[i]
		if days >= acc:
			stage = i + 1
		else:
			break
	return clampi(stage, 0, maxi(0, stage_textures.size() - 1))

func texture_for_days(days: int) -> Texture2D:
	if stage_textures.is_empty():
		return null
	return stage_textures[stage_for_days(days)]

func is_mature(days: int) -> bool:
	return days >= days_to_mature()
