extends SceneTree

## Headless validation for shop business hours (task #31). Run with:
##   godot --headless --path <project> -s res://tools/validate_shop_hours.gd
##
## Instantiates the shop interior on-tree, then walks the clock across a full day
## and asserts:
##   * the merchant resolved its OPEN/CLOSED placard (status_sign_path wired);
##   * `is_open()` is true only within [open_hour, close_hour);
##   * the placard frame tracks it (0 = open/green, 1 = closed/red) as the
##     `hour_changed` signal fires.

const SHOP := "res://scenes/world/shop_interior.tscn"

var _fail := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== shop hours validation ===")
	var ps := load(SHOP) as PackedScene
	if ps == null:
		_err("cannot load %s" % SHOP)
		_done()
		return
	var inst := ps.instantiate()
	root.add_child(inst)
	await process_frame

	var merchant := _find(inst)
	if merchant == null:
		_err("merchant (a node with interact + is_open) not found")
		_done()
		return
	var sign_node = merchant.get("_sign")
	if sign_node == null:
		_err("merchant did not resolve its StatusSign — check status_sign_path")

	var tm := root.get_node_or_null("TimeManager")
	if tm == null:
		_err("TimeManager autoload missing")
		_done()
		return

	var oh: int = int(merchant.get("open_hour"))
	var ch: int = int(merchant.get("close_hour"))
	print("  posted hours: %02d:00 - %02d:00" % [oh, ch])

	for h in [0, 6, 7, 8, 9, 12, 17, 18, 19, 23]:
		tm.load_state({"day": 1, "minutes": h * 60})
		tm.hour_changed.emit(h)  # drive the merchant's live refresh
		var want_open: bool = h >= oh and h < ch
		var got_open: bool = merchant.is_open()
		if got_open != want_open:
			_err("%02d:00 — is_open()=%s, want %s" % [h, got_open, want_open])
			continue
		if sign_node != null:
			var want_frame: int = 0 if want_open else 1
			if int(sign_node.frame) != want_frame:
				_err("%02d:00 — placard frame=%d, want %d" % [h, int(sign_node.frame), want_frame])
				continue
		print("  [ok] %02d:00 -> %s" % [h, "OPEN" if want_open else "closed"])

	_done()

func _done() -> void:
	if _fail == 0:
		print("\nRESULT: PASS — shop trades only within posted hours; placard matches")
	else:
		print("\nRESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _find(node: Node) -> Node:
	if node.has_method("interact") and node.has_method("is_open"):
		return node
	for c in node.get_children():
		var hit := _find(c)
		if hit != null:
			return hit
	return null
