extends Resource
class_name WorldLocation

## A named place on the world map — a hand-built destination scene (a town, the
## camp) that the player can fast-travel to once discovered. The graph of
## `connections` defines which locations are reachable from which. Authored as
## .tres under res://resources/world/locations/ and loaded by the WorldMap
## autoload.

@export var id: StringName = &""
@export var display_name: String = "Place"
@export_multiline var blurb: String = ""

## Destination scene and the spawn marker the player lands on there.
@export var scene_path: String = ""
@export var spawn_point: String = "spawn"

## Danger tier of the region: drives both the chance of a travel encounter and
## the difficulty of any creatures met on the way. 0 = safe (towns/camp).
@export var tier: int = 0

## Which kingdom / region of the world this place belongs to, for grouping on the
## map (e.g. &"hollenmark", &"plint", &"terakin", &"cursed_wilds"). Blank = ungrouped.
@export var region: StringName = &""

## What kind of place this is, for map labelling/iconography:
## &"camp" / &"town" / &"capital" / &"wild" / &"frontier" / &"landmark".
@export var kind: StringName = &"town"

## A place the world *knows about* but the player can't travel to yet — it shows on
## the map as a named, greyed "rumored" node (a distant capital, the Great Tree)
## to sell the world's scale, and becomes travelable once actually discovered.
@export var rumored: bool = false

## Ids of locations reachable from here by fast travel (and vice-versa is not
## assumed — list both directions if you want it symmetric).
@export var connections: PackedStringArray = PackedStringArray()

## Known from the start (the camp and the first town).
@export var discovered_by_default: bool = false

## BiomeData .tres used to generate an ambush area when a trip here is intercepted.
@export var travel_biome_path: String = ""
