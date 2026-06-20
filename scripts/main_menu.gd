extends Control

## Title screen. New Game starts a fresh run; Continue is enabled only when a
## save file exists and restores it; Quit exits. All flow goes through
## GameManager so scene-swap logic lives in one place.

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = $Center/VBox/NewGameButton

func _ready() -> void:
	# Returning here from a paused game-over screen must leave the tree running.
	get_tree().paused = false
	MusicManager.enter_zone(&"title")
	continue_button.disabled = not SaveManager.has_save()
	# Focus a sensible default so keyboard/gamepad users can navigate the menu.
	if continue_button.disabled:
		new_game_button.grab_focus()
	else:
		continue_button.grab_focus()

func _on_new_game_pressed() -> void:
	GameManager.new_game()

func _on_continue_pressed() -> void:
	GameManager.continue_game()

func _on_quit_pressed() -> void:
	get_tree().quit()
