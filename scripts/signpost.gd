extends Area2D
class_name Signpost

## A wooden trail signpost carrying a short line of DIEGETIC, in-world text —
## carved-board flavor a villager would actually write ("The Deepwood",
## "Danger ahead", "To Cleeve's Landing"). Never gamey labels like a tier number
## or a green/amber/red code; let the words carry the meaning.
##
## The post shows NO permanent floating text: walk up and press interact to READ
## it, and the carved line appears in the dialogue box (like talking to an NPC).
## Set `text` on the instance; a blank post stays plain scenery and isn't readable.
## It sits on the interactable collision layer (32) with no mask, so the player's
## interact probe can find it but it never blocks movement.

@export_multiline var text: String = ""

func _ready() -> void:
	# Only posts that actually carry words are readable; blank posts are scenery.
	if not text.strip_edges().is_empty():
		add_to_group("interactable")

## Player pressed interact while in range: surface the carved line in the box.
func interact(_player) -> void:
	var line := text.strip_edges()
	if line.is_empty():
		return
	UIManager.dialogue.start([line])
