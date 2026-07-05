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

## Rolls drops for a defeated pack: monsters drop resources and
## knowledge, not equipment. Returns
## {"materials": {id: count}, "recipes": [recipe_id], "gear": [GearDefinition]}.
## known_recipes suppresses already-learned knowledge (nothing wasted:
## a known recipe simply doesn't drop).
static func roll_enemy_drops(enemy_templates: Array, room: int, known_recipes := []) -> Dictionary:
	var drops := {"materials": {}, "recipes": [], "gear": []}
	var seen: Array = known_recipes.duplicate()

	for template in enemy_templates:
		# Materials: the common reward, in this enemy's identity.
		if not template.material_loot.is_empty() \
				and randf() <= template.material_drop_chance:
			var material_id = template.material_loot.pick_random()
			var count = 1 + (1 if randf() < 0.25 else 0)
			drops.materials[material_id] = drops.materials.get(material_id, 0) + count

		# Recipes: rare permanent knowledge (bosses teach something new
		# whenever anything remains unlearned).
		if randf() <= template.recipe_drop_chance:
			var unknown = template.recipe_loot.filter(
				func(id): return not seen.has(id)
			)
			if not unknown.is_empty():
				var recipe_id = unknown.pick_random()
				drops.recipes.append(recipe_id)
				seen.append(recipe_id)

		# Finished equipment: a memorable fluke, or a boss trophy.
		if not template.loot_ids.is_empty() and randf() <= template.drop_chance:
			var gear = materialize(
				template.loot_ids.pick_random(),
				room,
				roll_quality(room, template.is_boss)
			)
			if gear:
				drops.gear.append(gear)
	return drops
