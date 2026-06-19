extends Area2D
## Reusable AUTO-TRIGGER zone. When the player body enters, ask the
## SceneManager autoload to travel to `target_scene`, placing the player on
## the Marker2D named `target_spawn` in the destination scene.
##
## Collision: layer=0, mask=bit2 (player body). Resize the child
## CollisionShape2D per placement.

@export var target_scene: String = ""
@export var target_spawn: String = ""

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	if target_scene.is_empty():
		push_warning("transition_zone: no target_scene set")
		return
	_triggered = true
	var sm := get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("travel"):
		sm.travel(target_scene, target_spawn)
	else:
		push_warning("transition_zone: SceneManager autoload not found")
		_triggered = false
