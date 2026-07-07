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

## Depth unlocks rarity: deeper dungeons raise rare_chance and the
## boss's epic sliver rather than multiplying drop counts.
static func roll_quality(depth: int, boss := false, rare_chance := 0.01, epic_chance := 0.03) -> int:
	if boss:
		if randf() < epic_chance:
			return ItemQuality.Tier.EPIC
		return ItemQuality.Tier.RARE
	var roll = randf()
	if roll < rare_chance:
		return ItemQuality.Tier.RARE
	if roll < rare_chance + 0.12 + 0.02 * depth:
		return ItemQuality.Tier.UNCOMMON
	return ItemQuality.Tier.COMMON

## Builds a concrete item: authored base stats scaled by item level,
## with a smaller premium for rarity, optionally enchanted by an affix.
## Deterministic, so saved items rebuild identically from
## (id, level, quality, affix).
static func materialize(gear_id: String, item_level: int, quality: int, affix_id := "") -> GearDefinition:
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
	gear.armor = roundi(gear.armor * mult)
	gear.spell_power = roundi(gear.spell_power * mult)
	# Ratings (block/dodge/crit) stay flat: percentages don't inflate.

	if affix_id != "" and RosterSave.AFFIX_PATHS.has(affix_id):
		var affix = load(RosterSave.AFFIX_PATHS[affix_id])
		gear.affix_id = affix_id
		gear.gear_name = "%s %s" % [affix.affix_name, gear.gear_name]
		if gear.damage_min > 0 or gear.damage_max > 0:
			gear.damage_min = maxi(1, roundi(gear.damage_min * affix.damage_mult))
			gear.damage_max = maxi(
				gear.damage_min, roundi(gear.damage_max * affix.damage_mult)
			)
		if gear.attack_speed > 0.0:
			gear.attack_speed = snappedf(
				gear.attack_speed * affix.attack_speed_mult, 0.1
			)
		gear.health_bonus += affix.health_bonus_add
	return gear

## Rolls drops for a defeated pack: monsters drop resources and
## knowledge, not equipment. Returns {"materials": {id: count},
## "recipes": [recipe_id], "affixes": [affix_id], "gear": [...]}.
## known_recipes / known_affixes suppress already-learned knowledge
## (nothing wasted: known knowledge simply doesn't drop).
const LORE_DROP_CHANCE := 0.03

