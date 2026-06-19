extends Node2D

## A floating combat damage number. Spawned by CombatFX at the hit location; it
## drifts up, fades, and frees itself. Colour reflects who got hit.

@onready var _label: Label = $Label

func setup(amount: int, to_enemy: bool) -> void:
	if _label == null:
		_label = $Label
	_label.text = str(amount)
	var settings := LabelSettings.new()
	settings.font_size = 11 if to_enemy else 12
	settings.font_color = Color(0.98, 0.92, 0.55) if to_enemy else Color(0.95, 0.4, 0.4)
	settings.outline_size = 3
	settings.outline_color = Color(0, 0, 0, 0.85)
	_label.label_settings = settings

func _ready() -> void:
	z_index = 100
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 18.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.15)
	# A little pop on spawn.
	scale = Vector2(0.6, 0.6)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(queue_free)
