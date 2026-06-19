extends Resource
class_name QuestObjective

## One objective within a Quest. A quest is complete when ALL its objectives are
## met. KILL and COLLECT objectives advance automatically from the Events bus;
## STORY objectives are advanced by the Story system via
## QuestManager.advance_story().

enum Kind { KILL, COLLECT, STORY }

@export var kind: Kind = Kind.KILL
## KILL: enemy id (empty = any creature). COLLECT: item id. STORY: a beat id
## passed to QuestManager.advance_story().
@export var target_id: StringName = &""
@export var required_count: int = 1
## Optional menu/tracker text. Falls back to a generated label when blank.
@export var description: String = ""

## Human-readable one-liner for the menu and the on-screen tracker.
func label() -> String:
	if description != "":
		return description
	match kind:
		Kind.KILL:
			return "Defeat %s" % (String(target_id) if target_id != &"" else "enemies")
		Kind.COLLECT:
			return "Collect %s" % String(target_id)
		_:
			return String(target_id) if target_id != &"" else "Story"
