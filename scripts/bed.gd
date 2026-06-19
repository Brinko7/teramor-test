extends Area2D

## A bed the player sleeps in to end the day. Implements the shared INTERACT
## contract (collision layer 32, the "interactable" group, plus `interact(player)`).
## Interacting opens a Yes/No prompt; confirming hands off to
## GameManager.sleep_until_morning(), which fades out, advances the clock to the
## next morning, heals the player, and autosaves.

@export_multiline var prompt_line: String = "A bedroll, ready for the night. Sleep until morning?"
@export var speaker_name: String = "Bed"

func _ready() -> void:
	add_to_group("interactable")

func interact(_player) -> void:
	Dialogue.start_conversation([], _build_menu, speaker_name)

func _build_menu() -> Dictionary:
	return {
		"text": prompt_line,
		"choices": [
			{
				"text": "Sleep until morning",
				"effect": _sleep,
				"close": true,
			},
			{"text": "Not yet", "close": true},
		],
	}

func _sleep() -> void:
	GameManager.sleep_until_morning()
