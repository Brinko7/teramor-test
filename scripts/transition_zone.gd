extends Area2D
## Reusable AUTO-TRIGGER zone. When the player body enters, ask the SceneManager
## autoload to travel to `target_scene`, placing the player on the Marker2D named
## `target_spawn` in the destination scene.
##
## Triggers are ignored while SceneManager is mid-placement (`SceneManager.placing`),
## so a return marker that happens to sit inside a door zone doesn't bounce the
## player straight back through the door — the "stuck, can't exit the building"
## soft-lock. The spawn-overlap fires `body_entered` once during placement (ignored
## here); it won't fire again until the player steps out and walks back in.
##
## Collision: layer=0, mask=bit2 (player body). Resize the child CollisionShape2D
## per placement.

@export var target_scene: String = ""
@export var target_spawn: String = ""
## If set, this door stays hidden + inert until the named Story flag is set, so a
## route can be sealed until the world opens it (e.g. the road to the camp only
## appears once the camp has been discovered). Re-evaluated each time the scene loads.
@export var require_flag: StringName = &""

var _triggered: bool = false

func _ready() -> void:
	if require_flag != &"" and not _flag_set():
		visible = false
		set_deferred("monitoring", false)
		return
	body_entered.connect(_on_body_entered)

func _flag_set() -> bool:
	var story := get_node_or_null("/root/Story")
	return story != null and story.has_method("has_flag") and story.call("has_flag", require_flag)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	var sm := get_node_or_null("/root/SceneManager")
	# Ignore the overlap created by being spawned onto a marker mid-transition.
	if sm != null and sm.get("placing"):
		return
	if target_scene.is_empty():
		push_warning("transition_zone: no target_scene set")
		return
	_triggered = true
	if sm != null and sm.has_method("travel"):
		sm.travel(target_scene, target_spawn)
	else:
		push_warning("transition_zone: SceneManager autoload not found")
		_triggered = false
