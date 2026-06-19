extends Resource
class_name Quest

## Data describing a single quest. Objectives are either KILL (slay N targets)
## or COLLECT (gather N of an item, matched against Inventory item ids via the
## Events.item_collected signal). Rewards may grant XP and/or an item stack.

## KILL/COLLECT advance automatically from the Events bus. STORY quests are
## narrative beats advanced by the Story system; QuestManager never auto-advances
## them.
enum Objective { KILL, COLLECT, STORY }

@export var id: StringName = &""
@export var title: String = "Quest"
@export_multiline var description: String = ""

@export var objective: Objective = Objective.KILL
## For COLLECT: the item id to gather. For KILL: an optional enemy id (matched
## against Events.enemy_killed). Leave empty to count any kill of any creature.
@export var target_id: StringName = &""
@export var required_count: int = 1

@export var reward_xp: int = 0
@export var reward_coin: int = 0
@export var reward_item: Item = null
@export var reward_item_count: int = 1

## Repeatable contracts (e.g. monster bounties) may be accepted again after they
## are turned in; QuestManager never marks them permanently completed.
@export var repeatable: bool = false
