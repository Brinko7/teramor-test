extends Area2D
class_name Projectile

## A flying arrow. Travels in a fixed direction, damages the first enemy it
## hits, and despawns on hit or after travelling its max range.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 220.0
var damage: int = 4
var max_range: float = 160.0

var _travelled: float = 0.0

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
		queue_free()
