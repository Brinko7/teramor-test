extends Node
class_name Stats

## Progression component. Owns character level/XP, allocatable attributes, learned
## skill-tree nodes, and the derived combat stats that flow from all three. Attach
## as a child of an entity (the player) named "Stats".
##
## Derived = base growth (per level) + attributes (points the player allocates) +
## passive bonuses from learned SkillNodes (looked up in the Skills catalog). On a
## level-up the player earns attribute and skill points to spend.

## Emitted on any XP/level change so a HUD can refresh without polling.
signal stats_changed
## Emitted when attributes or learned skills change (the player re-syncs health and
## unlocked abilities off this; the menu refreshes).
signal skills_changed

## --- Level / XP -------------------------------------------------------------
var level: int = 1
var xp: int = 0
var xp_to_next: int = 0

## --- Base stats at level 1, and per-level growth ----------------------------
@export var base_max_hp: int = 20
@export var base_attack: int = 4
@export var base_defense: int = 0
@export var base_spell_power: int = 3

@export var hp_per_level: int = 6
@export var attack_per_level: int = 2
@export var defense_per_level: int = 1
@export var spell_per_level: int = 1

## --- Points & per-point attribute conversions -------------------------------
const ATTR_PER_LEVEL := 3
const SKILL_PER_LEVEL := 1
const START_ATTR_POINTS := 3
const START_SKILL_POINTS := 1
const MIGHT_MELEE := 2      ## melee attack per Might
const FINESSE_RANGED := 2   ## ranged power per Finesse
const VITALITY_HP := 5      ## max HP per Vitality
const ATTUNEMENT_SPELL := 2 ## spell power per Attunement

## --- Allocated character build (persisted) ----------------------------------
var might: int = 0
var finesse: int = 0
var vitality: int = 0
var attunement: int = 0
var attribute_points: int = 0
var skill_points: int = 0
var learned: Array[StringName] = []

## --- Derived (recomputed whenever the build changes) ------------------------
var max_hp: int = 0
var attack: int = 0
var ranged: int = 0
var defense: int = 0
var spell: int = 0

func _ready() -> void:
	add_to_group("persistent")
	# Starting kit of points so a fresh character has a first build choice.
	attribute_points = START_ATTR_POINTS
	skill_points = START_SKILL_POINTS
	_recompute_derived()
	xp_to_next = _xp_required(level)

## XP needed to advance FROM the given level to the next. Quadratic growth.
func _xp_required(for_level: int) -> int:
	return 50 + for_level * for_level * 10

# --- Derived stats ----------------------------------------------------------

func _recompute_derived() -> void:
	var grown: int = level - 1
	var b: Dictionary = _passive_bonuses()
	max_hp = base_max_hp + hp_per_level * grown + vitality * VITALITY_HP + int(b["hp_flat"])
	var melee_base: float = base_attack + attack_per_level * grown + might * MIGHT_MELEE + int(b["melee_flat"])
	attack = int(round(melee_base * (1.0 + float(b["melee_pct"]))))
	var ranged_base: float = finesse * FINESSE_RANGED + int(b["ranged_flat"])
	ranged = int(round(ranged_base * (1.0 + float(b["ranged_pct"]))))
	var spell_base: float = base_spell_power + spell_per_level * grown + attunement * ATTUNEMENT_SPELL + int(b["spell_flat"])
	spell = int(round(spell_base * (1.0 + float(b["spell_pct"]))))
	defense = base_defense + defense_per_level * grown + int(b["defense_flat"])

## Sum the passive modifiers of every learned skill node.
func _passive_bonuses() -> Dictionary:
	var agg: Dictionary = {
		"melee_flat": 0, "melee_pct": 0.0, "ranged_flat": 0, "ranged_pct": 0.0,
		"hp_flat": 0, "spell_flat": 0, "spell_pct": 0.0, "defense_flat": 0,
	}
	for node_id in learned:
		var node: SkillNode = Skills.get_node_data(node_id)
		if node == null:
			continue
		agg["melee_flat"] += node.melee_flat
		agg["melee_pct"] += node.melee_pct
		agg["ranged_flat"] += node.ranged_flat
		agg["ranged_pct"] += node.ranged_pct
		agg["hp_flat"] += node.hp_flat
		agg["spell_flat"] += node.spell_flat
		agg["spell_pct"] += node.spell_pct
		agg["defense_flat"] += node.defense_flat
	return agg

