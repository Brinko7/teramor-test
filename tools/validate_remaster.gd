extends SceneTree

## Headless smoke test for the remaster slice (the additive in-engine sandbox for
## the new Eastward art). Asserts the baked assets resolve at the expected sizes
## and the slice scene instantiates with a correctly-configured player sprite.
##   godot --headless --path <project> -s res://tools/validate_remaster.gd

const SHEET := "res://assets/remaster/player_walk.png"
const GRASS := "res://assets/remaster/grass32.png"
const SLICE := "res://scenes/world/remaster_slice.tscn"

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	print("=== remaster validation ===")
	# 1. baked assets present + correctly sized (8 facings x 4 phases of 84x120)
	var sheet := load(SHEET) as Texture2D
	if sheet == null:
		_err("player walk sheet missing: " + SHEET)
	elif sheet.get_width() != 336 or sheet.get_height() != 960:
		_err("player sheet is %dx%d, want 336x960" % [sheet.get_width(), sheet.get_height()])
	else:
		print("  [ok] player_walk.png 336x960 (8 dirs x 4 phases)")
	var grass := load(GRASS) as Texture2D
	if grass == null or grass.get_width() != 32 or grass.get_height() != 32:
		_err("grass32.png missing or not 32x32")
	else:
		print("  [ok] grass32.png 32x32 seamless tile")
	# 2. baked props present + correctly sized (foot-anchored sprites)
	for p in [["res://assets/remaster/cottage.png", 150, 185],
			["res://assets/remaster/tree.png", 92, 128],
			["res://assets/remaster/npc_bram.png", 84, 120],
			["res://assets/remaster/npc_wrenna.png", 84, 120]]:
		var tex := load(p[0]) as Texture2D
		if tex == null or tex.get_width() != p[1] or tex.get_height() != p[2]:
			_err("prop %s missing or wrong size (want %dx%d)" % [p[0], p[1], p[2]])
		else:
			print("  [ok] %s %dx%d" % [p[0], p[1], p[2]])
	# 3. gear overlay sheets share the body geometry (336x960, 8 dirs x 4 phases)
	for g in ["res://assets/remaster/armor_leather.png", "res://assets/remaster/armor_plate.png",
			"res://assets/remaster/weapon_sword.png", "res://assets/remaster/weapon_ember.png"]:
		var tex := load(g) as Texture2D
		if tex == null or tex.get_width() != 336 or tex.get_height() != 960:
			_err("gear overlay %s missing or not 336x960" % g)
		else:
			print("  [ok] %s 336x960 (overlay layer)" % g)
	# 4. slice scene instantiates: y-sorted Entities with the layered paper-doll
	var scene := load(SLICE) as PackedScene
	if scene == null or not scene.can_instantiate():
		_err("remaster_slice.tscn missing / cannot instantiate")
	else:
		var inst := scene.instantiate()
		var ents := inst.get_node_or_null("Entities") as Node2D
		var spr := inst.get_node_or_null("Entities/Player/Sprite") as Sprite2D
		var armor := inst.get_node_or_null("Entities/Player/Armor") as Sprite2D
		var weapon := inst.get_node_or_null("Entities/Player/Weapon") as Sprite2D
		if ents == null or not ents.y_sort_enabled:
			_err("slice has no y-sorted Entities root")
		elif spr == null or armor == null or weapon == null:
			_err("slice player is not a layered paper-doll (Sprite/Armor/Weapon)")
		elif spr.texture == null or not spr.texture.resource_path.ends_with("player_walk.png"):
			_err("slice sprite not wired to the player sheet")
		elif spr.hframes != 4 or spr.vframes != 8 or armor.hframes != 4 or weapon.hframes != 4:
			_err("slice paper-doll layers must all be 4x8 frames")
		elif inst.get_node_or_null("Entities/Player/Camera2D") == null:
			_err("slice has no follow Camera2D")
		elif ents.get_node_or_null("Cottage") == null or ents.get_node_or_null("Bram") == null:
			_err("slice missing baked props (cottage / NPC)")
		else:
			print("  [ok] slice scene: y-sorted entities, layered paper-doll + props")
		inst.free()
	if _fail == 0:
		print("\nRESULT: PASS — remaster slice assets + scene are wired")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)
