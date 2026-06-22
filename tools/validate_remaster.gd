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
	# 2. slice scene instantiates with a player sprite wired to the sheet
	var scene := load(SLICE) as PackedScene
	if scene == null or not scene.can_instantiate():
		_err("remaster_slice.tscn missing / cannot instantiate")
	else:
		var inst := scene.instantiate()
		var spr := inst.get_node_or_null("Player/Sprite") as Sprite2D
		if spr == null:
			_err("slice has no Player/Sprite")
		elif spr.texture == null or not spr.texture.resource_path.ends_with("player_walk.png"):
			_err("slice sprite not wired to the player sheet")
		elif spr.hframes != 4 or spr.vframes != 8:
			_err("slice sprite frames are %dx%d, want 4x8" % [spr.hframes, spr.vframes])
		elif inst.get_node_or_null("Player/Camera2D") == null:
			_err("slice has no follow Camera2D")
		else:
			print("  [ok] slice scene: player sprite + camera wired")
		inst.free()
	if _fail == 0:
		print("\nRESULT: PASS — remaster slice assets + scene are wired")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)
