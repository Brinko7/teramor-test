extends SceneTree

## Validates building/area transitions:
##   1. every door's `target_spawn` resolves to a real Marker2D in its destination
##      scene (a broken name silently falls back to some other marker — possibly
##      inside another trigger — which is how you get dumped somewhere wrong or
##      trapped);
##   2. every interior has at least one exit transition (you can always get out);
##   3. the spawn-overlap soft-lock guard stays wired (SceneManager.placing +
##      transition_zone honouring it).
##
## Pure text scan via FileAccess — no scene boot, no autoload access, so it is
## immune to the frame-0 autoload-compile trap.

const WORLD_DIR := "res://scenes/world"
const INTERIORS := ["shop_interior.tscn", "tavern_interior.tscn", "cabin_interior.tscn"]

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _run() -> void:
	var markers: Dictionary = {}   # full path -> Array of Marker2D names
	var transitions: Array = []    # {from, target_scene, target_spawn}
	var dir := DirAccess.open(WORLD_DIR)
	if dir == null:
		_err("cannot open %s" % WORLD_DIR)
		_done()
		return
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var path := "%s/%s" % [WORLD_DIR, file]
		var text := FileAccess.get_file_as_string(path)
		markers[path] = _marker_names(text)
		for t in _transitions(text):
			t["from"] = file
			transitions.append(t)

	# 1) target_spawn must name a real marker in the destination.
	for t in transitions:
		var dest: String = t["target_scene"]
		var spawn: String = t["target_spawn"]
		if not markers.has(dest):
			_err("%s -> %s: destination not found among world scenes" % [t["from"], dest])
			continue
		if spawn.is_empty():
			if (markers[dest] as Array).is_empty():
				_err("%s -> %s: empty target_spawn and destination has no markers" % [t["from"], dest])
			continue
		if not ((markers[dest] as Array).has(spawn)):
			_err("%s -> %s: target_spawn '%s' has no matching Marker2D there" % [t["from"], dest, spawn])

	# 2) Every interior must have at least one exit.
	for interior in INTERIORS:
		var has_exit := false
		for t in transitions:
			if t["from"] == interior:
				has_exit = true
				break
		if not has_exit:
			_err("%s has no exit transition — the player could be trapped" % interior)

	# 3) Soft-lock guard wired.
	var tz := FileAccess.get_file_as_string("res://scripts/transition_zone.gd")
	if not tz.contains("placing"):
		_err("transition_zone.gd no longer honours SceneManager.placing")
	var sm := FileAccess.get_file_as_string("res://scripts/autoload/scene_manager.gd")
	if not (sm.contains("placing = true") and sm.contains("placing = false")):
		_err("scene_manager.gd no longer toggles `placing` around placement")

	if _fail == 0:
		print("RESULT: PASS - %d transitions resolve; interiors exitable; soft-lock guard wired" % transitions.size())
	else:
		print("RESULT: FAIL - %d issue(s)" % _fail)
	_done()

func _marker_names(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		if line.begins_with("[node name=\"") and line.contains("type=\"Marker2D\""):
			out.append(_attr(line, "name"))
	return out

func _transitions(text: String) -> Array:
	var out: Array = []
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.begins_with("target_scene = \""):
			var ts := _quoted(line)
			var sp := ""
			if i + 1 < lines.size() and lines[i + 1].begins_with("target_spawn = \""):
				sp = _quoted(lines[i + 1])
			out.append({"target_scene": ts, "target_spawn": sp})
	return out

func _attr(line: String, key: String) -> String:
	var marker := "%s=\"" % key
	var a := line.find(marker) + marker.length()
	var b := line.find("\"", a)
	return line.substr(a, b - a)

func _quoted(line: String) -> String:
	var a := line.find("\"") + 1
	var b := line.find("\"", a)
	return line.substr(a, b - a)

func _done() -> void:
	quit()
