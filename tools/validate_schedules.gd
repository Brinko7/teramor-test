extends SceneTree

## Headless validation for NPC homes + daily routines (task #30). Run with:
##   godot --headless --path <project> -s res://tools/validate_schedules.gd
##
## Proves the scheduling loop end-to-end on the real scenes:
##   1. Every waypoint name an NPC references (schedule values + home_waypoint)
##      resolves to a real Marker2D in the "npc_waypoint" group.
##   2. On load each routed NPC SNAPS to the marker for the current period — this
##      is the decisive check that `.tscn` integer dict keys (`0:`, `1:`…) match
##      `TimeManager.get_period()`, i.e. the schedule actually drives placement
##      rather than silently falling back to home.
##   3. Firing `period_changed` for every period retargets the NPC to that
##      period's marker (the walk destination), again with no missing fallbacks.
##
## Like the variance check, this drives from a coroutine and `await process_frame`
## after add_child so npc.gd `_setup_schedule` (a `_ready` effect) has run.

const TOWN := "res://scenes/world/town.tscn"
const SETTLEMENT := "res://scenes/world/settlement.tscn"

var _fail := 0
var _routed := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== npc schedule validation ===")
	await _check(TOWN, "town")
	await _check(SETTLEMENT, "settlement")
	print("\n[summary] %d routed NPC(s) checked across 4 periods each" % _routed)
	if _fail == 0:
		print("RESULT: PASS — every routine resolves; NPCs snap to their period's spot")
	else:
		print("RESULT: FAIL — %d problem(s)" % _fail)
	quit(_fail)

func _err(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)

func _check(path: String, tag: String) -> void:
	print("\n[%s]" % tag)
	if not ResourceLoader.exists(path):
		_err("%s: missing scene %s" % [tag, path])
		return
	var ps := load(path) as PackedScene
	var inst := ps.instantiate()
	root.add_child(inst)
	# Let npc.gd `_ready`/`_setup_schedule` run (deferred past _initialize).
	await process_frame

	var markers: Dictionary = {}
	for n in get_nodes_in_group("npc_waypoint"):
		if n is Node2D:
			markers[String(n.name)] = (n as Node2D).global_position

	var npcs: Array = []
	_collect_npcs(inst, npcs)

	# Per-period occupancy: waypoint name -> [npc names] routed there. Two NPCs on
	# the same spot in the same period read as one blob, not a living town.
	var occupancy: Array = [{}, {}, {}, {}]

	for npc in npcs:
		var sched: Dictionary = npc.get("schedule")
		var home: String = String(npc.get("home_waypoint"))
		if sched.is_empty() and home == "":
			continue  # intentionally stationary (legacy townsfolk) — fine
		_routed += 1
		var nm: String = String(npc.name)

		# 1) every referenced waypoint exists
		var refs: Array = []
		if home != "":
			refs.append(home)
		for k in sched:
			var w: String = String(sched[k])
			if w != "":
				refs.append(w)
		for w in refs:
			if not markers.has(w):
				_err("%s/%s references missing waypoint '%s'" % [tag, nm, w])

		# 2) snapped to the current period's marker on load
		var period: int = _current_period()
		var want_name: String = String(sched.get(period, home))
		if want_name == "":
			want_name = home
		if markers.has(want_name):
			var got: Vector2 = (npc as Node2D).global_position
			var want: Vector2 = markers[want_name]
			if got.distance_to(want) > 1.5:
				_err("%s/%s did NOT snap to '%s' for period %d (at %s, want %s) — schedule key likely not matching get_period()" % [tag, nm, want_name, period, got, want])
			else:
				print("  [ok] %s snapped to %s (period %d)" % [nm, want_name, period])

		# 3) each period retargets to a resolvable marker
		for p in range(4):
			var tgt_name: String = String(sched.get(p, home))
			if tgt_name == "":
				continue  # explicit "stay home" via empty -> home position, allowed
			if not markers.has(tgt_name):
				_err("%s/%s period %d -> missing waypoint '%s'" % [tag, nm, p, tgt_name])
				continue
			npc._on_period_changed(p)
			var tp: Vector2 = npc.get("_target_position")
			if tp.distance_to(markers[tgt_name]) > 1.5:
				_err("%s/%s period %d retarget mismatch (got %s, want %s)" % [tag, nm, p, tp, markers[tgt_name]])
			var bucket: Dictionary = occupancy[p]
			if not bucket.has(tgt_name):
				bucket[tgt_name] = []
			bucket[tgt_name].append(nm)

	# 4) no two NPCs share a *public* waypoint in the same period (no daytime
	#    blobbing). Homes are exempt: families share a house, so `home_*` markers
	#    may hold more than one resident (e.g. a parent and child at night).
	for p in range(4):
		for wp in occupancy[p]:
			if String(wp).begins_with("home_"):
				continue
			var who: Array = occupancy[p][wp]
			if who.size() > 1:
				_err("%s period %d: %d NPCs stack on '%s' (%s)" % [tag, p, who.size(), wp, ", ".join(who)])

	inst.queue_free()

## TimeManager is an autoload node; resolve it at runtime since a standalone
## `-s` tool script doesn't get autoload names bound at compile time. A fresh
## clock starts at 06:00 -> MORNING (0).
func _current_period() -> int:
	var tm := root.get_node_or_null("TimeManager")
	return tm.get_period() if tm != null else 0

func _collect_npcs(node: Node, out: Array) -> void:
	if node.has_method("_resolve_target") and node.has_method("interact"):
		out.append(node)
	for c in node.get_children():
		_collect_npcs(c, out)
