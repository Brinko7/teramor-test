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
- **TimeManager** — in-game clock, day counter, and the **calendar** (season /
  day-of-season / year, all derived from the day). See "Seasons" below.
- **SeasonManager** — announces the calendar: a banner on each new season and on
  authored festival days. Registered **after** UIManager (it drives the banner).
- **WeatherManager** — each day's sky, a deterministic season-weighted roll derived
  from the day (so it costs the save nothing). See "Weather" below.
- **WeatherFX** — paints the weather + ambient life (rain/snow/fog/fireflies/leaves)
  as screen-space particles, gated to outdoor zones. Registered **after** MusicManager
  (it reads the zone).
- **CanopyFX** — drifts a dappled overhead-shade overlay across **wooded** areas (the
  "moving under a thick canopy" feel). A procedural area turns it on from its
  `BiomeData.has_canopy`, so it's data-driven (forests yes, plains/desert/cave no);
  it fades out at night and resets on zone change. Registered **after** WeatherFX. See
  "Forest canopy" below.
- **MusicManager** — owns the Music/Ambience buses; crossfades looping tracks per
  zone + day/night. See "Music & ambience" below.
- **SettingsManager** — app preferences (audio bus volumes, fullscreen/vsync, a
  screen-shake toggle, key rebindings) persisted to `user://settings.cfg`, **separate
  from the save**. Applies on startup; the options menu reads/writes it. Registered
  **after** AudioManager (it sets bus volumes on load).
- **Wallet** — gold balance.
- **SceneManager** — fade transitions and player spawn placement.
- **SaveManager** — generic group-based persistence (see below).
- **FarmManager**, **StorageManager** — farm tiles and the shared camp stash.
- **CampManager** — the recruited-camp roster + the chores they do (see
  "Recruiting the camp" below). Registered **after** FarmManager so its
  day-advance runs second.
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
UIManager.settings.open()  # the options overlay (Audio / Display / Controls)
```

Each panel is a `CanvasLayer` that processes while the tree is paused and handles
its own toggle input — `UIManager` just owns it.

**Options menu** (`scripts/ui/settings_panel.gd`, `UIManager.settings`) is the
tabbed overlay for **Audio** (Master/Music/SFX/Ambience sliders → the mixer buses),
**Display** (fullscreen, vsync, an accessibility screen-shake toggle the player
camera honours) and **Controls** (rebind the keyboard actions; combat stays
mouse-aimed). It's a thin view over **SettingsManager** (which applies + persists to
`user://settings.cfg`), reachable from the title screen and the player-menu footer.
Opening it pauses the tree and restores the prior pause state on close, so it layers
over the already-paused player menu. Headless coverage: `tools/validate_settings.gd`.

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

`travel()` also holds a `placing` flag across the swap so a return marker that
happens to sit inside a door zone can't bounce the player straight back through it
(transition zones ignore the spawn-overlap) — the fix for the stuck-in-building
soft-lock. Interiors put their door on the **south** wall (you enter at the room's
bottom and it opens upward). Coverage: the full per-scene HUD set is asserted by
`tools/validate_hud.gd`, door/exit integrity by `tools/validate_transitions.gd`.

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

**Dodge-roll (defensive verb).** `Shift` (`dodge` action) bursts a dash along the
move/aim direction with **i-frames** over most of it (`DODGE_*` constants): a roll
overrides movement, grants `_iframe_timer` invulnerability that `take_damage` honours,
cancels any swing, and gates attacks/block for its duration, then a short cooldown
before the next. It reports `Events.player_dodged` (AudioManager whoosh) + a
`step_puff` (dust). The counterplay to the enemy wind-up telegraphs — read the tell,
roll through the strike. Headless coverage: `tools/validate_dodge.gd`.

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

### Audio
The **AudioManager** autoload turns gameplay into sound the same way CombatFX turns
it into juice: it listens on the `Events` bus and plays SFX, so gameplay code never
references it. Connected events: `damage_dealt` (hit), `enemy_killed` (death),
`melee_swung` (swing), `step_puff` (footstep), `item_collected` (pickup),
`item_crafted` (craft), `player_leveled_up` (sting). Combat SFX are **player-gated**
exactly like the juice — a faction brawl off in the trees stays silent. A round-robin
pool of `AudioStreamPlayer`s on the **SFX** bus avoids cutting off overlaps, and each
shot gets a little random pitch so repeats don't machine-gun.

