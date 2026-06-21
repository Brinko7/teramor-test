extends Area2D

## A reusable trigger that sends the player into a procedurally-generated wild
## area (via TravelManager). Drop one at the edge of a town/camp, point it at a
## BiomeData, and set the tier and the location the player returns to. Mirrors
## transition_zone's collision setup (layer 0, mask = player body).

@export var biome_path: String = ""
@export var tier: int = 2
## The named location the area's exits return the player to.
@export var return_location: StringName = &""
## If set, this zone is a one-way **journey** rather than a there-and-back
## excursion: the generated area has a single "Continue →" gate at the far side
## that *arrives at (and discovers)* this location — the way you cross a long wild
## stretch to reach the next town/frontier. Leave blank for a normal excursion.
@export var journey_to: StringName = &""
## If set, this zone stays hidden + inert until the named Story flag is set — used
## for a secret route the world only opens once the player has earned it (e.g. the
## hidden trail to the camp, revealed by the tavern contact). Re-checked on each load.
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
	if _triggered or not body.is_in_group("player"):
		return
	if biome_path.is_empty() or not ResourceLoader.exists(biome_path):
		push_warning("explore_zone: missing biome '%s'" % biome_path)
		return
	_triggered = true
	var biome := load(biome_path) as BiomeData
	if journey_to != &"":
		# One-way crossing: the far "Continue" gate arrives at (discovers) journey_to.
		TravelManager.enter_area(biome, tier, journey_to, false)
	else:
		TravelManager.enter_area(biome, tier, return_location, true)
