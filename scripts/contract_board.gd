extends Area2D

## A tavern contract board. Implements the shared INTERACT contract (collision
## layer 32, the "interactable" group, plus `interact(player)`). Interacting opens
## a Dialogue menu listing posted monster contracts; accepting one hands it to the
## QuestManager. Contracts are authored per-instance as an Array[Quest] (typically
## the repeatable bounties), so new boards need no new code.

@export var board_title: String = "Contract Board"
@export_multiline var intro_line: String = "Weathered parchment flutters on the board — bounties posted by the townsfolk."
@export var contracts: Array[Quest] = []

func _ready() -> void:
	add_to_group("interactable")

## Called by the player when interacted with.
func interact(_player) -> void:
	var intro: Array = []
	if intro_line != "":
		intro.append({"text": intro_line})
	Dialogue.start_conversation(intro, _build_menu, board_title)

# --- Menu construction ------------------------------------------------------

func _build_menu() -> Dictionary:
	var choices: Array = []
	for quest: Quest in contracts:
		if quest == null:
			continue
		choices.append(_contract_choice(quest))
	if choices.is_empty():
		choices.append({"text": "(nothing posted)", "close": true})
	choices.append({"text": "Leave", "close": true})
	return {"text": "Posted contracts:", "choices": choices}

func _contract_choice(quest: Quest) -> Dictionary:
	if QuestManager.is_active(quest.id):
		var progress: int = QuestManager.get_progress(quest.id)
		return {
			"text": "%s  (%d/%d)" % [quest.title, progress, quest.required_count],
			"then": [{"text": "Still open — %s" % quest.description}],
		}
	return {
		"text": "%s  [%s]" % [quest.title, _reward_text(quest)],
		"effect": _accept.bind(quest),
		"then": [{"text": "Contract accepted. %s" % quest.description}],
	}

func _accept(quest: Quest) -> void:
	QuestManager.start_quest(quest)

func _reward_text(quest: Quest) -> String:
	var parts: Array = []
	if quest.reward_coin > 0:
		parts.append("%d g" % quest.reward_coin)
	if quest.reward_xp > 0:
		parts.append("%d xp" % quest.reward_xp)
	return ", ".join(parts)
