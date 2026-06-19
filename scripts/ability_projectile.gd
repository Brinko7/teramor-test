extends Area2D
class_name AbilityProjectile

## An elemental bolt. Travels in a fixed direction, damages the first enemy it
## hits (applying an optional status), and despawns on hit or at max range.
## Mirrors the arrow Projectile but carries an element tint + status payload.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var damage: int = 8
var max_range: float = 160.0
var status_kind: int = 0
var status_power: int = 0
var status_duration: float = 0.0
var status_magnitude: float = 1.0

var _travelled: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D

func setup(dir: Vector2, dmg: int, spd: float, rng: float, tint: Color,
		s_kind: int = 0, s_power: int = 0, s_dur: float = 0.0, s_mag: float = 1.0) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	max_range = rng
	status_kind = s_kind
	status_power = s_power
	status_duration = s_dur
	status_magnitude = s_mag
	rotation = direction.angle()
	if _sprite == null:
		_sprite = $Sprite2D
	_sprite.modulate = tint

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
		body.take_damage(damage)
		StatusEffect.apply(body, status_kind, status_power, status_duration, status_magnitude)
		queue_free()
