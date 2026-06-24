extends Area2D
class_name Projectile

## A flying arrow. Travels in a fixed direction, damages the first enemy it
## hits, and despawns on hit or after travelling its max range.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 220.0
var damage: int = 4
var max_range: float = 160.0

var _on_hit_kind: int = 0
var _on_hit_power: int = 0
var _on_hit_duration: float = 0.0
var _on_hit_chance: float = 0.0
var _on_hit_magnitude: float = 1.0

var _travelled: float = 0.0

## Carry the firing weapon's on-hit status onto the arrow.
func set_on_hit(kind: int, power: int, duration: float, chance: float, magnitude: float) -> void:
	_on_hit_kind = kind
	_on_hit_power = power
	_on_hit_duration = duration
	_on_hit_chance = chance
	_on_hit_magnitude = magnitude

func setup(dir: Vector2, dmg: int, spd: float, rng: float) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	max_range = rng
	rotation = direction.angle()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step: float = speed * delta
	position += direction * step
	_travelled += step
	if _travelled >= max_range:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, direction * 110.0, true)
		if _on_hit_kind != 0 and _on_hit_chance > 0.0:
			var chance: float = _on_hit_chance
			if "status_resist" in body:
				chance *= (1.0 - clampf(body.status_resist, 0.0, 0.95))
			if randf() <= chance:
				StatusEffect.apply(body, _on_hit_kind, _on_hit_power, _on_hit_duration, _on_hit_magnitude)
		queue_free()
