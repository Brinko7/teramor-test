extends SceneTree

## Headless validation of SaveManager.capture_subtree / apply_subtree — the
## mechanism that carries the player's gear/stats/inventory across a scene swap
## (change_scene_to_file rebuilds the player from authored defaults).
##
## Uses a synthetic player-like subtree with NO game class_names, so it never
## triggers the frame-0 autoload-compile trap. Asserts:
##   * every persistent descendant is captured, keyed by save id
##   * non-persistent children are ignored
##   * restore writes the captured values back
##   * the ROOT node restores LAST (children first), because the real player
##     recomputes max-HP from its Stats/Equipment children on load_state.

var _fail := 0

class FakeNode extends Node:
	var sid: String
	var value: int = 0
	var order_log: Array  # shared sink (Arrays are by-ref) recording load order
	func get_save_id() -> String: return sid
	func save_state() -> Dictionary: return {"value": value}
	func load_state(data: Dictionary) -> void:
		value = int(data.get("value", value))
		order_log.append(sid)

func _err(msg: String) -> void:
	_fail += 1
	print("FAIL: ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _make(name: String, sid: String, value: int, log: Array, persistent: bool) -> FakeNode:
	var n := FakeNode.new()
	n.name = name
	n.sid = sid
	n.value = value
	n.order_log = log
	if persistent:
		n.add_to_group("persistent")
	return n

func _run() -> void:
	await process_frame
	var sm = load("res://scripts/autoload/save_manager.gd").new()
	get_root().add_child(sm)

	var order: Array = []
	var player := _make("Player", "player", 7, order, true)
	var stats := _make("Stats", "player_stats", 11, order, true)
	var equip := _make("Equipment", "player_equipment", 13, order, true)
	var cosmetic := _make("Visuals", "visuals", 99, order, false)  # must be ignored
	player.add_child(stats)
	player.add_child(equip)
	player.add_child(cosmetic)
	get_root().add_child(player)

	# 1) Capture grabs exactly the persistent nodes.
	var snap: Dictionary = sm.capture_subtree(player)
	if snap.size() != 3:
		_err("expected 3 persistent entries, got %d (%s)" % [snap.size(), str(snap.keys())])
	if not (snap.has("player") and snap.has("player_stats") and snap.has("player_equipment")):
		_err("capture missing expected ids: %s" % str(snap.keys()))
	if snap.has("visuals"):
		_err("capture wrongly included a non-persistent node")

	# 2) Mutate, then restore from the snapshot.
	player.value = 0
	stats.value = 0
	equip.value = 0
	cosmetic.value = 0
	order.clear()
	sm.apply_subtree(player, snap)
	if player.value != 7:
		_err("player value not restored (%d)" % player.value)
	if stats.value != 11:
		_err("stats value not restored (%d)" % stats.value)
	if equip.value != 13:
		_err("equipment value not restored (%d)" % equip.value)
	if cosmetic.value != 0:
		_err("non-persistent node was wrongly restored (%d)" % cosmetic.value)

	# 3) Ordering: root (player) loads LAST so it sees restored children.
	if order.is_empty() or order[-1] != "player":
		_err("player did not restore last; order=%s" % str(order))
	if order.find("player") < order.find("player_stats"):
		_err("player restored before stats; order=%s" % str(order))
	if order.find("player") < order.find("player_equipment"):
		_err("player restored before equipment; order=%s" % str(order))

	# 4) Empty snapshot is a safe no-op.
	sm.apply_subtree(player, {})

	if _fail == 0:
		print("RESULT: PASS - capture/restore carries persistent subtree, root loads last")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
