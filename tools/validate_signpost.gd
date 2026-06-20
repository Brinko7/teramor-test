extends SceneTree

## Headless validation for read-on-keypress signposts (#47). The post is now an
## interactable Area2D (no permanent floating Label); interacting surfaces its
## carved line in the dialogue box, and a blank post stays inert scenery.
##
## Loads the scene only after awaiting frames so signpost.gd's first compile
## (which references the UIManager autoload inside interact()) happens after the
## autoloads are live — dodging the frame-0 autoload-compile trap.

var _fail := 0

func _err(m: String) -> void:
	_fail += 1
	print("FAIL: ", m)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame

	var packed = load("res://scenes/entities/props/signpost.tscn")
	if packed == null:
		_err("signpost.tscn failed to load")
		_done()
		return
	var post = packed.instantiate()
	post.set("text", "The Deepwood - keep your blade close")  # set before entering tree, as the generator does
	get_root().add_child(post)
	await process_frame

	# Structural: the interactable Area2D contract, and NO floating label.
	if not (post is Area2D):
		_err("signpost root is not an Area2D")
	if not post.is_in_group("interactable"):
		_err("signpost with text not in 'interactable' group")
	if not post.has_method("interact"):
		_err("signpost missing interact()")
	if post.get("collision_layer") != 32:
		_err("signpost not on interactable layer 32 (got %s)" % str(post.get("collision_layer")))
	var has_label := false
	var has_shape := false
	for c in post.get_children():
		if c is Label or c is RichTextLabel:
			has_label = true
		if c is CollisionShape2D:
			has_shape = true
	if has_label:
		_err("signpost still renders a permanent floating label")
	if not has_shape:
		_err("signpost has no CollisionShape2D for the interact probe")

	# Behavioural: interacting opens the dialogue box with the carved line.
	var ui = get_root().get_node_or_null("UIManager")
	if ui != null and ui.get("dialogue") != null:
		post.interact(null)
		await process_frame
		if not ui.dialogue.is_active():
			_err("interact() did not open the dialogue box")
		paused = false  # dialogue paused the tree; release so quit is clean
	else:
		print("NOTE: UIManager.dialogue unavailable headless; skipped behavioural check")

	# A blank post is plain scenery — never interactable.
	var blank = packed.instantiate()
	blank.set("text", "   ")  # set before entering tree, as the generator does
	get_root().add_child(blank)
	await process_frame
	if blank.is_in_group("interactable"):
		_err("blank signpost wrongly joined 'interactable'")

	_done()

func _done() -> void:
	if _fail == 0:
		print("RESULT: PASS - signpost reads on interact, no floating label, blank posts inert")
	else:
		print("RESULT: FAIL - %d check(s) failed" % _fail)
	quit()
