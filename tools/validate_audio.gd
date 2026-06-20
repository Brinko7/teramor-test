extends SceneTree

## Headless smoke test for the audio foundation: the bus layout (Master/Music/SFX/
## Ambience), the AudioManager autoload, every baked SFX loading as an AudioStream,
## the Events->SFX wiring firing without error, and the bus-volume API the options
## sliders will drive.
##
## Run: godot --headless -s tools/validate_audio.gd
## (load() after awaits, autoloads via /root — see CLAUDE.md "writing a validator".)

const SFX_DIR := "res://assets/audio/sfx/"
const EXPECTED_SFX := [
	"step", "swing", "bow", "hit_enemy", "hit_player", "death",
	"pickup", "craft", "gather", "levelup", "ui_click", "dodge",
]
const EXPECTED_BUSES := ["Master", "Music", "SFX", "Ambience"]

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	# 1) Bus layout loaded with the mixing buses the options menu will target.
	for bus_name in EXPECTED_BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			_err("audio bus '%s' missing (bus layout not applied?)" % bus_name)

	# 2) Every baked SFX loads as an AudioStream.
	for sfx in EXPECTED_SFX:
		var path := SFX_DIR + String(sfx) + ".wav"
		if not ResourceLoader.exists(path):
			_err("SFX missing: %s (run python3 tools/audioforge.py)" % path)
			continue
		if not (load(path) is AudioStream):
			_err("SFX did not load as AudioStream: %s" % path)

	# 3) AudioManager autoload is up and wired.
	var am = get_root().get_node_or_null("AudioManager")
	if am == null:
		_err("AudioManager autoload missing")
	else:
		# Bus-volume API round-trips (drives the future sliders).
		am.set_bus_volume_linear(&"SFX", 0.5)
		var v: float = am.get_bus_volume_linear(&"SFX")
		if v < 0.4 or v > 0.6:
			_err("SFX bus volume round-trip off: set 0.5, read %.2f" % v)
		am.set_bus_volume_linear(&"SFX", 1.0)  # restore
		# Direct playback of a known SFX must not error (dummy driver in headless).
		am.play(&"pickup")

	# 4) The live Events -> AudioManager wiring fires without error (player-gated
	#    handlers + the ambient-stays-silent path).
	var ev = get_root().get_node_or_null("Events")
	if ev == null:
		_err("Events autoload missing")
	else:
		ev.damage_dealt.emit(Vector2.ZERO, 5, true, true)    # player hits foe -> hit_enemy
		ev.damage_dealt.emit(Vector2.ZERO, 5, true, false)   # faction brawl -> silent
		ev.melee_swung.emit(Vector2.ZERO, Vector2.RIGHT, true)
		ev.step_puff.emit(Vector2.ZERO)
		ev.enemy_killed.emit(&"wolf", 10, Vector2.ZERO, true)
		ev.item_collected.emit(&"herb", 1)
		ev.item_crafted.emit(&"iron_sword")
		ev.player_leveled_up.emit(2)
	await process_frame

	if _fail == 0:
		print("RESULT: PASS - audio foundation: buses, %d SFX, AudioManager wiring, volume API" % EXPECTED_SFX.size())
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
