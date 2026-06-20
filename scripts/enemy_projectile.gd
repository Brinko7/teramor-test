extends Area2D
class_name EnemyProjectile

## A hostile projectile fired by ranged enemies (e.g. the archer). Travels in a
## fixed direction, damages the first faction-hostile thing it hits (the player
## or a rival-faction enemy), and despawns on hit or after travelling its max
## range. Passes harmlessly through allies of the shooter.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 160.0
var damage: int = 2
var max_range: float = 220.0
## Faction of the enemy that fired this shot; decides what it can hit.
var source_faction: StringName = &"bandit"

var _travelled: float = 0.0

func setup(dir: Vector2, dmg: int, spd: float, rng: float, faction: StringName = &"bandit") -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	max_range = rng
	source_faction = faction
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
	if not body.has_method("take_damage"):
		return
	var hits: bool = false
	if body.is_in_group("player"):
		hits = Faction.hostile(source_faction, Faction.PLAYER)
	elif body is Enemy:
		hits = Faction.hostile(source_faction, (body as Enemy).faction)
	if hits:
		body.take_damage(damage)
		queue_free()
