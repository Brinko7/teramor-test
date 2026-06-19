# Teramor

A top-down action-RPG / farming / town-sim hybrid built in **Godot 4.6** (Forward+,
GDScript). The base viewport is 480×270 pixel-art, scaled to a 1280×720 window.
Combat is mouse-aimed; the rest of the game (farming, crafting, shops, dialogue,
relationships, quests, day/night) is interaction- and menu-driven.

## Running

Open the project in Godot 4.6. The main scene is `scenes/ui/main_menu.tscn`
(`application/run/main_scene`). "New Game" → character creation →
`scenes/world/settlement.tscn`.

## Project layout

```
scripts/
  autoload/        # Global singletons registered in project.godot [autoload]
  components/      # Reusable nodes composed onto entities (e.g. player_visuals.gd)
  ui/              # Shared UI code (ui_theme.gd)
  items/           # Item resource subclasses (weapon/armor/tool/seed/consumable)
  crops/           # crop_data.gd
  abilities/       # ability_data.gd
  *.gd             # Entities (player, enemy_*), props (chest, bed, farm_plot), etc.
scenes/
  entities/        # Player, enemies, NPCs, projectiles, props/
  ui/              # Menus and HUD scenes
  world/           # Settlement, town, road
resources/         # Authored content as .tres (items, crops, abilities, recipes)
assets/            # Art/audio
addons/godot_ai/   # Editor/runtime helper plugin (_mcp_game_helper autoload)
```

## Architecture

### Autoloads (singletons)
Registered in `project.godot` under `[autoload]`:

- **Events** — global signal bus. Systems emit/listen here instead of holding
  references to each other (`enemy_killed`, `player_leveled_up`, `item_collected`,
  `item_crafted`). Prefer adding a signal here over cross-wiring nodes.
- **GameManager** — high-level flow: new game, continue, return to menu, the
  death → game-over → respawn loop, and the sleep/day-advance sequence.
- **PlayerProfile** — chosen identity (skin/hair) from character creation.
- **Story**, **Relationships**, **QuestManager** — narrative/social/quest state.
  Relationships and QuestManager are **pure data managers**: they expose state +
  signals, and the player menu renders them (no UI of their own).
- **TimeManager** — in-game clock and day counter.
- **Wallet** — gold balance.
- **SceneManager** — fade transitions and player spawn placement.
- **SaveManager** — generic group-based persistence (see below).
- **FarmManager**, **StorageManager** — farm tiles and the shared camp stash.
- **UIManager** — single owner of the overlay panels (dialogue, the player menu,
  crafting, shop, storage). See "UI" below.

### UI
`UIManager` instantiates the overlay panels once at startup and parents them under
itself, so there is **one** UI autoload instead of several. Reach a panel through
its accessor:

```gdscript
UIManager.dialogue.start_conversation(intro, menu_provider, speaker)
UIManager.shop.open(stock, shop_name)
UIManager.storage.open()
UIManager.menu.open(tab)   # the unified tabbed player menu
```

Each panel is a `CanvasLayer` that processes while the tree is paused and handles
its own toggle input — `UIManager` just owns it.

**Player menu** (`scripts/ui/player_menu.gd`) is the unified, Stardew/Kynseed-style
tabbed overlay and the home for inventory, equipped gear, character stats, quests
and social. Open with `Tab`; the legacy keys jump to a tab (`I` Inventory,
`J` Quests, `L` Social) and toggle shut if already on it. It replaced the old
standalone inventory / quest-journal / relationships panels. Add a new tab by
extending the `Tab` enum and adding a `_build_*` method. Crafting (`C`) is still
its own panel for now and is a natural future tab.

**Styling.** `scripts/ui/ui_theme.gd` (`class_name UITheme`) is the single source
of truth for the UI palette (brown panels, parchment text, gold/green accents) and
the shared widget builders (`make_label`, `make_row_button`, `panel_style`). All
code-built panels route through it — change a colour once, there. The matching
`resources/ui/teramor_theme.tres` mirrors those colours for the editor/.tscn side
and is registered as the project default theme (`gui/theme/custom`); keep the two
in sync, with `UITheme` as canonical.

### Persistence (SaveManager contract)
Any node that should be saved joins the `"persistent"` group in `_ready()` and
implements three methods:

```gdscript
func get_save_id() -> String      # globally unique, stable key
func save_state() -> Dictionary    # JSON-serializable snapshot
func load_state(data: Dictionary) -> void
```

