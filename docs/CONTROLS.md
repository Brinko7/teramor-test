# Teramor — Controls

> The complete keybind reference. The source of truth is `project.godot` `[input]`
> (plus the menu/system keys the UI handles directly); keep this table in sync when
> a binding changes. Keyboard + mouse today; gamepad + rebinding are planned.

Base viewport 480×270, scaled to 1280×720.

## Movement
| Input | Action |
|---|---|
| **W A S D** / **Arrow keys** | Move (8-directional) |
| **Mouse** | Aim |
| **Left Shift** | **Dodge-roll** — a quick dash with invulnerability (i-frames). Roll through an enemy's wind-up. |

## Combat
| Input | Action |
|---|---|
| **Left-click** (`attack_primary`) | Attack — melee swing / fire bow, aimed at the cursor |
| **Space** (`attack`) | Attack (alternate) |
| **Right-click** (`attack_secondary`) | Block / raise shield (if one is equipped) |
| **Hold Q** (`ability_menu`) | Open the ability radial |
| **1 2 3 4** (while Q held) | Cast unlocked elemental ability 1–4 toward the cursor |

## Items, tools & interaction
| Input | Action |
|---|---|
| **1 2 3 4 5 6 7 8 9 0** | Select item hotbar slot 1–10 (the first ten bag slots) |
| **Mouse wheel** | Cycle the hotbar selection |
| **F** (`use_item`) | Use the held item: drink a consumable, **or** act with a held tool/seed on the nearest target you're **standing by** (proximity, no precise aiming): |
| | • **Hoe** → till bare soil · **Seed** → plant on tilled soil · **Watering can** → water a crop · **F by a ripe crop** → harvest |
| | • **Pickaxe** → break rock/ore/crystal veins · **Axe** → fell a tree for wood · **Fishing rod** → cast at a pond |
| **E** (`interact`) | Talk to NPCs, open chests/doors, read signs, hand-gather herbs/forage, cast at a pond (if carrying a rod) |

> The number row is modal: it selects **hotbar items** normally, and casts **abilities
> 1–4** only while **Q** is held — so the two never collide.

## Menus
| Input | Action |
|---|---|
| **Tab** (`player_menu`) | Open the unified player menu (Inventory · Equipped · Stats · Skills · Quests · Social · Map) |
| **I** (`inventory`) | Jump to the Inventory tab (toggles shut if already there) |
| **J** (`journal`) | Jump to the Quests tab |
| **L** (`relationships`) | Jump to the Social tab |
| **C** (`crafting`) | Open the crafting panel |

## System
| Input | Action |
|---|---|
| **F5** (`save_game`) | Save |
| **F9** (`quick_load`) | Quick-load |

## Rebinding
The keyboard actions (movement, interact, dodge, use item, open menu, crafting,
abilities) are **rebindable** in **Options → Controls** (open Options from the title
screen or the player-menu footer). Overrides persist to `user://settings.cfg` via
`SettingsManager`, separate from the save. Combat stays mouse-aimed, so attack/block
aren't rebound. Options also has **Audio** volume sliders and **Display** toggles
(fullscreen, vsync, and an accessibility screen-shake toggle).

## Planned (not yet bound)
- **Gamepad** support and gamepad rebinding.
- A dedicated **pause** key (Esc) — Esc currently closes the open menu/overlay.
