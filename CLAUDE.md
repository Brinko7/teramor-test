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

**Carrying the player across area transitions.** `SceneManager.travel()` uses
`change_scene_to_file`, which frees the old player and builds a fresh one from the
new scene's authored defaults — so without help, gear/bag/levels reset at every
threshold. SaveManager reuses the *same* persistent-group contract **in-memory** for
this: `capture_subtree(player)` snapshots every persistent node in the player's
subtree (the player itself + `Inventory`, `Equipment`, `Stats`) into a dict, and
`apply_subtree(player, data)` restores it onto the rebuilt player after the scene
swap. The restore walks the subtree **root-last** (pre-order gather, then reversed)
so children (Stats, Equipment) load before the player node, whose `load_state`
recomputes `_max_hp()` from the already-restored stats + gear. Position is *not*
carried — `SceneManager._place_player` sets the spawn point after the restore.

When the **shape** of any saved state changes, bump `SAVE_VERSION` and add a step
to `SaveManager._migrate()`. Pre-versioning files (a bare id→state dictionary with
no `version` key) are read as version 0 and migrated forward. Keybinds: `F5` save,
`F9` quick-load.

### Player
`scripts/player.gd` (`CharacterBody2D`) handles movement, mouse-aimed combat
(melee + ranged), progression and death/respawn. Gameplay capabilities are
composed as child nodes: `Health`, `Stats`, `Equipment`, `Inventory`, `Mana`,
`AbilityCaster`, `ItemHotbar`. Cosmetic rendering — worn armour overlays and the
held weapon/shield with their posing/swing/recoil — lives in
`scripts/components/player_visuals.gd` (`class_name PlayerVisuals`), created in
`_ready()` and fed state each frame (body frame, aim, block flag).

**Hotbars (the number row is items; abilities live on Q).** The number row
**1–0** is a Stardew-style **item hotbar** over the first ten bag slots:
`scripts/item_hotbar.gd` (`class_name ItemHotbar`, a player child) tracks the
selected slot (`select`/`cycle`/`use_active`); keys 1–0 select, the mouse wheel
cycles, **F** uses the held consumable. Its HUD is `item_hotbar_hud.gd` /
`scenes/ui/item_hotbar.tscn`, a code-built CanvasLayer (layer 81) instanced per
world scene like the other HUD pieces, binding to the player via the `"player"`
group. **Abilities** moved to a **hold-Q radial**: `ability_hotbar.gd` is now a
ring of four ability slots shown only while `ability_menu` (Q) is held, and
`player.gd` branches input on that hold — Q down casts `ability_1..4` toward the
cursor, Q up drives the item hotbar — so the two never share a key. Input actions
(`hotbar_1..10`, `hotbar_prev/next`, `use_item`, `ability_menu`, `ability_1..4`)
live in `project.godot [input]`; `tools/validate_hotbar.gd` covers the scheme.

### Combat feel (juice)
Hits are sold by the **CombatFX** autoload, driven entirely off the `Events` bus so
combat code stays simple — it just reports outcomes:
- Entities that take damage emit
  `Events.damage_dealt(position, amount, to_enemy, player_involved)`; CombatFX always
  pops a floating `damage_number`, then **only when `player_involved`** requests an
  `Events.screen_shake` and (on `to_enemy`) a brief **hit-stop** (a micro
  `Engine.time_scale` freeze restored by an `ignore_time_scale` timer).
- `Events.enemy_killed(enemy_id, xp_reward, position, by_player)` always spawns a
  CPUParticles2D **death burst**, then **only when `by_player`** adds a bigger shake
  and a longer freeze.
- **Player-involvement gating.** `Enemy.take_damage(amount, knockback, from_player)`
  threads a `from_player` flag that surfaces as `player_involved` / `by_player` on
  the signals (the killing blow's source is remembered on the enemy as
  `_last_hit_from_player` for attribution). So a faction-vs-faction brawl (see
  **Factions & wildlife** below) is **ambient** — numbers and bursts still show for
  readability, but no shake, no hit-stop, no player **XP**
  (`player.gd._on_enemy_killed` credits XP only when `by_player`), and no **quest
  KILL credit** (`QuestManager` skips non-`by_player` kills). Every player attack
  path (melee, projectile, ability projectile/nova, DoT) passes `true`.
- The player camera (`components/camera_shake.gd`) listens for `screen_shake` and
  jolts its `offset`, and also adds a smoothed **aim-lead** — the view drifts a
  little toward the cursor (clamped to `LEAD_MAX`). Each frame `offset = lead + jolt`.
- **Knockback**: the `knockback` arg of `take_damage` is an optional impulse that
  decays in `_physics_process`; melee/projectiles/nova pass a direction.
