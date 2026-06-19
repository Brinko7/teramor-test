extends Node

## Autoload `UIManager`. Single owner of the game's overlay panels.
##
## These used to be five separate autoloads (Dialogue, InventoryUI, CraftingUI,
## ShopUI, StorageUI), each registered individually in project.godot and reached
## as its own global. That spread UI lifecycle across the whole autoload list and
## made the set of always-resident singletons hard to see at a glance.
##
## UIManager instantiates them once at startup and parents them under itself, so
## there is now one UI autoload instead of five. Each panel keeps its own
## behaviour unchanged — it is still a CanvasLayer that processes while paused and
## handles its own toggle input — it is just owned here instead of by the engine
## directly. Reach a panel through its accessor:
##
##   UIManager.dialogue.start_conversation(...)
##   UIManager.shop.open(stock, name)
##   UIManager.storage.open()
##
## The self-toggling panels (inventory, crafting) need no external calls; they are
## instanced here only so their toggle input is live from the first frame.

const DIALOGUE_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const INVENTORY_SCENE := preload("res://scenes/ui/inventory_ui.tscn")
const CRAFTING_SCENE := preload("res://scenes/ui/crafting_ui.tscn")
const SHOP_SCRIPT := preload("res://scripts/autoload/shop_ui.gd")
const STORAGE_SCRIPT := preload("res://scripts/autoload/storage_ui.gd")

# Untyped on purpose: each panel exposes its own methods (is_active, open, ...)
# that are not on the CanvasLayer base, so access is dynamic — exactly as it was
# when these were stand-alone autoload singletons.
var dialogue
var inventory
var crafting
var shop
var storage

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue = DIALOGUE_SCENE.instantiate()
	inventory = INVENTORY_SCENE.instantiate()
	crafting = CRAFTING_SCENE.instantiate()
	shop = SHOP_SCRIPT.new()
	storage = STORAGE_SCRIPT.new()
	for panel: CanvasLayer in [dialogue, inventory, crafting, shop, storage]:
		add_child(panel)
