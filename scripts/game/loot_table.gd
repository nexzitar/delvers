class_name LootTable

## Loot philosophy: drops are rare enough to matter. Each slain enemy
## consults its own loot table (archers drop bows, not battle swords)
## and usually drops nothing. Item level — the room it dropped in —
## decides an item's strength; rarity is rolled separately, weighted
## heavily toward the low end, with depth unlocking better odds rather
## than granting them. Bosses roll rare, with a sliver of epic.

const QUALITY_MULT := {
	ItemQuality.Tier.COMMON: 1.0,
	ItemQuality.Tier.UNCOMMON: 1.15,
	ItemQuality.Tier.RARE: 1.35,
	ItemQuality.Tier.EPIC: 1.6,
	ItemQuality.Tier.LEGENDARY: 1.9,
}

## Stat growth per item level above 1.
const LEVEL_STEP := 0.12

static func roll_quality(depth: int, boss := false) -> int:
	if boss:
		if randf() < 0.03:
			return ItemQuality.Tier.EPIC
		return ItemQuality.Tier.RARE
	var roll = randf()
	if roll < 0.01:
		return ItemQuality.Tier.RARE
	if roll < 0.01 + 0.12 + 0.02 * depth:
		return ItemQuality.Tier.UNCOMMON
	return ItemQuality.Tier.COMMON

## Builds a concrete item: authored base stats scaled by item level,
## with a smaller premium for rarity. Deterministic, so saved items
## rebuild identically from (id, level, quality).
static func materialize(gear_id: String, item_level: int, quality: int) -> GearDefinition:
	var path = RosterSave.GEAR_PATHS.get(gear_id)
	if path == null:
		return null
	var gear: GearDefinition = load(path).duplicate()
	gear.item_level = maxi(1, item_level)
	gear.quality = quality
	var mult = (1.0 + LEVEL_STEP * (gear.item_level - 1)) * QUALITY_MULT[quality]
	if gear.damage_min > 0 or gear.damage_max > 0:
		gear.damage_min = maxi(1, roundi(gear.damage_min * mult))
		gear.damage_max = maxi(gear.damage_min, roundi(gear.damage_max * mult))
	gear.attack_bonus = roundi(gear.attack_bonus * mult)
	gear.health_bonus = roundi(gear.health_bonus * mult)
	return gear

## Rolls drops for a defeated pack. Most enemies drop nothing.
static func roll_enemy_drops(enemy_templates: Array, room: int) -> Array:
	var drops := []
	for template in enemy_templates:
		if template.loot_ids.is_empty():
			continue
		if randf() > template.drop_chance:
			continue
		var gear = materialize(
			template.loot_ids.pick_random(),
			room,
			roll_quality(room, template.is_boss)
		)
		if gear:
			drops.append(gear)
	return drops
