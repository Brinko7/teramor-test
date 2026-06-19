extends Resource
class_name NpcData

## Declarative description of a friendly NPC. An `npc.tscn` instance points its
## `data` export at one of these resources; `npc.gd` turns the data plus live
## game state (friendship, story flags, the player's bag) into a branching
## conversation. Adding a townsfolk is therefore "author one .tres + drop an
## instance" — no new script required for ordinary villagers.

@export var id: StringName = &""
@export var display_name: String = "Villager"
@export var title: String = ""

## Optional sprite swaps so several NPCs can share npc.tscn but look distinct.
@export var sprite_texture: Texture2D = null
@export var tint: Color = Color.WHITE

## Shown the very first time the player talks to this NPC.
@export_multiline var met_line: String = ""

## Standing line shown above the choice menu, and a sign-off when leaving.
@export_multiline var greeting: String = "Hello there."
@export_multiline var farewell: String = "Safe travels."

## Friendship-gated small talk. Keys are minimum heart counts (int), values are
## PackedStringArray lines; the highest key the player has reached is used.
@export var talk_lines: Dictionary = {}

## Gift preferences, matched against Item.id.
@export var loved_gifts: Array[StringName] = []
@export var liked_gifts: Array[StringName] = []
@export var disliked_gifts: Array[StringName] = []

## Reaction lines, with "%s" optionally substituted by the item name.
@export_multiline var loved_line: String = "This is wonderful — thank you!"
@export_multiline var liked_line: String = "Oh, how thoughtful. Thank you."
@export_multiline var disliked_line: String = "Ah... well. I appreciate the thought."
@export_multiline var neutral_line: String = "For me? That's kind of you."

## Story conversation topics. Each entry is a Dictionary understood by npc.gd:
##   label            String   choice text in the menu
##   lines            Array    PackedStringArray spoken when chosen
##   require_flag     String   (optional) only offered when this Story flag is set
##   forbid_flag      String   (optional) hidden once this Story flag is set
##   require_hearts   int      (optional) minimum hearts to offer
##   set_flag         String   (optional) Story flag set after the topic plays
##   story_beat       String   (optional) Story beat fired (advances STORY quests)
##   affinity         int      (optional) friendship points granted (once, via set_flag)
##   start_quest      String   (optional) resource path of a Quest to start
@export var topics: Array[Dictionary] = []

## Returns the small-talk line set appropriate to the current heart count.
func talk_lines_for_hearts(hearts: int) -> PackedStringArray:
	var best_key: int = -1
	for key: Variant in talk_lines.keys():
		var threshold: int = int(key)
		if threshold <= hearts and threshold > best_key:
			best_key = threshold
	if best_key < 0:
		return PackedStringArray()
	return PackedStringArray(talk_lines[best_key])

## Classify a gift by item id: "loved" | "liked" | "disliked" | "neutral".
func gift_reaction(item_id: StringName) -> String:
	if loved_gifts.has(item_id):
		return "loved"
	if liked_gifts.has(item_id):
		return "liked"
	if disliked_gifts.has(item_id):
		return "disliked"
	return "neutral"
