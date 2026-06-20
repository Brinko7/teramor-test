extends Enemy
class_name Wildlife

## Passive, huntable prey — deer and rabbits that roam the wilds, graze idly, and
## bolt when a threat (the player or any predator) comes near or when struck. They
## belong to the WILDLIFE faction, so the faction system treats them as neutral:
## they fight no one and nothing faction-targets them. They still live in the
## "enemy" group, though, so the player's attacks land — that's the whole point,
## they're game to hunt for meat and hide.
##
## Reuses Enemy's locomotion/animation; only the brain changes. Grazing is a calm,
## mostly-idle drift; fleeing overrides `speed` for a panicked sprint directly away
## from the nearest threat, sustained for `spook_time` after the threat is gone so
## a deer keeps running rather than instantly settling.

## How close a threat must come before this animal spooks and flees (px).
@export var flee_range: float = 96.0
## Sprint multiplier applied to the grazing speed while fleeing.
@export var flee_speed_mult: float = 2.3
## How long the animal keeps fleeing after the last threat leaves range (seconds).
@export var spook_time: float = 2.5

var _base_speed: float = 0.0
var _spook: float = 0.0
var _flee_dir: Vector2 = Vector2.ZERO
var _graze_dir: Vector2 = Vector2.ZERO
var _graze_timer: float = 0.0

func _ready() -> void:
	super._ready()
	# Belt-and-suspenders: guarantee neutrality even if a scene forgets to set it.
	faction = Faction.WILDLIFE
	_base_speed = speed

## Flee from the nearest threat; keep fleeing while spooked; otherwise graze.
func _decide_input(delta: float) -> Vector2:
	_spook = maxf(0.0, _spook - delta)
	var threat := _nearest_threat()
	if threat != null:
		_flee_dir = (global_position - threat.global_position).normalized()
		_spook = spook_time
	if _spook > 0.0:
		speed = _base_speed * flee_speed_mult
		return _flee_dir
	speed = _base_speed
	return _graze(delta)

## Nearest thing this animal is scared of within flee_range: the player, or any
## non-wildlife creature (a predator/raider). Other prey are not threats.
func _nearest_threat() -> Node2D:
	var best: Node2D = null
	var best_dist: float = flee_range
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		var pd: float = global_position.distance_to(player.global_position)
		if pd <= best_dist:
			best = player
			best_dist = pd
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not (other is Enemy) or not is_instance_valid(other):
			continue
		if (other as Enemy).faction == Faction.WILDLIFE:
			continue
		var od: float = global_position.distance_to((other as Enemy).global_position)
		if od <= best_dist:
			best = other
			best_dist = od
	return best

## Calm grazing: mostly standing still, the odd slow few-step drift.
func _graze(delta: float) -> Vector2:
	_graze_timer -= delta
	if _graze_timer <= 0.0:
		_graze_timer = randf_range(1.5, 3.5)
		_graze_dir = Vector2.ZERO if randf() < 0.6 else Vector2.from_angle(randf() * TAU)
	return _graze_dir * 0.4

## When hit, bolt along the knockback (away from whoever struck us) and stay spooked.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, from_player: bool = false) -> void:
	super.take_damage(amount, knockback, from_player)
	_spook = spook_time
	if knockback != Vector2.ZERO:
		_flee_dir = knockback.normalized()
	elif _flee_dir == Vector2.ZERO:
		_flee_dir = Vector2.from_angle(randf() * TAU)

## Wildlife is ambient flavour, not a difficulty knob — never scale it to the tier.
func apply_tier(_tier: int) -> void:
	pass
