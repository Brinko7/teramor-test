extends Resource
class_name AbilityData

## Data-driven elemental ability. Author a .tres and drop it into a player's
## AbilityCaster hotbar — no new code needed. `behavior` selects how it resolves:
## PROJECTILE fires a travelling orb, NOVA strikes all enemies in a radius around
## the caster, HEAL restores the caster's own health. An optional on-hit status
## (`status_kind` matching StatusEffect.Kind: 1=BURN, 2=SLOW) adds depth.

enum Element { FIRE, WATER, EARTH, LIGHT }
enum Behavior { PROJECTILE, NOVA, HEAL }

@export var id: StringName = &""
@export var display_name: String = "Ability"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var element: Element = Element.FIRE
@export var behavior: Behavior = Behavior.PROJECTILE

## Cost and pacing.
@export var mana_cost: int = 6
@export var cooldown: float = 1.0
## Base effect magnitude (damage for offense, HP for HEAL); spell power is added.
@export var power: int = 8

## PROJECTILE tuning.
@export var projectile_speed: float = 200.0
@export var cast_range: float = 160.0
## NOVA tuning: strike radius around the caster.
@export var radius: float = 44.0

## Colour applied to the spawned effect (orb / nova ring).
@export var tint: Color = Color(1, 1, 1, 1)

## On-hit status (0=none, 1=burn, 2=slow). See StatusEffect.Kind.
@export var status_kind: int = 0
@export var status_power: int = 0
@export var status_duration: float = 0.0
## SLOW only: speed multiplier in (0,1).
@export var status_magnitude: float = 1.0
