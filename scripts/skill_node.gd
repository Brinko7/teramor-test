extends Resource
class_name SkillNode

## One node in the character skill tree. A node can grant passive combat bonuses,
## unlock an elemental ability, or both. Nodes live in one of three branches and
## may require other nodes (and a minimum level) before they can be learned.
## Authored as .tres under res://resources/skills/ and loaded by the Skills
## autoload. Bonuses are plain fields (not a Dictionary) so the .tres stay simple.

enum Branch { WARFARE, MARKSMANSHIP, ELEMENTALISM }

@export var id: StringName = &""
@export var display_name: String = "Skill"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export var branch: Branch = Branch.WARFARE
@export var cost: int = 1
@export var required_level: int = 1
## Node ids that must be learned first.
@export var requires: PackedStringArray = PackedStringArray()

## --- Passive bonuses (summed across learned nodes by Stats) ------------------
@export var melee_flat: int = 0
@export var melee_pct: float = 0.0
@export var ranged_flat: int = 0
@export var ranged_pct: float = 0.0
@export var hp_flat: int = 0
@export var spell_flat: int = 0
@export var spell_pct: float = 0.0
@export var defense_flat: int = 0

## --- Ability unlock ---------------------------------------------------------
## If set, learning this node makes that ability (by AbilityData id) castable.
@export var unlock_ability_id: StringName = &""

func is_ability() -> bool:
	return unlock_ability_id != &""
