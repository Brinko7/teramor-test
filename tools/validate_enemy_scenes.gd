extends SceneTree

## Smoke test for the loot-table edits: instantiate every enemy scene so a malformed
## .tscn or a bad Array[Item] entry surfaces as a hard error, and confirm the combat
## enemies expose a non-empty loot_table of real Item resources (the cub stays empty).
## Loads after awaiting frames so enemy.gd's class_name deps resolve post-autoload.

const COMBAT := {
	"res://scenes/entities/enemy_wolf.tscn": 2,
	"res://scenes/entities/enemy_bear.tscn": 2,
	"res://scenes/entities/enemy.tscn": 2,
	"res://scenes/entities/enemy_brute.tscn": 2,
	"res://scenes/entities/enemy_archer.tscn": 2,
	"res://scenes/entities/enemy_withered.tscn": 1,
}
const CUB := "res://scenes/entities/enemy_bear_cub.tscn"

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _run() -> void:
	await process_frame
	await process_frame
	for path in COMBAT:
		var loot = _load_loot(path)
		if loot == null:
			continue
		var want: int = COMBAT[path]
		if loot.size() < want:
			_err("%s loot_table has %d entries, expected >= %d" % [path, loot.size(), want])
		for entry in loot:
			if not (entry is Item):
				_err("%s loot entry is not an Item: %s" % [path, entry])
	var cub_loot = _load_loot(CUB)
	if cub_loot != null and cub_loot.size() > 0:
		_err("bear cub should be lootless, has %d entries" % cub_loot.size())
	if _fail == 0:
		print("RESULT: PASS - all enemy scenes instantiate; combat loot resolves to Items; cub lootless")
	else:
		print("RESULT: FAIL - %d issue(s)" % _fail)
	quit()

## Instantiate a scene, read its loot_table, free it. Returns null on load failure.
func _load_loot(path: String):
	var packed = load(path)
	if packed == null:
		_err("failed to load %s" % path)
		return null
	var inst = packed.instantiate()
	if inst == null:
		_err("failed to instantiate %s" % path)
		return null
	get_root().add_child(inst)
	var loot = inst.get("loot_table")
	inst.queue_free()
	if loot == null:
		return []
	return loot
