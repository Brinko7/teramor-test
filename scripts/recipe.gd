extends Resource
class_name Recipe

## A crafting recipe: consumes ingredient item ids/counts and produces a result
## item stack. Ingredients are modeled as two parallel typed arrays so the data
## is editable in the inspector and stays JSON/tres friendly.

@export var id: StringName = &""
@export var result: Item = null
@export var result_count: int = 1

## Parallel arrays: ingredient_ids[i] is required in quantity ingredient_counts[i].
@export var ingredient_ids: Array[StringName] = []
@export var ingredient_counts: Array[int] = []

## Returns the ingredient list as an Array of {item_id, count} dictionaries,
## guarding against mismatched array lengths.
func get_ingredients() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = mini(ingredient_ids.size(), ingredient_counts.size())
	for i in range(n):
		out.append({"item_id": ingredient_ids[i], "count": ingredient_counts[i]})
	return out