- The player adds a forward **lunge** on melee swings (`_lunge`).

**The feedback layer (the "good → great" pass).** Beyond the autoload juice above,
actors sell their own hits:
- **Enemy telegraphed attacks.** `Enemy` runs a `READY → WINDUP → STRIKE → RECOVER`
  state machine (`_update_attack`): a hostile within `attack_range` triggers a
  `windup_time` wind-up (movement locks, the sprite shows a warm warn-glow, and a
  CombatFX **telegraph ring** fills), then a **strike** paints a swing arc, lunges
  forward (`STRIKE_LUNGE`), and damages any hostile still inside `strike_range`. The
  wind-up is the player's window to back off or block — this **replaced** the old
  passive contact damage, so "they just touch you" is gone. Tune per-enemy via the
  `melee_attacker` / `attack_range` / `windup_time` / `recover_time` exports
  (authored in the `.tscn`s — a snappy wolf, a heavy brute). **Kiters and
  non-combatants opt out** (`melee_attacker = false`: archer, wildlife, bear cub) so
  they never deal contact damage.
- **Hit-flash + flinch + death beat.** Taking damage drives a per-instance shader
  (`assets/shaders/hit_flash.gdshader`, two channels: `warn` telegraph-glow and
  `flash` white-flash) for a crisp white pop, plus a squash-and-recover `_flinch`.
  Death is no longer an instant `queue_free` — `_on_died` fires the kill (so XP/quest/
  burst land immediately), pulls the enemy from the `"enemy"` group, disables its
  collision, then plays a collapse/topple/fade before freeing (the `_dying` flag gates
  further hits and physics).
- **Spawned VFX, Events-driven.** New signals on the bus — `melee_swung(pos, dir,
  by_player)`, `attack_windup(pos, dir, duration)`, `step_puff(pos)` — let CombatFX
  spawn the actor-local effects so combat code stays clean. The effects are
  **code-built** `Node2D`s in `scripts/effects/` (`SlashArc`, `TelegraphRing`,
  `DustPuff`), drawn with `_draw` on the grounded palette (no `.tscn`). The player
  emits `melee_swung` on a melee swing and `step_puff` on a footstep cadence.

Tune feel via the constants in `combat_fx.gd`, `camera_shake.gd`, the `scripts/effects/`
scripts, the enemy attack exports, and the player's `MELEE_KNOCKBACK`/`LUNGE_*`.
Headless coverage: `tools/validate_combat_feel.gd`.

### Progression & skills
`Stats` (`scripts/stats.gd`, child of the player) is the progression authority:
level/XP, four allocatable **attributes** (Might→melee, Finesse→ranged,
Vitality→HP, Attunement→spell), and the set of **learned skill nodes**. Derived
combat stats = base growth + attributes + the summed passives of learned nodes.
A level-up grants attribute and skill points (`stats_changed` for XP/level,
`skills_changed` for build changes).

Skill nodes are `SkillNode` resources (`scripts/skill_node.gd`) under
`resources/skills/`, loaded by the **Skills** autoload catalog. A node lives in a
branch (Warfare / Marksmanship / Elementalism), may require other nodes + a level,
and either grants passive bonuses, unlocks an elemental ability
(`unlock_ability_id`), or both. Add a skill by authoring a `.tres`.

Elemental abilities are **earned, not given**: the player scene's authored
`AbilityCaster.hotbar` is treated as the ability *catalog*, and
`AbilityCaster.set_unlocked(ids)` rebuilds the castable bar from the abilities
that learned skill nodes unlock. `player.gd` resyncs this (and the health pool) on
`skills_changed`. Ranged damage now flows through `Stats.ranged_power()`. The
player menu's **Skills** tab spends points and learns nodes.

### Story / main questline
The **Story** autoload is both a flag/`stage` bag and the main-line **director**. It
loads `StoryChapter` resources (`scripts/story_chapter.gd`) from
`resources/story/chapters/`; a new game starts `FIRST_CHAPTER`. Each chapter
starts its `quest_path` and shows an intro banner; when that quest completes Story
applies the chapter's `set_flags`, grants `grant_skill_points`, shows a completion
banner, and starts `next_chapter`. Add/repace beats by authoring `.tres` — no code.

**Beats** advance STORY quest objectives. `Story.beat(id)` calls
`QuestManager.advance_story(id)` and records a `beat_<id>` flag. Triggers wired in
Story: discovering a location fires `visit_<location_id>`, entering a wild area
fires `enter_wilds` (via `TravelManager.area_entered`), and an NPC dialogue topic
can fire one via its `story_beat` key. Because fast travel is gated on discovery,
the opening naturally routes the player out to discover Cleeve's Landing.

