extends Node

## Autoload `Events`. A global signal bus that decouples gameplay systems:
## emitters and listeners never hold direct references to each other. Combat,
## progression, quests, and crafting all communicate through here.

## Emitted by an enemy when it dies. `enemy_id` lets contracts target a specific
## creature; `xp_reward` feeds progression; `position` lets quests and FX react at
## the death site.
signal enemy_killed(enemy_id: StringName, xp_reward: int, position: Vector2)

## Emitted by the player's Stats component when a new level is reached.
signal player_leveled_up(new_level: int)

## Emitted whenever items actually enter the player's inventory. Quests use this
## for "collect N of X" objectives.
signal item_collected(item_id: StringName, count: int)

## Emitted by the crafting system after a successful craft.
signal item_crafted(item_id: StringName)