static func roll_enemy_drops(
		enemy_templates: Array, room: int,
		known_recipes := [], known_affixes := [], known_lore := [],
		dungeon: DungeonDefinition = null, unlocked_dungeons := [],
		tier := 1, known_doctrines := [],
) -> Dictionary:
	var drops := {"materials": {}, "recipes": [], "affixes": [], "gear": [],
		"lore": [], "maps": [], "doctrines": []}
	var seen_doctrines: Array = known_doctrines.duplicate()
	# Difficulty pays in materials, rarity odds, and tier-gated
	# knowledge — never in raw item level. Power comes from covering
	# more slots with the dungeon's answer, not bigger numbers.
	var item_level = room + (dungeon.level_offset if dungeon else 0)
	var rare_chance = (dungeon.rare_chance if dungeon else 0.01) + 0.03 * (tier - 1)
	var epic_chance = (dungeon.boss_epic_chance if dungeon else 0.03) + 0.03 * (tier - 1)
	var lore_series = dungeon.lore_ids if dungeon else RosterSave.LORE_PATHS.keys()
	var seen: Array = known_recipes.duplicate()
	var seen_affixes: Array = known_affixes.duplicate()

	for template in enemy_templates:
		# Materials: the common reward, in this enemy's identity.
		if not template.material_loot.is_empty() \
				and randf() <= template.material_drop_chance:
			var material_id = template.material_loot.pick_random()
			var count = template.material_drop_count + (tier - 1) \
				+ (1 if randf() < 0.25 else 0)
			drops.materials[material_id] = drops.materials.get(material_id, 0) + count

		# Recipes: rare permanent knowledge (bosses teach something new
		# whenever anything remains unlearned).
		if randf() <= template.recipe_drop_chance:
			var unknown = template.recipe_loot.filter(
				func(id):
					if seen.has(id):
						return false
					var recipe = load(RosterSave.RECIPE_PATHS[id])
					return recipe.min_tier <= tier
			)
			if not unknown.is_empty():
				var recipe_id = unknown.pick_random()
				drops.recipes.append(recipe_id)
				seen.append(recipe_id)

		# Affixes: the rarest knowledge of all.
		if randf() <= template.affix_drop_chance:
			var unknown_affixes = template.affix_loot.filter(
				func(id): return not seen_affixes.has(id)
			)
			if not unknown_affixes.is_empty():
				var affix_id = unknown_affixes.pick_random()
				drops.affixes.append(affix_id)
				seen_affixes.append(affix_id)

		# Doctrines: battlefield knowledge, taught by its practitioners.
		if randf() <= template.doctrine_drop_chance:
			var unknown_doctrines = template.doctrine_loot.filter(
				func(id): return not seen_doctrines.has(id)
			)
			if not unknown_doctrines.is_empty():
				var doctrine_id = unknown_doctrines.pick_random()
				drops.doctrines.append(doctrine_id)
				seen_doctrines.append(doctrine_id)

		# History: the next unrecovered fragment of THIS dungeon's
		# expedition, in order — evidence assembles the way a trail would.
		if randf() <= LORE_DROP_CHANCE:
			for lore_id in lore_series:
				if not known_lore.has(lore_id) and not drops.lore.has(lore_id):
					drops.lore.append(lore_id)
					break

		# Maps: bosses guard the way deeper. Dropped once, ever.
		if template.map_loot != "" \
				and not unlocked_dungeons.has(template.map_loot) \
				and not drops.maps.has(template.map_loot):
			drops.maps.append(template.map_loot)

		# Finished equipment comes only from bosses — and a trophy
		# always carries an affix, possibly one not yet learned:
		# wield it, or salvage it to study the enchantment.
		if not template.loot_ids.is_empty() and randf() <= template.drop_chance:
			var trophy_affix := ""
			if template.is_boss:
				trophy_affix = RosterSave.AFFIX_PATHS.keys().pick_random()
			var gear = materialize(
				template.loot_ids.pick_random(),
				item_level,
				roll_quality(room, template.is_boss, rare_chance, epic_chance),
				trophy_affix
			)
			if gear:
				drops.gear.append(gear)
	return drops

## Who to hunt for a material: the non-boss enemy with the most copies
## of it in their table (bosses only as a last resort).
const ENEMY_PATHS := [
	"res://resources/enemies/green_slime.tres",
	"res://resources/enemies/goblin_archer.tres",
	"res://resources/enemies/goblin_warrior.tres",
	"res://resources/enemies/venomous_spider.tres",
	"res://resources/enemies/nest_spiderling.tres",
	"res://resources/enemies/web_weaver.tres",
	"res://resources/enemies/chitin_crawler.tres",
	"res://resources/enemies/slime_king.tres",
	"res://resources/enemies/broodmother.tres",
]
static var _owner_cache := {}

static func material_owner(material_id: String) -> String:
	if _owner_cache.has(material_id):
		return _owner_cache[material_id]
	var best := ""
	var best_count := 0
	var boss_fallback := ""
	for path in ENEMY_PATHS:
		var template = load(path)
		var count = template.material_loot.count(material_id)
		if count == 0:
			continue
		if template.is_boss:
			if boss_fallback == "":
				boss_fallback = template.enemy_name
			continue
		if count > best_count:
			best_count = count
			best = template.enemy_name
	if best == "":
		best = boss_fallback
	_owner_cache[material_id] = best
	return best
