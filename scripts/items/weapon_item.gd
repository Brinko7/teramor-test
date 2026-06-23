extends Item
class_name WeaponItem

## A weapon the player can equip. Melee weapons drive the existing hitbox;
## ranged weapons spawn a projectile toward the facing direction.

enum WeaponClass { MELEE, RANGED }

@export var weapon_class: WeaponClass = WeaponClass.MELEE
@export var damage: int = 4
@export var attack_duration: float = 0.15
@export var attack_cooldown: float = 0.35
## Ranged-only: how far the projectile travels before despawning, and its speed.
@export var range: float = 160.0
@export var projectile_speed: float = 220.0
## In-hand sprite, drawn pointing along +X (toward the aim direction). Falls
## back to `icon` when unset.
@export var hold_texture: Texture2D
## How far from the hand the weapon sits, and its swing arc half-angle (radians).
@export var hold_distance: float = 10.0
@export var swing_arc: float = 1.1
## Where the held sprite grips (the pixel that lands on the hand). Set per weapon so
## one WeaponSprite node can carry blades (grip at the left edge) and bows (grip at
## the centre) without re-centring. Sword default; bows override to their riser.
@export var hold_offset: Vector2 = Vector2(0, -8)
## Melee-only: an 8-column ATTACK OVERLAY sheet (4 transparent walk cols + the
## weapon drawn at the hero's swinging hand for the 4 attack cols). Stacked over the
## body and synced to the swing frame, so the blade is carried by the actual arm —
## no floating sprite. Ranged weapons leave this null (they get a draw pose instead).
@export var attack_sheet: Texture2D
## Directional overlay sheet (96x320) showing the weapon stowed on the body when
## it is not in hand: a hip scabbard for blades, a slung stave for bows. Synced
## to the body's animation frame like a worn armour layer; swapped for the
## in-hand sprite while the player is mid-attack.
@export var stow_texture: Texture2D

func held_texture() -> Texture2D:
	return hold_texture if hold_texture != null else icon

func is_ranged() -> bool:
	return weapon_class == WeaponClass.RANGED
