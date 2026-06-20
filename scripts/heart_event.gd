extends Resource
class_name HeartEvent

## An authored relationship cutscene that fires once, when an NPC's friendship
## crosses `hearts`. Pure data: HeartEventManager loads the catalog from
## resources/heart_events/, watches Relationships, and plays the lines when the
## threshold is reached (after any conversation in progress closes).
##
## Authoring a heart event is "drop one .tres" — the payoff that turns a rising
## friendship number into a moment.

@export var id: StringName = &""
@export var npc_id: StringName = &""
@export var hearts: int = 4
@export var speaker: String = ""
@export_multiline var lines: PackedStringArray = PackedStringArray()

## Optional Story flag set when the event plays (one-shot narrative hook).
@export var set_flag: StringName = &""

## Optional keepsake the friend leaves in the camp stash: item resource path + count.
@export var reward_item: String = ""
@export var reward_count: int = 1