`SaveManager` walks the group and writes one JSON file (`user://teramor_save.json`)
wrapped in a versioned envelope: `{"version": N, "entries": {id: state}}`. New
systems become saveable just by implementing the contract — SaveManager itself
does not change.

When the **shape** of any saved state changes, bump `SAVE_VERSION` and add a step
to `SaveManager._migrate()`. Pre-versioning files (a bare id→state dictionary with
no `version` key) are read as version 0 and migrated forward. Keybinds: `F5` save,
`F9` quick-load.

### Player
`scripts/player.gd` (`CharacterBody2D`) handles movement, mouse-aimed combat
(melee + ranged), progression and death/respawn. Gameplay capabilities are
composed as child nodes: `Health`, `Stats`, `Equipment`, `Inventory`, `Mana`,
`AbilityCaster`. Cosmetic rendering — worn armour overlays and the held
weapon/shield with their posing/swing/recoil — lives in
`scripts/components/player_visuals.gd` (`class_name PlayerVisuals`), created in
`_ready()` and fed state each frame (body frame, aim, block flag).

### Quests
A `Quest` (`scripts/quest.gd`) has a `category` (Main / Contract / Rescue / Task)
and a list of `QuestObjective`s (`scripts/quest_objective.gd`) — KILL, COLLECT or
STORY — all of which must be met to finish. KILL/COLLECT advance automatically off
the `Events` bus; STORY objectives advance when narrative code calls
`QuestManager.advance_story(beat_id)`.

For back-compat, a quest with an empty `objectives` array falls back to the flat
`objective`/`target_id`/`required_count` fields (one synthesized objective), so
pre-existing single-objective `.tres` files still work. Author multi-objective
quests in the editor by populating the `objectives` array.

If a quest `requires_turn_in`, meeting its objectives makes it **ready** rather
than complete; the player turns it in to the NPC whose `NpcData.id` matches the
quest's `giver_id` (the NPC offers a "Turn in" choice via
`QuestManager.get_turn_in_quests`). Otherwise it auto-completes and grants rewards.

`QuestManager` keeps one **tracked** quest (`set_tracked`/`get_tracked`); the
on-screen `quest_tracker.gd` HUD (UIManager-owned) shows it during gameplay, and
the menu's Quests tab has a Track button per quest. Quest progress saves
per-objective; `load_state` also reads the old single-int format.

### World, travel & procedural areas
Named places are `WorldLocation` resources (`scripts/world/world_location.gd`)
under `resources/world/locations/`, loaded by the **WorldMap** autoload, which
tracks which are discovered and where the player currently is (persistent). Tag a
hand-built scene as a location by calling `WorldMap.discover/set_current` in its
root `_ready` (see `settlement.gd`, `town_terrain.gd`).

**TravelManager** (autoload) moves the player around:
- `fast_travel(id)` (from the menu's Map tab) rolls a tier-based encounter chance.
  On a hit it stages a generated ambush and the player must cross to the far exit
  to continue; otherwise they `arrive` directly. No fast travel mid-encounter.
- `enter_area(biome, tier, return_to)` (an `ExploreZone` at a town edge) drops the
  player into an explorable wild area.

Generated areas use one scene, `scenes/world/procedural_area.tscn`
(`scripts/world/procedural_area.gd`), driven by a **`BiomeData`** resource
(`resources/world/biomes/`) and a difficulty **tier**. The generator reads the
staged request from `TravelManager.consume_pending()`, paints the ground, scatters
props, spawns tier-scaled enemies (`Enemy.apply_tier`), and wires exit "gates"
(triggered by the player's position): a one-way *Continue* for encounters, or
*Return* / *Deeper* (tier+1) for excursions. Add a biome or a place by authoring a
`.tres` — scenes/items inside `BiomeData` are referenced by path, so no code
change is needed.

## Conventions

- **Decouple via `Events`** rather than direct node references where practical.
- **Prefer typed code** (`class_name` types, typed signals) over string-based
  `has_method`/`call` duck typing.
- **Content is data.** New items/crops/abilities/recipes are `.tres` resources
  under `resources/`; UIs load them by scanning their directory, so no code change
  is needed to add content.
- **Code-built UI** routes colours and shared widgets through `UITheme`.
- Tabs for indentation (`.editorconfig`).
