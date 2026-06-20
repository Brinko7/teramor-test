extends SceneTree

## Headless smoke test for the faction-aware combat signals (#44). Emits the real
## Events.damage_dealt / enemy_killed with their new 4-arg shapes and lets the live
## autoload handlers (CombatFX, QuestManager) react — an arg-count mismatch in any
## connected handler would throw here. Also asserts our own probe handlers receive
## the player_involved / by_player flags intact.
##
## Accesses autoloads via /root (not by global name) and only after awaiting a
## frame, to dodge the frame-0 autoload-compile trap.

var _fail := 0
var _got_damage: Array = []
var _got_kill: Array = []

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _on_dmg(_pos: Vector2, _amount: int, _to_enemy: bool, player_involved: bool) -> void:
	_got_damage.append(player_involved)

func _on_kill(_id: StringName, _xp: int, _pos: Vector2, by_player: bool) -> void:
	_got_kill.append(by_player)

func _run() -> void:
	await process_frame
	await process_frame
	var ev = get_root().get_node_or_null("Events")
	if ev == null:
		_err("Events autoload missing in headless mode")
		quit()
		return
	ev.damage_dealt.connect(_on_dmg)
	ev.enemy_killed.connect(_on_kill)

	# Fire the real signals with the new 4-arg shapes. The live CombatFX and
	# QuestManager handlers run too; a wrong arity in any of them errors here.
	ev.damage_dealt.emit(Vector2.ZERO, 5, true, false)      # enemy-vs-enemy: no juice
	ev.damage_dealt.emit(Vector2.ZERO, 5, true, true)       # player hit: juice
	ev.enemy_killed.emit(&"wolf", 10, Vector2.ZERO, false)  # faction kill: no credit
	ev.enemy_killed.emit(&"wolf", 10, Vector2.ZERO, true)   # player kill: credit
	await process_frame

	if _got_damage != [false, true]:
		_err("damage player_involved mismatch: %s" % str(_got_damage))
	if _got_kill != [false, true]:
		_err("kill by_player mismatch: %s" % str(_got_kill))

	if _fail == 0:
		print("RESULT: PASS - faction-aware combat signals fire with correct arity")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
