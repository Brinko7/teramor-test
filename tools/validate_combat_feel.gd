extends SceneTree

## Headless smoke test for the combat-feel layer: the hit-flash shader, the three
## CombatFX-spawned effects (slash arc, telegraph ring, dust puff), the new Events
## signals (melee_swung / attack_windup / step_puff), and the enemy telegraphed
## melee attack (READY -> WINDUP -> STRIKE) plus the death beat.
##
## Run: godot --headless -s tools/validate_combat_feel.gd
##
## Everything is loaded with load() *inside* _run, after awaiting a couple of
## frames — never top-level preload/class_name refs, which resolve at this script's
## compile time and trip the frame-0 autoload/global-class trap (scripts then fail
## to attach). See validate_scene_load.gd for the same pattern.

const SLASH := "res://scripts/effects/slash_arc.gd"
const RING := "res://scripts/effects/telegraph_ring.gd"
const PUFF := "res://scripts/effects/dust_puff.gd"
const FLASH_SHADER := "res://assets/shaders/hit_flash.gdshader"
const WITHERED := "res://scenes/entities/enemy_withered.tscn"

var _fail := 0
var _swung := 0
var _windup := 0
var _step := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _on_swung(_p: Vector2, _d: Vector2, _by_player: bool) -> void:
	_swung += 1

func _on_windup(_p: Vector2, _d: Vector2, _dur: float) -> void:
	_windup += 1

func _on_step(_p: Vector2) -> void:
	_step += 1

## A throwaway combatant in the "player" group that records damage taken.
func _make_dummy_player() -> Node2D:
	var src := GDScript.new()
	src.source_code = "extends CharacterBody2D\nvar hits: int = 0\nfunc take_damage(a: int) -> void:\n\thits += a\n"
	src.reload()
	var dummy := CharacterBody2D.new()
	dummy.set_script(src)
	dummy.add_to_group("player")
	return dummy

func _run() -> void:
	# Let autoloads + global classes finish registering before we touch scenes.
	await process_frame
	await process_frame
	await process_frame

	var ev = get_root().get_node_or_null("Events")
	if ev == null:
		_err("Events autoload missing in headless mode")
		_finish()
		return

	# 1) Shader resource loads.
	if not (load(FLASH_SHADER) is Shader):
		_err("hit_flash.gdshader did not load as a Shader")

	# 2) New signals exist with the right arity; live CombatFX handlers also run
	#    (current_scene is null headless, so the spawns are guarded no-ops).
	ev.melee_swung.connect(_on_swung)
	ev.attack_windup.connect(_on_windup)
	ev.step_puff.connect(_on_step)
	ev.melee_swung.emit(Vector2.ZERO, Vector2.RIGHT, true)
	ev.attack_windup.emit(Vector2.ZERO, Vector2.DOWN, 0.4)
	ev.step_puff.emit(Vector2.ZERO)
	await process_frame
	if _swung != 1 or _windup != 1 or _step != 1:
		_err("new Events signals did not round-trip (swung=%d windup=%d step=%d)" % [_swung, _windup, _step])

	# 3) The code-built effects instantiate, enter the tree and tween without error.
	for path in [SLASH, RING, PUFF]:
		var script = load(path)
		if script == null:
			_err("effect script failed to load: %s" % path)
			continue
		var fx = script.new()
		if not (fx is Node2D):
			_err("effect %s is not a Node2D" % path)
			continue
		get_root().add_child(fx)
	await process_frame

	# 4) melee_attacker flags: base enemy attacks, kiters/prey/non-combatants don't.
	_check_attacker("res://scenes/entities/enemy.tscn", true, "bandit")
	_check_attacker("res://scenes/entities/enemy_archer.tscn", false, "archer")
	_check_attacker("res://scenes/entities/wildlife_deer.tscn", false, "deer")
	_check_attacker("res://scenes/entities/enemy_bear_cub.tscn", false, "bear cub")
	await process_frame

	# 5) A telegraphed strike lands on a dummy in range after the wind-up resolves.
	var dummy := _make_dummy_player()
	get_root().add_child(dummy)
	dummy.global_position = Vector2(15, 0)
	var e = load("res://scenes/entities/enemy.tscn").instantiate()
	get_root().add_child(e)
	e.global_position = Vector2.ZERO
	await process_frame
	var frames := 0
	while dummy.hits == 0 and frames < 120:
		e._acquire_target(1.0)
		e._update_attack(0.05)
		frames += 1
	if dummy.hits <= 0:
		_err("telegraphed strike never landed on an in-range target")
	elif _windup < 2:
		_err("strike landed but no attack_windup telegraph fired")

	# 6) The death beat: a lethal hit flags the corpse and pulls it from combat.
	var victim = load("res://scenes/entities/enemy.tscn").instantiate()
	get_root().add_child(victim)
	victim.global_position = Vector2(400, 0)
	await process_frame
	victim.take_damage(9999, Vector2.ZERO, true)
	if not victim._dying:
		_err("lethal hit did not start the death beat (_dying stayed false)")
	if victim.is_in_group("enemy"):
		_err("dying enemy was not removed from the 'enemy' group")

	_finish()

func _check_attacker(scene_path: String, want: bool, label: String) -> void:
	var scene = load(scene_path)
	if scene == null:
		_err("%s scene failed to load: %s" % [label, scene_path])
		return
	var n = scene.instantiate()
	get_root().add_child(n)
	# _ready (where archer/prey/cub opt out) has run by now.
	var got = n.get("melee_attacker")
	if got != want:
		_err("%s melee_attacker = %s, expected %s" % [label, str(got), str(want)])
	n.queue_free()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - combat-feel layer (flash, effects, telegraphs, strike, death) is wired")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
