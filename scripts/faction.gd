extends RefCounted
class_name Faction

## Allegiance lookup for combatants. Every fighter carries a faction StringName;
## these static helpers decide who fights whom. The rule is deliberately simple:
## different factions are hostile, the same faction is allied, and anything in
## NEUTRAL (passive wildlife) never fights at all.
##
## Canon factions:
##   PLAYER  — the player (always a target for hostile factions)
##   BEAST   — wolves, bears (wild predators)
##   BANDIT  — raiders, archers, brutes (human outlaws)
##   MONSTER — the Withered and other corrupted horrors (hostile to all)
##   WILDLIFE — deer, rabbits; passive prey, fights no one
##
## Beast and Bandit are hostile to each other and to the player, so a wolf pack
## and a bandit patrol will clash if they meet — and the player can exploit it.

const PLAYER: StringName = &"player"
const BEAST: StringName = &"beast"
const BANDIT: StringName = &"bandit"
const MONSTER: StringName = &"monster"
const WILDLIFE: StringName = &"wildlife"

## Factions that never initiate or receive aggression (passive prey).
const NEUTRAL: Array[StringName] = [WILDLIFE]

## True when a fighter of faction `a` should attack a fighter of faction `b`.
## Same faction = allied; either side neutral = peace; otherwise hostile.
static func hostile(a: StringName, b: StringName) -> bool:
	if a == b:
		return false
	if a in NEUTRAL or b in NEUTRAL:
		return false
	return true