Banners are shown via `UIManager.notify(title, subtitle)` (the UIManager-owned
`notification_banner`, also reusable for level-ups/awakenings).

`Story` is registered **after** QuestManager/WorldMap/TravelManager in the autoload
order because it connects to their signals in `_ready`.

### Items, gear & loot
`Item` (`scripts/items/item.gd`) carries a `rarity` (Common→Legendary, with
`rarity_color()`/`rarity_name()`) and equip **affix** bonuses
(`bonus_melee/ranged/spell/max_hp/defense`, `lifesteal`). The **Equipment**
component aggregates affixes across the equipped weapon + armor
(`bonus_melee()`, `lifesteal()`, etc.; `total_defense()` now folds affix defense
in), and the combat code adds them: melee/ranged damage, the health pool (gear HP
is re-applied on `equipment.changed`), spell power (in `AbilityCaster`), and
melee lifesteal. The player menu shows rarity + affix lines in tooltips and tints
bag slots by rarity.

**Unique named weapons/armor** are just authored `.tres` with a high rarity and
affixes (e.g. `emberbrand`, `windpiercer`, `wyrmscale_vest`). They drop from
**treasure chests** (`scripts/treasure_chest.gd`) scattered by the area generator
— more, fuller chests the deeper the tier — and from biome `loot_paths`, so
braving the Cursed Wilds pays out. (Randomly-rolled per-instance affixes would
need item duplication on drop; not done yet — affixes are authored for now.)

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

Biomes can also seed **gather nodes** (`scripts/gather_node.gd`) — ore/stone/
crystal veins you interact with to harvest, scattered from a biome's
`gather_paths`. The `cave` biome (the Stone Folk Undervault, reached via a camp
ExploreZone) yields materials that feed forge recipes (`forge_iron_sword`, etc.),
closing the gather → craft → fight loop. Recipes are `Recipe` .tres referencing
ingredients by item id.

