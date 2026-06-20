extends Resource
class_name EncounterData

## An authored "setpiece" — a small, hand-arranged cluster of enemies (and optional
## decor) dropped into a generated area as a single intentional beat: a wolf pack, a
## bear with its cubs, a bandit camp. The generator places a few of these with big
## calm gaps between them (see ProceduralArea), so the wilds read as semi-peaceful
## punctuated by designed encounters rather than a uniform sprinkle of foes.
##
## Positions are LOCAL offsets from an anchor the generator chooses; this resource
## just describes the formation. Enemy/prop arrays are parallel to their offset
## arrays (matching the BiomeData enemy_paths/enemy_weights convention); a missing or
## short offsets array falls back to a tight scatter around the anchor.

@export var id: StringName = &""
@export var display_name: String = "Encounter"

## Enemy scene paths and their local offsets from the anchor (parallel arrays).
@export var enemy_paths: PackedStringArray = PackedStringArray()
@export var enemy_offsets: PackedVector2Array = PackedVector2Array()

## Decorative/obstacle prop scene paths and their local offsets (parallel arrays).
## Used to dress a setpiece — tents and a campfire for a bandit camp, say.
@export var prop_paths: PackedStringArray = PackedStringArray()
@export var prop_offsets: PackedVector2Array = PackedVector2Array()

## Drop a treasure chest (biome loot) — the reward for clearing a camp. The
## generator fills it from the biome's loot_paths.
@export var loot_cache: bool = false
## Local offset of the loot-cache chest from the anchor (tuck it between tents,
## behind the fire, etc. so it doesn't overlap decor).
@export var loot_offset: Vector2 = Vector2.ZERO

## Minimum area tier this encounter may appear at (gate dangerous beats deeper in).
@export var min_tier: int = 1
## Selection weight when the generator picks which encounter to place.
@export var weight: float = 1.0
## Clearance radius (px) — how much open space this setpiece wants around its
## anchor, so the generator can keep encounters from crowding each other or edges.
@export var radius: float = 80.0

## Local offset for the i-th enemy, or a small deterministic scatter if unspecified.
func enemy_offset(i: int) -> Vector2:
	if i < enemy_offsets.size():
		return enemy_offsets[i]
	var ang: float = float(i) * 2.4
	return Vector2(cos(ang), sin(ang)) * (18.0 + 8.0 * float(i))

## Local offset for the i-th prop, or zero if unspecified.
func prop_offset(i: int) -> Vector2:
	if i < prop_offsets.size():
		return prop_offsets[i]
	return Vector2.ZERO
