extends SceneTree

## Headless smoke test for the player dodge-roll: the input action exists, the dodge
## SFX is baked, starting a roll grants i-frames + cooldown + a committed direction,
## and i-frames actually make take_damage a no-op (roll through the blow) while a hit
## still lands without them.
##
## Run: godot --headless -s tools/validate_dodge.gd

const DODGE_SFX := "res://assets/audio/sfx/dodge.wav"

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	if not InputMap.has_action("dodge"):
		_err("input action 'dodge' is not mapped")
	if not ResourceLoader.exists(DODGE_SFX):
		_err("dodge SFX missing (run python3 tools/audioforge.py): %s" % DODGE_SFX)

	var scene = load("res://scenes/entities/player.tscn")
	if scene == null:
		_err("player.tscn failed to load")
		_finish()
		return
	var p = scene.instantiate()
	get_root().add_child(p)
	await process_frame
	await process_frame

	# Starting a roll commits a direction and grants i-frames + cooldown.
	p._start_dodge()
	if p._dodge_timer <= 0.0:
		_err("dodge did not start (no dash time)")
	if p._iframe_timer <= 0.0:
		_err("dodge granted no i-frames")
	if p._dodge_cd <= 0.0:
		_err("dodge set no cooldown (could be spammed)")
	if p._dodge_dir == Vector2.ZERO:
		_err("dodge committed no direction")

	# I-frames make incoming damage a no-op.
	p._iframe_timer = 1.0
	p._invuln_timer = 0.0
	var hp0: int = p.health.health
	p.take_damage(20)
	if p.health.health != hp0:
		_err("i-frames did not block damage (%d -> %d)" % [hp0, p.health.health])

	# Without i-frames (or post-hit invuln), the same hit lands.
	p._iframe_timer = 0.0
	p._invuln_timer = 0.0
	var hp1: int = p.health.health
	p.take_damage(20)
	if p.health.health >= hp1:
		_err("damage did not land once i-frames expired (%d -> %d)" % [hp1, p.health.health])

	p.queue_free()
	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - dodge: input + SFX + i-frames grant/expire correctly")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