Generated areas use one scene, `scenes/world/procedural_area.tscn`
(`scripts/world/procedural_area.gd`), driven by a **`BiomeData`** resource
(`resources/world/biomes/`) and a difficulty **tier**. The generator reads the
staged request from `TravelManager.consume_pending()`, paints the ground, scatters
props, spawns a sparse set of tier-scaled ambient enemies (`Enemy.apply_tier`),
drops authored **encounter setpieces** (`EncounterData` in
`resources/world/encounters/` — hand-arranged enemy/prop clusters a biome lists in
`encounter_paths`, budgeted + tier-gated), seeds passive **wildlife** (see below),
and wires exit "gates" (triggered by the player's position): a one-way *Continue*
for encounters, or *Return* / *Deeper* (tier+1) for excursions. Add a biome or a
place by authoring a `.tres` — scenes/items inside `BiomeData` are referenced by
path, so no code change is needed.

### Factions & wildlife
Every `Enemy` carries a `faction` (`scripts/faction.gd`, `class_name Faction`:
`PLAYER` / `BEAST` / `BANDIT` / `MONSTER` / `WILDLIFE`). `Faction.hostile(a, b)`
gates targeting *and* damage, so an enemy chases the **nearest hostile** in range
(player *or* rival faction) and contact/projectiles only hurt a hostile body —
rival factions fight each other, not just the player. Those rival fights are
**ambient**: they deal real damage to each other but award the *player* nothing —
no shake, hit-stop, XP, or quest credit (see **Combat feel** above) — so the world
feels alive without hijacking the camera or padding the kill count. **`WILDLIFE` is
neutral**: it fights no one and nothing faction-targets it.

Passive game (`scripts/wildlife.gd`, `class_name Wildlife extends Enemy` — deer,
rabbit) is the huntable end of that table. It spawns on a **separate**
`_spawn_wildlife()` pass from a biome's `wildlife_paths` (+ `min/max_wildlife`),
*not* `enemy_paths` — that pass deliberately **keeps the scene's authored loot**
(meat/hide) and **skips `apply_tier`**, so hunting always yields the same gentle
prey. Its brain overrides only `_decide_input`: flee the nearest non-wildlife thing
at a sprint, graze when safe, bolt along the knockback when struck (`apply_tier` is
a no-op). The `wild_clash` encounter weaponizes the faction system by staging
mutually-hostile BEAST + BANDIT a few steps apart so a brawl erupts on spawn.
Headless coverage: `tools/validate_wildlife.gd`.

## Art & visual style (the art bible)

> The single source of truth for how Teramor looks. Every sprite — generated or
> sourced — must obey the **scale grid** and sit on the **grounded palette**.
> The scale grid exists because we shipped a bug where the player rendered as big
> as a house; never reintroduce it. When in doubt, generate at these sizes and
> verify in-engine with a screenshot.

### Mood
**Grounded & naturalistic serious fantasy.** Muted, earthy, slightly desaturated.
Think overcast Northern-European woodland, weathered timber and thatch, mossy
stone. NOT the bright candy palette of Stardew/Sprout-Lands, and NOT heavy
cartoon outlines. Soft top-left key light, cool ambient shadow. Saturation stays
low except for deliberate story accents (embers, magic, blight).

### The scale grid (non-negotiable)
The world is built on a **16 px tile**. Everything is sized in tiles so relative
proportions read correctly. The governing rule: **a one-story door is about one
character tall (~40 px / 2.5 tiles).** Buildings tower over the player; trees
tower over buildings.

| Thing | Footprint / size (px) | In tiles | Notes |
|---|---|---|---|
| **Tile** | 16×16 | 1×1 | the base unit |
| **Player / humanoid frame** | 24×40 | 1.5×2.5 | KEEP — paper-doll + gear overlays tuned to this |
| Small prop (rock, bush, crate) | 16–28 wide | 1–1.75 | foot-anchored |
| Cottage / small house | 64×72 | 4×4.5 | door ≈ 40 tall |
| Town house | 72×88 | 4.5×5.5 | |
| Big / 2-story building | 80–96 × 112–128 | up to 6×8 | tavern, chapel, hall |
| Tree | 48–64 wide × 64–96 tall | up to 4×6 | canopy towers over roofs |
| World scene | 640×480 | 40×30 | standard town/area canvas |

If a new sprite would break the "door ≈ one character" sanity check, it's wrong —
resize it, don't ship it.

### Foot-anchoring convention (depth + placement)
Sprites are authored so the **visual base sits at the node origin**, which makes
placement and `y_sort` depth trivial. On every world Sprite2D:
- `centered = false`
- `offset = Vector2(-w/2, -base_h)` — centers horizontally, lifts the sprite so
  its feet/base touch y=0 (`base_h` = full height for a thing standing on the
  ground; a hair/gear overlay shares the body's offset).
- `y_sort_enabled` on the sprite (and its parent) so things behind/in front sort
  by their base y.
- **No `scale` multiplier** on world Sprite2D nodes — author at native pixel size
  so the scale grid is real. (The camera does the zoom.)
- Collision shapes hug the **base footprint**, not the full sprite (e.g. a tree's
  collider is a small ellipse at the trunk, not the canopy).

### The pixel engine: `tools/pixelforge.py`
The bespoke Teramor art (player, NPCs, the Withered, items, FX, and any prop we
want pixel-perfect on the palette) is generated by a **dependency-free** Python
toolkit. No Pillow, no pip — PNGs are hand-encoded with stdlib `zlib` + `struct`,
so it runs anywhere with python3. This is also part of the story: the whole pixel
pipeline is ours.

- **`class P`** — the grounded palette as light→dark ramps (`GRASS`, `SOIL`,
  `PATH`, `STONE`, `WOOD`, `ROOF`, `THATCH`, `PLASTER`, `WATER`, `FOLIAGE`,
  `BARK`, `METAL`, `LEATHER`, `CLOTH`, plus `OUTLINE`/`SHADOW`/`NIGHT`/`EMBER`).
  Pull colors from here so everything sits in the same world.
- **`class Canvas`** — a pixel buffer with drawing primitives (`rect`, `frame`,
  `line`, `ellipse`, `disc`, `shade_rect` bevel, gradients, `dither`, `mottle`
  value-noise fill, `speckle`) and post pass helpers (`outline`, `drop_shadow`,
  `replace` palette-swap, `tint`, `blit`, `region`, `scaled`, `save`).
- Per-sprite generator scripts live in `tools/gen_*.py` and import pixelforge;
  they paint to `assets/placeholder/`. Run a generator to (re)bake its PNG — art
  is regenerated, not hand-edited.
- Smoke test: `python3 tools/pixelforge.py` renders `_pixelforge_smoke.png`.

### Sourced (CC0) art
Open-source CC0 art (Kenney-first) may back the world foundation where it clearly
beats generating. Anything sourced must (1) match the scale grid, (2) be retinted
toward the grounded palette if needed, and (3) have its origin + license recorded
in `assets/CREDITS.md`. Kenney packs are CC0 (no attribution required) but we log
them anyway.

## Conventions

- **Decouple via `Events`** rather than direct node references where practical.
- **Prefer typed code** (`class_name` types, typed signals) over string-based
  `has_method`/`call` duck typing.
- **Content is data.** New items/crops/abilities/recipes are `.tres` resources
  under `resources/`; UIs load them by scanning their directory, so no code change
  is needed to add content.
- **Code-built UI** routes colours and shared widgets through `UITheme`.
- Tabs for indentation (`.editorconfig`).