SFX are **bespoke and ours**: `tools/audioforge.py` is a dependency-free synth (the
audio twin of `pixelforge.py`) — stdlib `wave`+`struct`+`math`, no samples — that
bakes `assets/audio/sfx/*.wav` from math on the grounded/muted palette. Regenerate or
tune a sound by editing its recipe in `bake_all()` and running
`python3 tools/audioforge.py`.

The mixer is a **bus layout** (`resources/audio/default_bus_layout.tres`, set as
`audio/buses/default_bus_layout`): Master → **Music / SFX / Ambience**, so the coming
options sliders drive `AudioManager.set_bus_volume_linear(bus, 0..1)`.
Headless coverage: `tools/validate_audio.gd`.

**Music & ambience (the soundscape's bed).** The **MusicManager** autoload owns the
**Music** and **Ambience** buses the way AudioManager owns SFX — gameplay never
touches it. It holds one looping layer per bus and **crossfades** (an A/B
`AudioStreamPlayer` pair, ~1.4s) between tracks as the player moves between **zones**
and as day turns to night. Each world scene just announces its mood in `_ready` —
`MusicManager.enter_zone(zone)` (camp/town/wild/cursed/finale/interior/title/cave) —
and re-entering the same zone is a no-op, so walking through a door never restarts the
music. Zones map to a theme via `ZONE_MUSIC`; **outdoor** zones swap their ambience
bed on `TimeManager.period_changed` (day birds ↔ night crickets). `procedural_area`
derives its zone from the biome (the Cursed-Wilds biomes get the ominous theme, the
cave its own bed); `LocationScene` derives its zone from the place's authored
kind/region. Tracks are **bespoke audioforge loops** — `bake_music()`/`bake_ambience()`
synth four themes + four beds (the same dependency-free math as the SFX), saved as
seamless loops (`make_loop()` crossfade-wraps each so the seam is continuous; the WAV
is set to `LOOP_FORWARD` at load) under `assets/audio/{music,ambience}/`. Regenerate
or tune by editing the recipes and running `python3 tools/audioforge.py`. Headless
coverage: `tools/validate_music.gd`.

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

### The opening (the Elkar prologue)
A **new game opens on the prologue** (`scenes/world/prologue.tscn`, `prologue.gd`) —
the wilds' edge, not the camp. `GameManager.enter_world` drops the player here
(`PROLOGUE`, distinct from `WORLD` which `continue_game` still uses). It's the home
of **Elkar**, the player's father and a ranger (`resources/npcs/elkar.tres`), who
gives a **diegetic last lesson**: his dialogue topics teach the verbs (footwork,
the blade, the dodge-roll, working the land), the two wolves at the treeline are
chapter 1's "defeat 2 foes" beat, and a few farm plots + a seed pickup cover the cozy
verb. Felling the wolves completes `ch1_first_lesson` → `father_missing` → `ch2`
("find Elkar in Cleeve's Landing"); an exit by the road carries the player onward to
**Cleeve's Landing** (`town.tscn`, spawn `from_road`). Elkar's bust is baked like the
others by `gen_portraits.py`. Headless: `tools/validate_prologue.gd`.

**The camp is a secret you earn into.** `settlement_camp` is **not**
`discovered_by_default` — it isn't on the map until you find it. The route:
- **ch2** completes the moment you reach Cleeve's Landing, and **ch3_children** points
  you at the tavern. There a hooded **Child of Tera, Sorrel**
  (`resources/npcs/sorrel.tres`, in `tavern_interior.tscn`) reveals a **hidden trail**
  — her topic sets the `trail_revealed` flag.
- A **flag-gated journey `ExploreZone`** in `town.tscn` (hidden until `trail_revealed`)
  is the trek: a one-way deepwood crossing that `journey_to`s the camp, **discovering**
  it. The open `road.tscn` route to the camp stays sealed (`ExitToSettlement`'s
  `require_flag = beat_visit_settlement_camp`) until that discovery, so the trail is the
  only first way in. Both `ExploreZone` and `TransitionZone` gained an optional
  `require_flag` export (hide + go inert until the Story flag is set; re-checked each
  scene load).
- At the camp, **Elder Maelon** recruits you (a topic gated on `trail_revealed`, firing
  the `joined_children` beat that completes `q_seek_camp`); ch3_children sets
  `joined_children_of_tera` and hands off to **ch4 First Awakening**.
- **Continue reloads your last location**: `continue_game` peeks the saved WorldMap
  state (`SaveManager.peek`) to pick the scene from the current location's `scene_path`,
  falling back to the camp only for pre-existing/wild-area saves.

Headless: `tools/validate_recruitment.gd`.

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
**treasure chests** (`scripts/treasure_chest.gd`) — now a **rare find** the
generator scatters sparingly (`_spawn_treasure`: usually none-to-one per area, a
small chance of a second deep in an excursion; deeper tiers still stock fuller
chests) plus the loot caches you earn by clearing an authored encounter, so loot
feels earned rather than littered. (Randomly-rolled per-instance affixes would need
item duplication on drop; not done yet — affixes are authored for now.)

**Enemy drops are thematic, not a biome grab-bag.** Each combat enemy scene authors
its own `loot_table` + `loot_chance` (wolf/bear → raw meat + hide; bandit/brute/
archer → the gear they carry; Withered → a crystal shard; bear cub → nothing). The
generator's `_place_enemy` **preserves an enemy's own table** and only falls back to
the biome `loot_paths` pool for enemies that ship without one, so drops read as
logical. `Enemy._drop_loot` rolls each entry independently against `loot_chance`.

**Dropping items.** Right-clicking a bag slot in the player menu drops the whole
stack as a recoverable world `ItemPickup` a step from the player (offset so it isn't
re-collected on the spot) — a quick way to clear bag space.

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
tracks which are discovered and where the player currently is (persistent). Each
location carries a `region` (kingdom), a `kind` (camp/town/capital/wild/frontier/
landmark), and a `rumored` flag.

**The world is three human kingdoms + a deep frontier**, adopting the GDD canon:
- **The Hollenmark** (Third Kingdom, `region = &"hollenmark"`) — the forest-edge
  home region: the **Children of Tera camp** hidden where the woods meet the wilds,
  the border barony **Cleeve's Landing**, the capital **Hollen**, and **Mirefen**.
- **Plint** (Second Kingdom, plains) — the Wizard King's grain capital, plus
  **Kingsford** on the King's Path.
- **Terakin** (First Kingdom, desert) — the hybrid-abducting crown, plus **The
  Holdfast** (a desert prison — the first Rescue hook).
- **The Cursed Wilds** frontier — **The Thornwall**, **The Elven Glade** (the
  elves endure), and **The Great Tree** (Tera, the finale), as steep-tier goals.

Most far places ship as **`rumored = true`**: named, greyed nodes on the map that
sell the world's scale. Tiers form the curve — camp/towns 0–2, the plains/desert
2–4, and a hard jump to **5–7 in the Cursed Wilds** (the threshold).

**Every named place has its own editable scene.** The camp (`settlement.tscn`),
Cleeve's Landing (`town.tscn`) and the finale **Great Tree**
(`scenes/world/the_great_tree.tscn`, `scripts/great_tree.gd`) are bespoke; the
remaining eight live under `scenes/world/locations/<id>.tscn`, each built on the
shared **`LocationScene`** root
(`scripts/location.gd`) — set `location_id` + `map_size`, point `Ground` at a texture
(tint via its modulate), and drop building/prop instances under `Entities`; the root
claims its id on load, frames perimeter walls, sizes the ground and clamps the camera.
The HUD stack is bundled as `scenes/ui/world_hud.tscn` (one node, not six). The eight
starters were scaffolded by **`tools/gen_locations.py`** (regenerating overwrites — so
hand-edit the `.tscn` in the editor after; the bespoke Great Tree is not scaffolded).
Tag any other hand-built scene with
`WorldMap.claim_arrival(fallback_id)` in its root `_ready` (see `settlement.gd`,
`town_terrain.gd`); `claim_arrival` honours a **staged journey/fast-travel
destination** so one scene can stand in for several map nodes, else uses its own id.
The **Map tab** (`player_menu`) renders the world grouped by kingdom via
`WorldMap.get_map_regions()`. Headless coverage: `tools/validate_locations.gd`.

**TravelManager** (autoload) moves the player around:
- `fast_travel(id)` (from the menu's Map tab) rolls a tier-based encounter chance.
  On a hit it stages a generated ambush and the player must cross to the far exit
  to continue; otherwise they `arrive` directly. No fast travel mid-encounter.
- `enter_area(biome, tier, return_to, explore)` — an `ExploreZone` at a town edge.
  A normal zone is a there-and-back **excursion**; a zone with `journey_to` set is
  a one-way **journey** (`explore = false`) whose single *Continue* gate *arrives at
  and discovers* a named place — the way you cross a long wild stretch to reach the
  next town/frontier. The camp's **Cursed Wilds entrance** drops you into the
  tier-5 Vast frontier where the **Withered** (`monster` faction) roam.

Biomes can also seed **gather nodes** (`scripts/gather_node.gd`) — ore/stone/
crystal veins you interact with to harvest, scattered from a biome's
`gather_paths`. The `cave` biome (the Stone Folk Undervault, reached via a camp
ExploreZone) yields materials that feed forge recipes (`forge_iron_sword`, etc.),
closing the gather → craft → fight loop. Recipes are `Recipe` .tres referencing
ingredients by item id.

### Seasons & the calendar (the loop's frame)
The calendar lives in **TimeManager** as pure derivation: four `Season`s
(Spring/Summer/Autumn/Winter) of `DAYS_PER_SEASON` (28) days make a year, all
computed from the running `_day` — so seasons cost the save file **nothing** (the
day already persists). Queries: `get_season()`/`get_day_of_season()`/`get_year()`,
`get_season_id()` (the lower-case content id, e.g. `&"autumn"`), and
`format_date()` ("Spring 5", gaining ", Year 2" past the first year). A
`season_changed(season)` signal fires when a `sleep()` crosses a boundary (and on
load/reset for sync). The HUD clock shows `format_date()`.

- **Seasonal crops.** `CropData.seasons: Array[StringName]` lists the season ids a
  crop grows in (**empty = year-round**); `grows_in(season_id)` is the test. Out of
  season a crop **can't be planted** (`FarmPlot` filters the plant menu / `try_plant`
  to in-season seeds) and a standing crop **pauses** in `FarmManager._on_day_changed`
  (`crop.grows_in(TimeManager.get_season_id())`) — it never withers, keeping the loop
  forgiving. Turnip = spring/summer, wheat = summer/autumn; winter is the off-season.
- **Seasonal look.** `day_night.gd` folds a subtle per-season `SEASON_TINT`
  multiplier over its time-of-day colour, so the whole world shifts hue with the
  calendar (fresh spring → warm summer → amber autumn → pale-cold winter), kept gentle
  so night/lamplight still read.
- **Festivals.** A `Festival` resource (`scripts/festival.gd`, `.tres` under
  `resources/festivals/`) names a `season` + `day` (recurring each year), a banner
  `title`/`subtitle`, and an optional Story `set_flag`. **SeasonManager** loads the
  catalog and, on a *natural* day advance (a sleep, not a load/reset jump), pops the
  season banner on a crossing and the festival banner on its day. Four ship
  (Spring Bloom Fair, Sunpeak Revel, Harvest Home, The Long Night) — add one by
  authoring a `.tres`. Headless coverage: `tools/validate_seasons.gd`.

### Weather (the day's mood)
Each day has a sky. **WeatherManager** rolls it **deterministically from the day**
(a season-weighted pick — winter trades rain for snow, autumn is the foggiest,
summer the clearest), so like the season it costs the save file nothing and a load
reproduces the same weather. It exposes `get_weather()`/`weather_id()` and the
`is_rainy()`/`is_snowy()`/`is_foggy()`/`waters_crops()` queries, and fires
`weather_changed` on a day roll. Consumers react, never poll:

- **WeatherFX** (autoload `CanvasLayer`, layer 79) paints it as **code-built
  CPUParticles2D** over tiny runtime textures (no assets) — rain, snow, a fog veil,
  plus ambient life: **fireflies** at dusk/night in the growing seasons and drifting
  **autumn leaves**. All of it is gated to the **outdoor** zones (via
  `MusicManager.is_outdoor()` + its new `zone_changed`) and keyed off weather/season/
  time, so nothing shows indoors. Tune feel entirely in `weather_fx.gd`.
- **day_night** folds a gentle per-weather tint over its time-of-day + season colour
  (rain/fog dim and cool the world, snow stays pale-bright).
- **FarmManager** lets a **rainy day water every crop for free** (and leave the soil
  wet), so weather feeds the farming loop.

Headless coverage: `tools/validate_weather.gd`.

### Forest canopy (depth overhead)
**CanopyFX** (autoload `CanvasLayer`, layer 77 — under WeatherFX, over the world) sells
"thick forest" by drifting a **dappled overhead shade** across wooded areas: a small
seamless shadow tile (`assets/placeholder/canopy_dapple.png`, baked by
`tools/gen_canopy.py`) scrolls *opposite* the player's motion (`PARALLAX`), so you read
as moving **under** the leaves. It's **data-driven, not zone-guessed** — a procedural
area calls `CanopyFX.set_canopy(_biome.has_canopy)` after `enter_zone`, so the new
`BiomeData.has_canopy` flag decides (on for deepwood/roadside/cursed_wilds/vast_edge,
off for plains/desert/cave). It **fades out at night** (no sun to dapple; keyed off
`TimeManager.get_period()`) and **resets off on `zone_changed`** so it never lingers
into a town or cave. CanvasLayers skip the world's CanvasModulate, so the day/night
fade is done here. Tune feel (tile, `PARALLAX`, `STRENGTH`) in `canopy_fx.gd`.
Headless: `tools/validate_canopy.gd`.

### The Cursed Wilds reveal (the Great Tree vista)
The gameplay camera clamps `limit_top = 0`, so there's **no sky above the maps** to
loom a distant landmark into — a persistent in-world horizon vista can't work. The
fix is a **cutscene**: a composed full-screen shot isn't bound by that clamp. The
**first** time the player crosses into the Cursed Wilds, `procedural_area._maybe_reveal_wilds()`
(gated on `_biome.id` in `cursed_wilds`/`vast_edge`, one-shot via the Story flag
`seen_wilds_reveal`) plays `scenes/ui/wilds_reveal.tscn` (`scripts/wilds_reveal.gd`):
a `CanvasLayer` (layer 95) that composes **sky → distant Great Tree → haze veil →
foreground treeline** (baked by `tools/gen_wilds_reveal.py`), pauses the tree, fades up
from black, slow-pushes in on **Tera** looming above the lesser forest with a line of
narration, then fades back to play (skippable on any key). Atmospheric perspective —
the pale `wilds_haze` band — pushes the tree back behind the nearer trees so it reads as
*far*. Re-bake/tune the shot in `gen_wilds_reveal.py` (it also writes a `/tmp` preview
still). Headless: `tools/validate_wilds_reveal.gd`.

### Cozy tools as verbs (the Stardew layer)
Tools are **real verbs**, not menus: select a tool/seed on the item hotbar and press
**F** (`use_item`). `item_hotbar.use_active` drinks a consumable; anything else routes
to `player._use_held_on_facing`, which dispatches by item type — a `ToolItem` calls the
target's `use_tool(kind, player)`, a `SeedItem` calls `try_plant(crop, player)`.
**Targeting is by proximity, not the mouse** (`player._nearest_tool_target`, within
`TOOL_REACH`): stand on/next to the thing and use it — no precise aiming, the
Stardew feel. (Interaction, E, still uses the mouse-aimed `interact_probe`.) Using a
tool plays a visible swing (`PlayerVisuals.swing_tool` sweeps the tool's icon). World
objects opt in by implementing the contract:
- **FarmPlot** — **hoe** tills bare soil, a **seed** plants on tilled soil, the
  **watering can** waters a thirsty crop, and **F over a ripe crop** harvests it. (The
  old E-interact menu still works as a fallback.)
- **ChoppableTree** (`scripts/tree.gd` on `props/tree.tscn`) — the actual trees you see;
  the **axe** fells one for wood, then it topples and fades. The generator marks
  **border** trees `choppable = false` so felling can't breach the area frame.
- **GatherNode** — gains a `required_tool`: **pickaxe** for stone/ore/crystal veins
  (herbs/forage stay hand-gathered with E). Set by the generator from `GATHER_TOOLS`.
- **FishingSpot** (`scripts/fishing_spot.gd`, `scenes/entities/fishing_spot.tscn`) —
  dropped at every **pond** the generator paints; cast with the **fishing rod** (F) or
  interact (E) carrying one. A short cast resolves into a random fish from `catch_table`
  (`river_fish` / `lake_bass`).

All of it reports `Events.tool_used(kind, position)` so **AudioManager** plays the
matching synthesized sound (`dig`/`water`/`gather`/`chop`/`cast`) — gameplay never
touches the audio/VFX systems. New tool/fish art is baked by `tools/gen_tools.py`; the
starting kit hands the player all five tools. Full keybinds live in `docs/CONTROLS.md`.
Headless coverage: `tools/validate_tools.gd`.

### Recruiting the camp (the cozy-social → automation loop)
Befriend a camp member, enlist them, and they tend the camp while you're off in
the wilds — the bridge from the relationship layer to the farming layer.

- **The gate is friendship.** An `NpcData` flagged `recruitable` (with a
  `recruit_role` and `recruit_hearts`) surfaces a "lend a hand" choice in
  conversation *once the player has reached `recruit_hearts`* — so you earn helpers
  by talking/gifting (the Relationships loop), not by buying them. `npc.gd` adds the
  choice in `_build_main_menu`; choosing it calls `CampManager.recruit`.
- **CampManager** (autoload, pure data manager like FarmManager) owns the roster
  (`{npc_id: {name, role, active}}`) and runs the chores. It listens on
  `TimeManager.day_changed`, and **because it's registered after FarmManager**, its
  handler fires *after* FarmManager has matured the watered crops. Four **roles**:
  a **farmhand** harvests what just ripened (into `StorageManager.stash`) and
  re-waters every remaining crop for the next night; a **forager** brings wild goods
  (`FORAGE_TABLE`); a **woodcutter** stocks building materials (`MATERIAL_TABLE`);
  a **cook** turns stash produce into Camp Stew (a healing meal). That farmhand
  ordering *is* the "they keep your crops growing while you're away" loop. Each dawn
  it emits `chores_reported` and pops a `UIManager.notify` summary.
- **The camp economy.** What the workers bring in funds **camp upgrades**
  (`CampUpgrade` `.tres` in `resources/camp/upgrades/`, loaded like the Skills
  catalog): spend stash goods (`CampManager.purchase`) to raise the **recruit cap**
  (`recruit_slots`), let each farmhand work more rows (`plots_per_farmhand`), or
  boost gather yields (`yield`). A new upgrade is "author one `.tres`" as long as its
  `effect` is one CampManager's accessors read. So the loop is gather → build →
  recruit more → gather more, and a few tents grow into a settlement.
- **The player menu's Camp tab** (`player_menu._build_camp`) shows the roster
  (name + role) with a **Working/Resting** toggle, the **recruit count vs cap**, the
  **Improvements** store (Buy buttons gated on affordability), and last night's
  report. Resting members skip chores.
- **Add a recruit** by authoring an `NpcData` `.tres` with the recruit fields and a
  `recruit_role` CampManager understands (`&"farmhand"`/`&"forager"`/`&"woodcutter"`/
  `&"cook"`), then drop the NPC into a scene. Bram (farmhand), Wrenna (forager), Pell
  (cook) and Hadrin (woodcutter) live in the camp (`settlement.tscn`). Add a **new
  role** by extending the `match` in `CampManager._on_day_changed`. Headless
  coverage: `tools/validate_camp.gd`.
- CampManager is persistent (SaveManager contract — roster + owned upgrades) and
  reset on new game.

### Heart events (the social → story payoff)
Rising friendship pays off in **authored cutscenes**. A `HeartEvent` resource
(`scripts/heart_event.gd`, `.tres` under `resources/heart_events/`) names an
`npc_id` + `hearts` threshold, the `lines` to play, and optional rewards (a Story
`set_flag`, a keepsake deposited to the stash). **HeartEventManager** (autoload,
persistent) loads the catalog and listens on `Relationships.hearts_changed`. Because
the threshold is usually crossed *inside* a conversation (a gift, small talk), the
event is **queued and played once the current dialogue closes** (via the dialogue's
`finished` signal), never interrupting it — `_try_play` no-ops while
`UIManager.dialogue.is_active()`. Rewards apply the moment the event is eligible
(`check_and_apply`, split out so it's testable without the UI). Each event is
one-shot (a `_seen` set, saved). Bram's and Wrenna's 4-heart events are the first
two — author a `.tres` to add more. Headless coverage:
`tools/validate_heart_events.gd`.

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

**The Vast** (the `MONSTER` faction — the Cursed-Wilds threshold) fields three
threats: the baseline **Withered** (`enemy_withered`), a fast swarming **Vast Hound**
(`enemy_vast_hound`, wolf brain + corrupted tint), and a slow elite **Vast Hulk**
(`enemy_vast_hulk`, high HP/damage, scaled up). All are hostile to everything and seed
the `cursed_wilds` / `vast_edge` biomes plus the `withered_horde` and `vast_pack`
encounters; each drops a crystal (the hulk a potion too). Distinct silhouettes are
placeholder retints/reuses for now — bespoke Vast art is a follow-up.

**The boss.** `BossEnemy` (`scripts/boss_enemy.gd`, a thin `Enemy` subclass) is the
skill-check the curve builds toward — the **Withered Colossus**
(`enemy_vast_colossus.tscn`). It keeps the base wind-up→strike rhythm but adds
**health-gated phases** (`phase_thresholds`): each threshold it crosses it sharpens
wind-ups, shortens recovery, speeds up, and a `UIManager.notify` banner announces the
turn. From phase 2 it gains a telegraphed **ground slam** — a long, readable wind-up
(roll out of it) then radial damage + a screen jolt — reusing the same hostile-in-
radius pattern as the melee strike so faction rules still apply. It overrides
`apply_tier` for a gentler HP curve (bosses are already big). It ships as the rare,
`min_tier`-6, low-weight `vast_colossus` encounter in the two Cursed-Wilds biomes, and
**always** drops its trophy, the unique **Blightbane** blade (`loot_chance = 1.0`).
Author another boss by putting `BossEnemy` on a scene and tuning the exports. Headless
coverage: `tools/validate_boss.gd`.

**Talkable NPCs** (`scripts/npc.gd`, an `Area2D`) drive the social loop and, when
given a `schedule` + `home_waypoint`, walk a daily route between `npc_waypoint`
markers on `TimeManager.period_changed`. Between scheduled moves they now **idle-wander**
gently around their current station (small radius, with pauses) so the town reads as
lived-in rather than frozen. Families may share a `home_*` marker; daytime stations
stay distinct. Headless: `tools/validate_schedules.gd`.

**The crowd (cosmetic townsfolk).** A bustling city needs more bodies than it has
quest-givers, so `scripts/townsfolk.gd` (`class_name Townsfolk`, `scenes/entities/
townsfolk.tscn`) is a lightweight **non-interactive pedestrian**: a `Node2D` that
strolls between shared waypoints (the `npc_waypoint` group by default), milling a beat
at each then picking a new one. It reuses the same 4×8 directional walk-sheet animation
(`dir_util.gd`) the talking NPCs use, so the crowd moves identically — but carries **no
dialogue/quest/relationship/gift state** and isn't in the `"interactable"` group, and
has **no collision** (the player walks right through them). They're spawned in bulk by
`scripts/townsfolk_crowd.gd` (`townsfolk_crowd.tscn`): one node that instances `count`
Townsfolk at random stroll points with varied looks (cycled from a sprite pool) and
gaits. Crucially the spawner adds them to **its parent** (the scene's y-sorted
`Entities` root), not under itself, so each pedestrian depth-sorts against the buildings
by its own feet. Cleeve's Landing carries a crowd of 9. **Chimney smoke**
(`scenes/entities/props/chimney_smoke.tscn`, a `CPUParticles2D` over `light_soft`) rises
from the hearth buildings (townhouse/tavern/blacksmith/cabin — added as a child of each
prop scene so it shows everywhere they're placed); it sits on the painted chimney mouth
and reads against the existing `night_light.gd` window-glow for a lived-in skyline.
Headless: `tools/validate_townlife.gd`.

**Ambient animals.** `scripts/critter.gd` (`class_name Critter`) is a cosmetic animal:
a `Node2D` with **no collision** that wanders/pecks around a home spot, animating off
the **4×4 directional animal sheet** (rows down/up/left/right) via `dir_util` — the
same rig the wildlife uses, but with no physics body. Exports tune the behaviour:
`idle_peck` nibbles in place while paused; `skittish` flees the player within
`flush_radius`; a `flyer` **takes wing** on a flush (rises + fades, latched so it
commits even after clearing the radius, then respawns near home after `respawn_delay`).
Three ship — `chicken.tscn` (pecking hen, scurries), `dog.tscn` (ambling, friendly),
`bird.tscn` (skittish flyer): the camp keeps a few hens by the farm and Cleeve's
Landing has a street dog plus a **flock of plaza birds that scatter** when you run
through them. Art is baked by `tools/gen_critters.py` (pixelforge, grounded palette);
add an animal by authoring a sheet + a tuned `Critter` scene. Headless:
`tools/validate_critters.gd`.

**Dialogue portraits.** Conversations show the speaker's **bust** beside their lines.
The dialogue box (`scripts/autoload/dialogue.gd`) renders a portrait `TextureRect` in
an HBox to the left of the text; `start()` / `start_conversation()` take an optional
portrait, and any per-line/menu node can override it with a `"portrait"` key (so a
gift the NPC *loves* swaps to their **happy** expression mid-conversation). Portraits
resolve **by convention** — `UIManager.dialogue.portrait_for(npc_id, happy)` loads
`assets/placeholder/portraits/portrait_<id>[_happy].png` (cached; a missing happy
falls back to neutral, a missing portrait to null so an NPC without art just shows no
bust). `npc.gd` passes the speaker's portrait into every conversation and the happy
one on loved/liked gifts; `HeartEventManager` shows it during heart-event cutscenes.
The busts are baked by **`tools/gen_portraits.py`** (built on pixelforge, grounded
palette + upper-left key light, a neutral + happy per NPC). Headless coverage:
`tools/validate_portraits.gd`.

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
  Pull colors from here so everything sits in the same world. Every material ramp is
  **hue-shifted** (run through `grade()` at class build): highlights drift warm +
  desaturate, shadows drift cool + saturate, with a touch of added contrast — the
  pro-pixel-art depth that flat value-darkening misses, kept subtle so the world stays
  earthy. **Regenerating any sprite picks this up for free**; after touching the palette
  or `grade()`, re-run every `gen_*.py` so the look stays cohesive.
- **Hue-shift shading helpers** (use these when authoring new shading instead of plain
  `shade`): `rgb_to_hsv`/`hsv_to_rgb`, `hue_shift(c, k)` (shade one colour by ramp
  position `k∈[-1..1]` with hue rotation), `ramp_hue(base)` (a hue-shifted ramp from a
  single base), and `grade(ramp)` (enrich an existing light→dark ramp, preserving its
  lightness). Light drifts toward `LIGHT_HUE` (warm gold), shadow toward `SHADOW_HUE`
  (cool blue-violet).
- **`class Canvas`** — a pixel buffer with drawing primitives (`rect`, `frame`,
  `line`, `ellipse`, `disc`, `shade_rect` bevel, gradients, `dither`, `mottle`
  value-noise fill, `speckle`) and post pass helpers (`outline`, `rim_light`
  warm lit-edge glow, `drop_shadow`, `replace` palette-swap, `tint`, `blit`,
  `region`, `scaled`, `save`). `rim_light(amount, color)` brightens the
  upper-left (key-light) silhouette edge so a sprite pops off busy terrain —
  apply it *before* `outline` so the ink sits just outside the rim.
- Per-sprite generator scripts live in `tools/gen_*.py` and import pixelforge;
  they paint to `assets/placeholder/`. Run a generator to (re)bake its PNG — art
  is regenerated, not hand-edited. (`gen_char.py` walk sheets, `gen_portraits.py`
  dialogue busts, `gen_props.py`/`gen_nature.py`/… world props, etc.)
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
- **Warnings are errors.** The project compiles with warnings-as-errors, so keep
  code warning-clean — notably, never `var x := <Variant>` (type it or drop the
  `:=`).

## Testing & CI

The codebase leans hard on *content-as-data*, which has a sharp edge: a typo'd
`res://` path **fails silently** (e.g. `BiomeData.pick_enemy_path` just skips a
missing scene). The safety net is a headless validation suite, run on every
PR/push by **`.github/workflows/ci.yml`** (downloads Godot 4.6, imports, runs the
suite) and locally by **`tools/run_checks.sh`**:

```
GODOT=/path/to/Godot_v4.6 bash tools/run_checks.sh   # all checks must say RESULT: PASS
```

- **`tools/validate_content.gd`** is the lint that catches the broken-path /
  duplicate-id class across *every* `.tres` by reflection — no per-type code, so new
  resource types are covered for free. Run it after authoring content.
- **`tools/validate_*.gd`** are per-system headless smoke tests (each a `SceneTree`
  script printing `RESULT: PASS`/`FAIL`). Add one when you add a system.
- **Writing a validator — avoid the frame-0 trap.** Autoload globals (`UIManager`,
  etc.) and `class_name` references aren't registered when a `-s` script compiles.
  So: **`load()` inside `_run` after `await process_frame`, never top-level
  `preload`/`const`**; defer work via `_initialize() -> _run.call_deferred()`; and
  identify nodes by **script path** (`get_script().resource_path.ends_with(...)`),
  not `is SomeClassName`, or you force that script (and its autoload deps) to compile
  too early and poison every instance.
- **Web sessions:** `.claude/hooks/session-start.sh` fetches Godot + imports so the
  suite is runnable in Claude Code on the web (no more shipping blind).
