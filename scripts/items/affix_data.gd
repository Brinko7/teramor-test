extends Resource
class_name AffixData

## One rollable equipment affix (authored as a .tres under resources/affixes/).
## AffixRoller picks from the pool and stamps the magnitude onto a dropped item's
## bonus_* fields, scaled by the drop's tier. A PREFIX prepends its word
## ("Vicious Iron Sword"); a SUFFIX appends "of <word>" ("Iron Sword of Fury").

enum Slot { PREFIX, SUFFIX }
enum Target { ANY, WEAPON, ARMOR }
enum Stat { MELEE, RANGED, SPELL, MAX_HP, DEFENSE }

@export var id: StringName = &""
## Name fragment: a prefix adjective ("Vicious") or a suffix noun ("Fury").
@export var word: String = ""
@export var slot: Slot = Slot.PREFIX
## Which equipment this affix can roll on.
@export var target: Target = Target.ANY
@export var stat: Stat = Stat.MELEE
## Magnitude rolls in [base_min, base_max] + round(per_tier * (tier - 1)).
@export var base_min: int = 1
@export var base_max: int = 2
@export var per_tier: float = 1.0
## Relative pick weight within its slot/target bucket.
@export var weight: float = 1.0

## --- Status affixes ---------------------------------------------------------
## If status_kind != 0 (a StatusEffect.Kind) this is a STATUS affix: instead of a
## stat bonus it grants the weapon an on-hit status (e.g. Flaming -> Burn). `stat`
## is ignored for these.
@export var status_kind: int = 0
@export var status_power: int = 0          # DoT damage per tick
@export var status_duration: float = 3.0
@export_range(0.0, 1.0) var status_chance: float = 0.25
@export var status_magnitude: float = 1.0  # SLOW: speed multiplier

func is_status() -> bool:
	return status_kind != 0

## Can this affix roll on the given item?
func fits(item: Item) -> bool:
	match target:
		Target.WEAPON:
			return item.is_weapon()
		Target.ARMOR:
			return item.is_armor()
		_:
			return item.is_weapon() or item.is_armor()

## Roll a magnitude for the given tier.
func magnitude(tier: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(base_min, base_max) + int(round(per_tier * float(maxi(0, tier - 1))))
