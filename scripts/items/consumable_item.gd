extends Item
class_name ConsumableItem

## A single-use item. Returns true if it was consumed (so the caller can
## decrement the stack).

@export var heal: int = 0

## --- Food buff (optional) ---------------------------------------------------
## A cooked dish can grant a timed combat buff on top of any heal. buff_stat is a
## PlayerBuffs.Stat (-1 = none); buff_amount is the bonus (HP/sec for REGEN).
@export var buff_stat: int = -1
@export var buff_amount: int = 0
@export var buff_duration: float = 0.0

const BUFF_NAMES := ["Melee", "Ranged", "Spell", "Defense", "Max HP", "Speed", "Regen"]

func has_buff() -> bool:
	return buff_stat >= 0 and buff_amount != 0 and buff_duration > 0.0

func use(user: Node) -> bool:
	var consumed := false
	if heal > 0 and user.has_node("Health"):
		(user.get_node("Health") as Health).heal(heal)
		consumed = true
	if has_buff() and user.has_node("Buffs"):
		user.get_node("Buffs").apply(buff_stat, buff_amount, buff_duration)
		consumed = true
	return consumed

## Human-readable buff line for tooltips, e.g. "+4 Melee for 90s".
func buff_line() -> String:
	if not has_buff() or buff_stat >= BUFF_NAMES.size():
		return ""
	if buff_stat == PlayerBuffs.Stat.REGEN:
		return "Regen %d HP/s for %ds" % [buff_amount, int(buff_duration)]
	return "+%d %s for %ds" % [buff_amount, BUFF_NAMES[buff_stat], int(buff_duration)]
