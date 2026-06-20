extends SceneTree

## Validates logical enemy loot (roadmap: wolves drop hide/meat, humanoids drop
## the gear they carry). Every combat enemy must ship a non-empty loot_table of
## items that actually exist; the bear cub (a non-combatant) stays lootless; and
## the area generator must KEEP an enemy's authored loot instead of overwriting it
## with the generic biome pool (which is the "random with no logic" we're fixing).
##
## Text scan via FileAccess — no instantiation / autoload access (frame-0 safe).

const DIR := "res://scenes/entities"
const COMBAT := [
	"enemy_wolf.tscn", "enemy_bear.tscn", "enemy.tscn",
	"enemy_brute.tscn", "enemy_archer.tscn", "enemy_withered.tscn",
]
const LOOTLESS := ["enemy_bear_cub.tscn"]
const LOOT_MARK := "loot_table = Array[Item]([ExtResource("

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _run() -> void:
	for f in COMBAT:
		var text := FileAccess.get_file_as_string("%s/%s" % [DIR, f])
		if text.is_empty():
			_err("%s unreadable" % f)
			continue
		if not text.contains(LOOT_MARK):
			_err("%s has no loot_table — it would drop nothing" % f)
			continue
		for path in _item_paths(text):
			if not ResourceLoader.exists(path):
				_err("%s references missing item '%s'" % [f, path])

	for f in LOOTLESS:
		var text := FileAccess.get_file_as_string("%s/%s" % [DIR, f])
		if text.contains(LOOT_MARK):
			_err("%s is a non-combatant and should not drop loot" % f)

	var gen := FileAccess.get_file_as_string("res://scripts/world/procedural_area.gd")
	if not gen.contains("own_loot"):
		_err("procedural_area.gd no longer preserves authored enemy loot (clobbers it with the biome pool)")

	if _fail == 0:
		print("RESULT: PASS - every combat enemy drops logical loot; cub lootless; generator keeps authored loot")
	else:
		print("RESULT: FAIL - %d issue(s)" % _fail)
	quit()

func _item_paths(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		if line.begins_with("[ext_resource") and line.contains("/resources/items/"):
			var a := line.find("path=\"") + 6
			var b := line.find("\"", a)
			out.append(line.substr(a, b - a))
	return out
