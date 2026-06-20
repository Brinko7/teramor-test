extends SceneTree

## Headless smoke test for NPC visual variance (task #29). Run with:
##   godot --headless --path <project> -s res://tools/validate_npcs.gd
## Instantiates the town, tavern and settlement ON-tree (so npc.gd `_ready` fires
## and `_apply_appearance` resolves each look), then asserts every named NPC
## ended up on its own distinct baked sheet instead of the shared villager sprite.
##
## NOTE: a SceneTree's `_initialize` runs BEFORE the first frame, so descendant
## `_ready` callbacks are still deferred at that point. We drive the checks from a
## coroutine and `await process_frame` after each add_child so `_apply_appearance`
## has actually run before we read the resolved Sprite2D.texture.

const TOWN := "res://scenes/world/town.tscn"
const TAVERN := "res://scenes/world/tavern_interior.tscn"
const SETTLEMENT := "res://scenes/world/settlement.tscn"

## node name -> expected sheet filename.
const TOWN_LOOKS := {
	"Guard": "npc_warden.png",
	"Villager": "npc_townswoman.png",
	"Child": "npc_child.png",
	"Smith": "npc_smith.png",
	"Cleric": "npc_cleric.png",
	"Vendor": "npc_grocer.png",
	"Gossip": "npc_gossip.png",
}
const TAVERN_LOOKS := {"TavernKeeper": "npc_keeper.png"}
const SETTLEMENT_LOOKS := {"Mara": "npc_quartermaster.png", "ElderMaelon": "npc_druid.png"}

var _fail := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== npc variance validation ===")
	var seen: Array = []
	seen += await _check_scene(TOWN, "town", TOWN_LOOKS)
	seen += await _check_scene(TAVERN, "tavern", TAVERN_LOOKS)
	seen += await _check_scene(SETTLEMENT, "settlement", SETTLEMENT_LOOKS)
	_check_distinct(seen)
	if _fail == 0:
		print("\nRESULT: PASS — townsfolk wear distinct, individual looks")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

## Instantiate on-tree, let a frame process so `_ready` fires, then assert each
## named NPC's resolved sprite. Returns the sheet filenames found (for the
## cross-scene distinctness check).
func _check_scene(path: String, tag: String, looks: Dictionary) -> Array:
	print("\n[%s] %d named npc look(s)" % [tag, looks.size()])
	var found: Array = []
	if not ResourceLoader.exists(path):
		_err("%s: missing scene %s" % [tag, path])
		return found
	var ps := load(path) as PackedScene
	if ps == null or not ps.can_instantiate():
		_err("%s: cannot instantiate %s" % [tag, path])
		return found
	var inst := ps.instantiate()
	root.add_child(inst)
	# Let descendant `_ready` (and thus `_apply_appearance`) actually run.
	await process_frame
	for nname in looks:
		var want: String = looks[nname]
		var npc := _find_named(inst, nname)
		if npc == null:
			_err("%s: NPC '%s' not found" % [tag, nname])
			continue
		var spr := npc.get_node_or_null("Sprite2D") as Sprite2D
		if spr == null or spr.texture == null:
			_err("%s: %s has no Sprite2D texture" % [tag, nname])
			continue
		var got: String = spr.texture.resource_path.get_file()
		if got != want:
			_err("%s: %s wears '%s' (want %s)" % [tag, nname, got, want])
		else:
			print("  [ok] %s -> %s" % [nname, got])
			found.append(got)
	inst.queue_free()
	return found

func _check_distinct(sheets: Array) -> void:
	print("\n[variance] all looks unique")
	var uniq: Dictionary = {}
	for s in sheets:
		uniq[s] = true
	if uniq.size() != sheets.size():
		_err("duplicate looks across the cast (%d sheets, %d unique)" % [sheets.size(), uniq.size()])
	elif sheets.has("npc_villager.png"):
		_err("a named NPC fell back to the shared npc_villager.png")
	else:
		print("  [ok] %d named NPCs, all on their own sheet" % sheets.size())

func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for c in node.get_children():
		var hit := _find_named(c, wanted)
		if hit != null:
			return hit
	return null
