extends Area2D

## A reusable trigger that sends the player into a procedurally-generated wild
## area (via TravelManager). Drop one at the edge of a town/camp, point it at a
## BiomeData, and set the tier and the location the player returns to. Mirrors
## transition_zone's collision setup (layer 0, mask = player body).

@export var biome_path: String = ""
@export var tier: int = 2
## The named location the area's exits return the player to.
@export var return_location: StringName = &""

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	if biome_path.is_empty() or not ResourceLoader.exists(biome_path):
		push_warning("explore_zone: missing biome '%s'" % biome_path)
		return
	_triggered = true
	var biome := load(biome_path) as BiomeData
	TravelManager.enter_area(biome, tier, return_location, true)
