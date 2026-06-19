extends CharacterBody2D
class_name Enemy

## Basic bandit enemy and shared base for the other enemy types. Wanders idly,
## chases the player when near, and damages the player on contact. Sprite sheet
## is a 4x4 grid matching the player layout (rows: 0=down, 1=up, 2=left,
## 3=right). Subclasses (wolf, brute, archer) tweak exported stats and may
## override `_decide_input()` for bespoke movement.

@export var speed: float = 45.0
@export var anim_fps: float = 6.0
@export var detect_range: float = 80.0
@export var touch_damage: int = 3
@export var touch_cooldown: float = 1.0
## Experience granted to the player when this enemy dies.
@export var xp_reward: int = 5
## Identifies the creature kind so monster contracts can target it (e.g. a
## "slay 3 wolves" bounty matches only enemies whose id is &"wolf").
@export var enemy_id: StringName = &"bandit"

## Items dropped on death. Each entry rolls independently against loot_chance.
@export var loot_table: Array[Item] = []
@export_range(0.0, 1.0) var loot_chance: float = 0.5

const PICKUP_SCENE := preload("res://scenes/entities/item_pickup.tscn")

const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3
const WALK_FRAMES := [0, 1, 0, 2]

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: Health = $Health
@onready var touch_box: Area2D = $TouchBox

var _facing_row: int = ROW_DOWN
var _anim_time: float = 0.0
var _player: Node2D = null
var _touch_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
## Decaying knockback velocity applied when struck.
var _knockback: Vector2 = Vector2.ZERO
const KNOCKBACK_DECAY := 700.0

func _ready() -> void:
	add_to_group("enemy")
	health.died.connect(_on_died)
	_pick_wander()

func _physics_process(delta: float) -> void:
	_touch_timer = maxf(0.0, _touch_timer - delta)
	_acquire_player()

	var input: Vector2 = _decide_input(delta)

	velocity = input * speed + _knockback
	move_and_slide()
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	_update_facing(input)
	_update_animation(delta, input.length() > 0.01)
	_check_touch()

## Returns the desired movement direction this frame. Base behavior: chase the
## player within detect_range, otherwise wander. Overridable by subclasses.
func _decide_input(delta: float) -> Vector2:
	if _player != null and is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		if to_player.length() <= detect_range:
			return to_player.normalized()
	return _wander(delta)

func _acquire_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

func _wander(delta: float) -> Vector2:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander()
	return _wander_dir * 0.5

func _pick_wander() -> void:
	_wander_timer = randf_range(1.0, 2.5)
	if randf() < 0.4:
		_wander_dir = Vector2.ZERO
	else:
		_wander_dir = Vector2.from_angle(randf() * TAU)

func _check_touch() -> void:
	if _touch_timer > 0.0:
		return
	for body in touch_box.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(touch_damage)
			_touch_timer = touch_cooldown
			return

func _update_facing(input: Vector2) -> void:
	if input == Vector2.ZERO:
		return
	if abs(input.x) > abs(input.y):
		_facing_row = ROW_RIGHT if input.x > 0.0 else ROW_LEFT
	else:
		_facing_row = ROW_DOWN if input.y > 0.0 else ROW_UP

func _update_animation(delta: float, moving: bool) -> void:
	if moving:
		_anim_time += delta * anim_fps
	else:
		_anim_time = 0.0
	var col: int = WALK_FRAMES[int(_anim_time) % WALK_FRAMES.size()] if moving else 0
	sprite.frame = _facing_row * sprite.hframes + col

## Scale this enemy's threat to a difficulty tier (1 = base). Called by the area
## generator right after spawning so the deeper wilds field tougher, more
## rewarding creatures. Subclasses inherit this unchanged.
func apply_tier(tier: int) -> void:
	if tier <= 1:
		return
	var steps: int = tier - 1
	touch_damage = int(round(touch_damage * (1.0 + 0.35 * steps)))
	xp_reward = int(round(xp_reward * (1.0 + 0.5 * steps)))
	var scaled_hp: int = int(round(health.max_health * (1.0 + 0.5 * steps)))
	health.max_health = scaled_hp
	health.health = scaled_hp
	# Tint deeper-tier foes so they read as more dangerous.
	modulate = modulate.lerp(Color(1.0, 0.6, 0.7), clampf(0.12 * steps, 0.0, 0.5))

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	health.take_damage(amount)
	_flash()
	Events.damage_dealt.emit(global_position, amount, true)
	if knockback != Vector2.ZERO:
		_knockback = knockback

func _flash() -> void:
	modulate = Color(1.0, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.2)

func _on_died() -> void:
	_drop_loot()
	Events.enemy_killed.emit(enemy_id, xp_reward, global_position)
	queue_free()

func _drop_loot() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for item in loot_table:
		if item == null or randf() > loot_chance:
			continue
		var pickup := PICKUP_SCENE.instantiate() as ItemPickup
		pickup.configure(item, 1)
		pickup.position = position + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		parent.call_deferred("add_child", pickup)
