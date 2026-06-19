extends Node

## Autoload `UIManager`. Single owner of the game's overlay panels.
##
## These used to be five separate autoloads (Dialogue, InventoryUI, CraftingUI,
## ShopUI, StorageUI), each registered individually in project.godot and reached
## as its own global. That spread UI lifecycle across the whole autoload list and
## made the set of always-resident singletons hard to see at a glance.
##
## UIManager instantiates them once at startup and parents them under itself, so
## there is now one UI autoload instead of several. Each panel keeps its own
## behaviour unchanged — it is still a CanvasLayer that processes while paused and
## handles its own toggle input — it is just owned here instead of by the engine
## directly. Reach a panel through its accessor:
##
##   UIManager.dialogue.start_conversation(...)
##   UIManager.shop.open(stock, name)
##   UIManager.storage.open()
##   UIManager.menu.open(tab)            # the unified tabbed player menu
##
## The self-toggling panels (menu, crafting) need no external calls; they are
## instanced here only so their toggle input is live from the first frame. The
## player menu (Tab / I / J / L) replaces the old standalone inventory, quest
## journal and relationships panels.

const DIALOGUE_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const CRAFTING_SCENE := preload("res://scenes/ui/crafting_ui.tscn")
const MENU_SCRIPT := preload("res://scripts/ui/player_menu.gd")
const TRACKER_SCRIPT := preload("res://scripts/ui/quest_tracker.gd")
const SHOP_SCRIPT := preload("res://scripts/autoload/shop_ui.gd")
const STORAGE_SCRIPT := preload("res://scripts/autoload/storage_ui.gd")

# Untyped on purpose: each panel exposes its own methods (is_active, open, ...)
# that are not on the CanvasLayer base, so access is dynamic — exactly as it was
# when these were stand-alone autoload singletons.
var dialogue
var crafting
var menu
var tracker
var shop
var storage

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue = DIALOGUE_SCENE.instantiate()
	crafting = CRAFTING_SCENE.instantiate()
	menu = MENU_SCRIPT.new()
	tracker = TRACKER_SCRIPT.new()
	shop = SHOP_SCRIPT.new()
	storage = STORAGE_SCRIPT.new()
	for panel: CanvasLayer in [dialogue, crafting, menu, tracker, shop, storage]:
		add_child(panel)
