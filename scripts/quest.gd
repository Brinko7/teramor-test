extends Resource
class_name Quest

## Data describing a single quest. A quest holds one or more QuestObjectives, all
## of which must be met to complete it. KILL/COLLECT objectives advance from the
## Events bus; STORY objectives are advanced by the Story system. Rewards may grant
## XP, coin and/or an item stack.
##
## Back-compat: older quests authored before multi-objective support set the flat
## `objective`/`target_id`/`required_count` fields instead of `objectives`. When
## `objectives` is empty, `get_objectives()` synthesizes a single objective from
## those flat fields, so existing .tres files keep working unchanged.

## Legacy single-objective kind (mirrors QuestObjective.Kind values).
enum Objective { KILL, COLLECT, STORY }

## Grouping used by the player menu's Quests tab.
enum Category { MAIN, CONTRACT, RESCUE, TASK }

@export var id: StringName = &""
@export var title: String = "Quest"
@export_multiline var description: String = ""
@export var category: Category = Category.TASK

## Preferred: the list of objectives. If left empty, the legacy flat fields below
## are used to synthesize a single objective.
@export var objectives: Array[QuestObjective] = []

## When true, meeting every objective makes the quest "ready" rather than
## completing it; the player must turn it in to the NPC named by `giver_id`
## (an NpcData id) to claim the rewards.
@export var requires_turn_in: bool = false
@export var giver_id: StringName = &""

## --- Legacy single-objective fields (used only when `objectives` is empty) ----
@export var objective: Objective = Objective.KILL
@export var target_id: StringName = &""
@export var required_count: int = 1

## --- Rewards ----------------------------------------------------------------
@export var reward_xp: int = 0
@export var reward_coin: int = 0
@export var reward_item: Item = null
@export var reward_item_count: int = 1

## Repeatable contracts (e.g. monster bounties) may be accepted again after they
## are turned in; QuestManager never marks them permanently completed.
@export var repeatable: bool = false

## The resolved objective list: the authored array, or a single objective
## synthesized from the legacy flat fields.
func get_objectives() -> Array:
	if not objectives.is_empty():
		return objectives
	var o := QuestObjective.new()
	# Objective and QuestObjective.Kind share the same int values (KILL/COLLECT/STORY).
	o.kind = objective
	o.target_id = target_id
	o.required_count = required_count
	return [o]
