extends Node2D
class_name AbilityNova

## An instant area strike centred on the caster. On setup it damages every enemy
## within `radius` (applying an optional status) via a group + distance scan —
## no physics timing to wait on — then plays an expanding, fading ring before
## freeing itself.

const SPRITE_SIZE := 32.0

@onready var _sprite: Sprite2D = $Sprite2D

func setup(dmg: int, radius: float, tint: Color,
		s_kind: int = 0, s_power: int = 0, s_dur: float = 0.0, s_mag: float = 1.0) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_damage"):
			continue
		var e2d := enemy as Node2D
		if e2d == null:
			continue
		if global_position.distance_to(e2d.global_position) <= radius:
			var push: Vector2 = (e2d.global_position - global_position).normalized() * 150.0
			enemy.take_damage(dmg, push)
			StatusEffect.apply(enemy, s_kind, s_power, s_dur, s_mag)
	_play(radius, tint)

func _play(radius: float, tint: Color) -> void:
	if _sprite == null:
		_sprite = $Sprite2D
	_sprite.modulate = tint
	var target_scale: float = (radius * 2.0) / SPRITE_SIZE
	_sprite.scale = Vector2.ONE * (target_scale * 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector2.ONE * target_scale, 0.25)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)