# --- XP / level -------------------------------------------------------------

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		attribute_points += ATTR_PER_LEVEL
		skill_points += SKILL_PER_LEVEL
		_recompute_derived()
		xp_to_next = _xp_required(level)
		Events.player_leveled_up.emit(level)
	stats_changed.emit()

## Death penalty: forfeit progress toward the current level (never drops a level).
func apply_death_penalty() -> void:
	xp = 0
	stats_changed.emit()

# --- Spending points --------------------------------------------------------

## Raise one attribute by a point. `attr` is "might"/"finesse"/"vitality"/"attunement".
func spend_attribute(attr: StringName) -> bool:
	if attribute_points <= 0:
		return false
	match attr:
		&"might": might += 1
		&"finesse": finesse += 1
		&"vitality": vitality += 1
		&"attunement": attunement += 1
		_: return false
	attribute_points -= 1
	_recompute_derived()
	skills_changed.emit()
	stats_changed.emit()
	return true

## Learn a skill node if its cost, level and prerequisites are met.
func learn_skill(node_id: StringName) -> bool:
	if not can_learn(node_id):
		return false
	var node: SkillNode = Skills.get_node_data(node_id)
	learned.append(node_id)
	skill_points -= node.cost
	_recompute_derived()
	skills_changed.emit()
	stats_changed.emit()
	return true

func is_learned(node_id: StringName) -> bool:
	return learned.has(node_id)

func can_learn(node_id: StringName) -> bool:
	if learned.has(node_id):
		return false
	var node: SkillNode = Skills.get_node_data(node_id)
	if node == null or skill_points < node.cost or level < node.required_level:
		return false
	for req in node.requires:
		if not learned.has(StringName(req)):
			return false
	return true

## Short reason a node can't be learned yet, for the menu (empty if learnable).
func locked_reason(node_id: StringName) -> String:
	var node: SkillNode = Skills.get_node_data(node_id)
	if node == null:
		return ""
	if level < node.required_level:
		return "Req. Lv %d" % node.required_level
	for req in node.requires:
		if not learned.has(StringName(req)):
			var rn: SkillNode = Skills.get_node_data(StringName(req))
			return "Req. %s" % (rn.display_name if rn != null else String(req))
	if skill_points < node.cost:
		return "Need %d pts" % node.cost
	return ""

# --- Combat queries ---------------------------------------------------------

func attack_power() -> int:
	return attack

func ranged_power() -> int:
	return ranged

func defense_power() -> int:
	return defense

func spell_power() -> int:
	return spell

## Fraction (0..1) toward the next level, for HUD bars.
func xp_progress() -> float:
	if xp_to_next <= 0:
		return 0.0
	return clampf(float(xp) / float(xp_to_next), 0.0, 1.0)

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "player_stats"

func save_state() -> Dictionary:
	var learned_out: Array = []
	for id in learned:
		learned_out.append(String(id))
	return {
		"level": level, "xp": xp,
		"might": might, "finesse": finesse, "vitality": vitality, "attunement": attunement,
		"attribute_points": attribute_points, "skill_points": skill_points,
		"learned": learned_out,
	}

func load_state(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	might = int(data.get("might", 0))
	finesse = int(data.get("finesse", 0))
	vitality = int(data.get("vitality", 0))
	attunement = int(data.get("attunement", 0))
	attribute_points = int(data.get("attribute_points", 0))
	skill_points = int(data.get("skill_points", 0))
	learned.clear()
	for id in data.get("learned", []):
		learned.append(StringName(id))
	_recompute_derived()
	xp_to_next = _xp_required(level)
	skills_changed.emit()
	stats_changed.emit()
