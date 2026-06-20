extends SceneTree

## Headless check for the music & ambience layer (MusicManager):
##   1. Every baked loop (music + ambience) exists and loads as an AudioStreamWAV
##      that can be set to loop (the silent-path failure mode is a typo'd track).
##   2. Every zone in ZONE_MUSIC maps to a real music track.
##   3. enter_zone() runs for every declared zone and updates the current zone,
##      and the day/night ambience swap doesn't error.
##
## Run: godot --headless -s tools/validate_music.gd

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _ok(m: String) -> void:
	print("  ok: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var music = get_root().get_node_or_null("MusicManager")
	var time = get_root().get_node_or_null("TimeManager")
	if music == null or time == null:
		_err("a required autoload is missing (music/time)")
		_finish()
		return

	# --- 1. Baked loops exist and can be looped ------------------------------
	var tracks := {
		music.MUSIC_DIR: ["theme_camp", "theme_town", "theme_wild", "theme_cursed"],
		music.AMB_DIR: ["amb_day", "amb_night", "amb_cave", "amb_cursed"],
	}
	for dir: String in tracks:
		for name: String in tracks[dir]:
			var path: String = dir + name + ".wav"
			if not ResourceLoader.exists(path):
				_err("missing baked loop: %s (run python3 tools/audioforge.py)" % path)
				continue
			var w := load(path) as AudioStreamWAV
			if w == null:
				_err("%s did not load as AudioStreamWAV" % path)
				continue
			var loop_end: int = int(round(w.get_length() * w.mix_rate))
			if loop_end > 0:
				_ok("%s loads + loops (%.1fs)" % [name, w.get_length()])
			else:
				_err("%s has no length to loop" % name)

	# --- 2. Every zone maps to a real music track ----------------------------
	var zmusic: Dictionary = music.ZONE_MUSIC
	var map_ok := true
	for zone: StringName in zmusic:
		var track: String = music.MUSIC_DIR + String(zmusic[zone]) + ".wav"
		if not ResourceLoader.exists(track):
			map_ok = false
			_err("zone '%s' -> '%s' but that track is missing" % [String(zone), String(zmusic[zone])])
	if map_ok:
		_ok("all %d zones map to a real music track" % zmusic.size())

	# --- 3. enter_zone runs for every zone + day/night ambience swap ---------
	var zones: Array = zmusic.keys()
	zones.append(&"cave")  # cave is a valid zone even though it shares wild's theme
	var ran_ok := true
	for zone: StringName in zones:
		music.enter_zone(zone)
		if music.get_zone() != zone:
			ran_ok = false
			_err("enter_zone('%s') did not set the current zone" % String(zone))
	if ran_ok:
		_ok("enter_zone ran for every zone and tracked the current one")

	# Day/night ambience swap for an outdoor zone shouldn't error.
	time.reset()
	music.enter_zone(&"camp")
	music._on_period_changed(time.get_period())
	_ok("day/night ambience swap ran without error")

	_finish()

func _finish() -> void:
	if _fail == 0:
		print("RESULT: PASS - music & ambience layer wired (loops, zone map, transitions)")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
