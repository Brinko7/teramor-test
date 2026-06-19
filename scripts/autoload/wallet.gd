extends Node

## Autoload `Wallet`. The player's coin purse. Gold is the single currency:
## monster contracts and selling loot pay into it; the trader's wares spend it.
## Implements the SaveManager "persistent" contract.

signal changed(balance: int)

## Coin a fresh character starts with — enough for one early purchase.
const STARTING_GOLD := 50

var _gold: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("persistent")

func get_gold() -> int:
	return _gold

## Add (or, with a negative amount, deduct) coin, never dropping below zero.
func add(amount: int) -> void:
	if amount == 0:
		return
	_gold = maxi(0, _gold + amount)
	changed.emit(_gold)

func can_afford(amount: int) -> bool:
	return _gold >= amount

## Spend `amount` only if the purse can cover it. Returns true on success.
func spend(amount: int) -> bool:
	if amount < 0 or _gold < amount:
		return false
	_gold -= amount
	changed.emit(_gold)
	return true

## Reset to the new-game starting purse.
func reset() -> void:
	_gold = STARTING_GOLD
	changed.emit(_gold)

# --- Persistence (SaveManager "persistent" contract) ------------------------

func get_save_id() -> String:
	return "wallet"

func save_state() -> Dictionary:
	return {"gold": _gold}

func load_state(data: Dictionary) -> void:
	_gold = int(data.get("gold", 0))
	changed.emit(_gold)
