extends SceneTree

## Headless smoke test for player character-creation customization — notably the
## new beard layer. The beard sheets are referenced by STRING (built from the
## style id), so a typo'd path would fail silently; this asserts every option's
## sheet exists, the profile round-trips the choice through the save contract, and
## both the player and creation scenes carry the Beard sprite layer.
##   godot --headless --path <project> -s res://tools/validate_customization.gd

const PROFILE := "res://scripts/autoload/player_profile.gd"
const PLAYER_SCENE := "res://scenes/entities/player.tscn"
const CREATION_SCENE := "res://scenes/ui/character_creation.tscn"

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	print("=== player customization validation ===")
	_check_profile()
	_check_scene_layers()
	if _fail == 0:
		print("\nRESULT: PASS — beard customization wired end to end")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _check_profile() -> void:
	print("\n[profile] beard options + persistence")
	var script: GDScript = load(PROFILE)
	if script == null:
		_err("player_profile.gd failed to load")
		return
	var p: Object = script.new()           # a bare Node; _ready (group add) not run
	var styles: Array = p.BEARD_STYLES
	if styles.is_empty() or styles[0] != "none":
		_err("BEARD_STYLES should start with 'none' (got %s)" % str(styles))
	# 1. every non-none beard has a baked sheet, and beard_texture() resolves it.
	for style: String in styles:
		p.beard_style = style
		var tex = p.beard_texture()
		if style == "none":
			if tex != null:
				_err("'none' should yield no beard texture")
		else:
			var path := "res://assets/placeholder/char/beard_%s.png" % style
			if not ResourceLoader.exists(path):
				_err("missing beard sheet: " + path)
			if tex == null:
				_err("beard_texture() returned null for '%s'" % style)
	# 2. the choice survives a save/load round-trip.
	p.apply("Test", Color("a6724e"), Color("7e3a24"), "long", "goatee")
	if p.beard_style != "goatee":
		_err("apply() did not set beard_style")
	var snap: Dictionary = p.save_state()
	if not snap.has("beard_style"):
		_err("save_state() omits beard_style")
	var q: Object = script.new()
	q.load_state(snap)
	if q.beard_style != "goatee":
		_err("beard_style did not round-trip through save/load (got '%s')" % q.beard_style)
	# 3. a pre-beard save (no key) loads as the safe default.
	var r: Object = script.new()
	r.load_state({"name": "Old", "hair_style": "short"})
	if r.beard_style != "none":
		_err("a legacy save without beard_style should default to 'none'")
	if _fail == 0:
		print("  [ok] %d beard options, all sheets present, round-trips clean" % styles.size())

## Both scenes must carry the Beard layer. Checked against the scene TEXT (robust,
## and avoids instantiating the player — which pulls autoloads not ready at frame 0).
func _check_scene_layers() -> void:
	print("\n[scenes] Beard layer present")
	_assert_in_file(PLAYER_SCENE, '[node name="Beard" type="Sprite2D" parent="."]',
		"player scene is missing the Beard sprite layer")
	_assert_in_file(CREATION_SCENE, '[node name="Beard" type="Sprite2D" parent="Preview"]',
		"creation preview is missing the Beard sprite")
	_assert_in_file(CREATION_SCENE, '[node name="BeardRow"',
		"creation screen is missing the BeardRow picker")

func _assert_in_file(path: String, needle: String, msg: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_err("could not open " + path)
		return
	var text := f.get_as_text()
	f.close()
	if not text.contains(needle):
		_err(msg)
	else:
		print("  [ok] %s" % needle)
