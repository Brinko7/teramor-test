extends Node

## Autoload `Events`. A global signal bus that decouples gameplay systems:
## emitters and listeners never hold direct references to each other. Combat,
## progression, quests, and crafting all communicate through here.

## Emitted by an enemy when it dies. `enemy_id` lets contracts target a specific
## creature; `xp_reward` feeds progression; `position` lets quests and FX react at
## the death site. `by_player` is true only when the player landed the killing
## blow — so XP, quest credit and death juice skip enemy-vs-enemy faction kills.
signal enemy_killed(enemy_id: StringName, xp_reward: int, position: Vector2, by_player: bool)

## Emitted by the player's Stats component when a new level is reached.
signal player_leveled_up(new_level: int)

## Emitted whenever items actually enter the player's inventory. Quests use this
## for "collect N of X" objectives.
signal item_collected(item_id: StringName, count: int)

## Emitted by the crafting system after a successful craft.
signal item_crafted(item_id: StringName)

## --- Combat feel / juice ----------------------------------------------------
## Emitted whenever damage lands, so CombatFX can pop a number, shake, and
## hit-stop. `to_enemy` is true when a foe is the victim, false when the player
## is. `player_involved` is true only when the player dealt or took the hit, so
## screen shake and hit-stop skip enemy-vs-enemy faction brawls.
signal damage_dealt(position: Vector2, amount: int, to_enemy: bool, player_involved: bool)

## Requests a camera shake of the given strength (in pixels). The player camera's
## CameraShake listens.
signal screen_shake(strength: float)
