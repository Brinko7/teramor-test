extends RefCounted
class_name AffixRoller

## Turns a generic dropped weapon/armor into a per-instance rolled item: duplicates
## the base .tres (never mutating the shared resource), stamps 0-2 random affixes
## scaled by the drop tier, renames it, and bumps its rarity. Authored unique gear
## (rarity above COMMON) and non-equipment pass through untouched, so hand-made
## legendaries keep their identity. Affixes are data — resources/affixes/*.tres.

const AFFIX_DIR := "res://resources/affixes/"

static var _pool: Array = []
static var _loaded: bool = false
static var _rng: RandomNumberGenerator = null

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	var dir := DirAccess.open(AFFIX_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.ends_with(".tres"):
			var a := load(AFFIX_DIR + fn) as AffixData
			if a != null:
				_pool.append(a)
		fn = dir.get_next()

## Return a rolled duplicate of `base` (or `base` unchanged if it's not generic
## equipment or no affixes rolled). Safe to call on every drop.
static func roll(base: Item, tier: int) -> Item:
	if base == null or not (base.is_weapon() or base.is_armor()):
		return base
	if base.rarity != Item.Rarity.COMMON:   # preserve authored uniques
		return base
	_ensure_loaded()
	if _pool.is_empty():
		return base
	var count := _roll_count(tier)
	if count <= 0:
		return base
	var item := base.duplicate(true) as Item
	if item == null:
		return base
	item.base_path = base.resource_path   # the duplicate's own path is empty
	var prefix := _pick(base, AffixData.Slot.PREFIX)
	var suffix := _pick(base, AffixData.Slot.SUFFIX)
	var applied := 0
	if count >= 1 and prefix != null:
		_apply(item, prefix, tier)
		item.name = "%s %s" % [prefix.word, item.name]
		applied += 1
	if count >= 2 and suffix != null:
		_apply(item, suffix, tier)
		item.name = "%s of %s" % [item.name, suffix.word]
		applied += 1
	# If only one slot was available, still grant the second roll from it.
	if applied < count:
		var extra := _pick(base, AffixData.Slot.SUFFIX if prefix != null else AffixData.Slot.PREFIX)
		if extra != null:
			_apply(item, extra, tier)
			applied += 1
	if applied == 0:
		return base
	item.rarity = mini(Item.Rarity.COMMON + applied, Item.Rarity.RARE) as Item.Rarity
	item.rolled = true
	return item

static func _roll_count(tier: int) -> int:
	var n := 0
	var chance := clampf(0.40 + 0.10 * float(maxi(0, tier - 1)), 0.0, 0.92)
	for i in range(2):
		if _rng.randf() < chance:
			n += 1
			chance *= 0.55
		else:
			break
	return n

static func _pick(item: Item, slot: int) -> AffixData:
	var cands: Array = []
	var total := 0.0
	for a: AffixData in _pool:
		if a.slot == slot and a.fits(item):
			cands.append(a)
			total += maxf(0.01, a.weight)
	if cands.is_empty():
		return null
	var r := _rng.randf() * total
	for a: AffixData in cands:
		r -= maxf(0.01, a.weight)
		if r <= 0.0:
			return a
	return cands.back()

static func _apply(item: Item, affix: AffixData, tier: int) -> void:
	if affix.is_status():
		# A status affix grants the weapon an on-hit effect rather than a stat bonus.
		item.on_hit_status = affix.status_kind
		item.on_hit_power = affix.status_power + int(round(affix.per_tier * float(maxi(0, tier - 1))))
		item.on_hit_duration = affix.status_duration
		item.on_hit_chance = affix.status_chance
		item.on_hit_magnitude = affix.status_magnitude
		return
	var mag := affix.magnitude(tier, _rng)
	match affix.stat:
		AffixData.Stat.MELEE:
			item.bonus_melee += mag
		AffixData.Stat.RANGED:
			item.bonus_ranged += mag
		AffixData.Stat.SPELL:
			item.bonus_spell += mag
		AffixData.Stat.MAX_HP:
			item.bonus_max_hp += mag
		AffixData.Stat.DEFENSE:
			item.bonus_defense += mag
