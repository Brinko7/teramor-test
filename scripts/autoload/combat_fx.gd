extends Node

## Autoload `CombatFX`. Turns combat events into game-feel: floating damage
## numbers, brief hit-stop (a micro freeze that sells impact), camera shake, and a
## death burst. Listens to the Events bus so nothing else needs to know it exists
## — combat code just reports damage/kills and this makes them feel good.

const DAMAGE_NUMBER := preload("res://scenes/effects/damage_number.tscn")

## Hit-stop freeze depth and durations (real seconds, independent of time scale).
const FREEZE_SCALE := 0.04
const HIT_FREEZE := 0.045
const KILL_FREEZE := 0.08

var _frozen: bool = false

func _ready() -> void:
	# Run during the freeze (its restore timer ignores time scale anyway).
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.enemy_killed.connect(_on_enemy_killed)

func _on_damage_dealt(position: Vector2, amount: int, to_enemy: bool) -> void:
	_spawn_number(position, amount, to_enemy)
	Events.screen_shake.emit(2.5 if to_enemy else 4.5)
	if to_enemy:
		_hit_stop(HIT_FREEZE)

func _on_enemy_killed(_enemy_id: StringName, _xp_reward: int, position: Vector2) -> void:
	Events.screen_shake.emit(5.5)
	_hit_stop(KILL_FREEZE)
	_spawn_death_burst(position)

# --- Hit-stop ---------------------------------------------------------------

## Briefly slow time to a crawl, then restore. The restore timer ignores time
## scale so it fires in real seconds. Non-reentrant so rapid hits don't stack.
func _hit_stop(duration: float) -> void:
	if _frozen:
		return
	_frozen = true
	Engine.time_scale = FREEZE_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_frozen = false

# --- Spawned effects --------------------------------------------------------

func _spawn_number(position: Vector2, amount: int, to_enemy: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var number := DAMAGE_NUMBER.instantiate()
	scene.add_child(number)
	(number as Node2D).global_position = position + Vector2(randf_range(-4, 4), -10)
	number.call("setup", amount, to_enemy)

func _spawn_death_burst(position: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var burst := CPUParticles2D.new()
	burst.global_position = position
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 14
	burst.lifetime = 0.45
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 110.0
	burst.gravity = Vector2(0, 120)
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color = Color(0.85, 0.3, 0.3)
	scene.add_child(burst)
	# Free the emitter once its particles have died.
	burst.get_tree().create_timer(burst.lifetime + 0.2).timeout.connect(burst.queue_free)
