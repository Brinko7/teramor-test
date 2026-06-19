extends Item
class_name ConsumableItem

## A single-use item. Returns true if it was consumed (so the caller can
## decrement the stack).

@export var heal: int = 0

func use(user: Node) -> bool:
	if heal > 0 and user.has_node("Health"):
		var hp: Health = user.get_node("Health")
		hp.heal(heal)
		return true
	return false
