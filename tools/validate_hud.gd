extends SceneTree

## Guard test: every playable world scene (one that instances the player) must
## carry the full player HUD set — health bar, mana bar, coin counter, clock, and
## the item hotbar. Walking into an area should never drop the overlay.
##
## This bug shipped once on `road.tscn` (only the clock was present, so health/
## mana/coins/hotbar vanished while crossing between settlement and town). The HUD
## is instanced per-scene by hand, which is easy to forget when authoring a new
## area — and the world is about to expand a lot. This asserts the omission can't
## come back silently.
##
## Pure text scan via FileAccess (no scene instantiation, no autoload access), so
## it is immune to the frame-0 autoload-compile trap.

const WORLD_DIR := "res://scenes/world"
const PLAYER_SCENE := "res://scenes/entities/player.tscn"
const HUD_PIECES := {
	"health bar": "res://scenes/ui/health_bar.tscn",
	"mana bar": "res://scenes/ui/mana_bar.tscn",
	"coin counter": "res://scenes/ui/hud_coins.tscn",
	"clock": "res://scenes/ui/hud_clock.tscn",
	"item hotbar": "res://scenes/ui/item_hotbar.tscn",
}

var _fail := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var dir := DirAccess.open(WORLD_DIR)
	if dir == null:
		print("FAIL: cannot open %s" % WORLD_DIR)
		_done()
		return
	var checked := 0
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var path := "%s/%s" % [WORLD_DIR, file]
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			print("FAIL: cannot read %s" % path)
			_fail += 1
			continue
		# Only playable areas (those that place the player) need the HUD.
		if not text.contains(PLAYER_SCENE):
			continue
		checked += 1
		for label in HUD_PIECES:
			if not text.contains(HUD_PIECES[label]):
				print("FAIL: %s is missing the %s HUD" % [file, label])
				_fail += 1
	if _fail == 0:
		print("RESULT: PASS - all %d player-bearing world scenes carry the full HUD" % checked)
	else:
		print("RESULT: FAIL - %d HUD gap(s)" % _fail)
	_done()

func _done() -> void:
	quit()
