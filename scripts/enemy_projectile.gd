extends Area2D
class_name EnemyProjectile

## A hostile projectile fired by ranged enemies (e.g. the archer). Travels in a
## fixed direction, damages the player on contact, and despawns on hit or after
## travelling its max range. Mirrors the player's Projectile but targets the
## "player" group instead of "enemy".

var direction: Vector2 = Vector2.RIGHT
var speed: float = 160.0
var damage: int = 2
var max_range: float = 220.0

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
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
