class_name RosterSave

## Saves and restores the player's roster: heroes (name, loadout, skill
## slots), the shared gear stash, and party progress. Items serialize
## by stable id and are rebuilt as fresh duplicates on load, preserving
## the "each item is one physical object" model.

const SAVE_PATH := "user://delvers_save.json"
const VERSION := 7

const MATERIAL_PATHS := {
	"gel": "res://resources/materials/gel.tres",
	"acidic_ooze": "res://resources/materials/acidic_ooze.tres",
	"corrosion_core": "res://resources/materials/corrosion_core.tres",
	"iron_scrap": "res://resources/materials/iron_scrap.tres",
	"ash_wood": "res://resources/materials/ash_wood.tres",
	"bow_string": "res://resources/materials/bow_string.tres",
	"poison_sac": "res://resources/materials/poison_sac.tres",
	"royal_jelly": "res://resources/materials/royal_jelly.tres",
	"leather": "res://resources/materials/leather.tres",
	"silk_thread": "res://resources/materials/silk_thread.tres",
	"chitin_plate": "res://resources/materials/chitin_plate.tres",
	"brass_fitting": "res://resources/materials/brass_fitting.tres",
	"engine_oil": "res://resources/materials/engine_oil.tres",
	"cog_wheel": "res://resources/materials/cog_wheel.tres",
	"brood_silk": "res://resources/materials/brood_silk.tres",
}

const RECIPE_PATHS := {
	"iron_sword": "res://resources/recipes/iron_sword.tres",
	"hunter_bow": "res://resources/recipes/hunter_bow.tres",
	"reinforced_shield": "res://resources/recipes/reinforced_shield.tres",
	"iron_helm": "res://resources/recipes/iron_helm.tres",
	"leather_hood": "res://resources/recipes/leather_hood.tres",
	"silk_hood": "res://resources/recipes/silk_hood.tres",
	"chitin_shield": "res://resources/recipes/chitin_shield.tres",
	"chitin_armor": "res://resources/recipes/chitin_armor.tres",
	"iron_shod_boots": "res://resources/recipes/iron_shod_boots.tres",
	"goblin_work_gauntlets": "res://resources/recipes/goblin_work_gauntlets.tres",
	"studded_belt": "res://resources/recipes/studded_belt.tres",
	"iron_greaves": "res://resources/recipes/iron_greaves.tres",
	"wardens_pauldrons": "res://resources/recipes/wardens_pauldrons.tres",
	"silk_bracers": "res://resources/recipes/silk_bracers.tres",
	"weavers_cloak": "res://resources/recipes/weavers_cloak.tres",
	"oiled_leathers": "res://resources/recipes/oiled_leathers.tres",
	"sprung_boots": "res://resources/recipes/sprung_boots.tres",
	"engineers_goggles": "res://resources/recipes/engineers_goggles.tres",
}

const AFFIX_PATHS := {
	"virulent": "res://resources/affixes/virulent.tres",
	"frostforged": "res://resources/affixes/frostforged.tres",
	"flaming": "res://resources/affixes/flaming.tres",
	"quick": "res://resources/affixes/quick.tres",
	"guarding": "res://resources/affixes/guarding.tres",
}

## Ordered: fragments are recovered lowest-order first, so the story
## assembles like a trail of evidence.
const LORE_PATHS := {
	"expedition_log_1": "res://resources/lore/expedition_log_1.tres",
	"expedition_log_2": "res://resources/lore/expedition_log_2.tres",
	"expedition_log_3": "res://resources/lore/expedition_log_3.tres",
	"expedition_log_4": "res://resources/lore/expedition_log_4.tres",
	"expedition_nest_1": "res://resources/lore/expedition_nest_1.tres",
	"expedition_nest_2": "res://resources/lore/expedition_nest_2.tres",
	"expedition_nest_3": "res://resources/lore/expedition_nest_3.tres",
	"expedition_nest_4": "res://resources/lore/expedition_nest_4.tres",
	"workshop_log_1": "res://resources/lore/workshop_log_1.tres",
	"workshop_log_2": "res://resources/lore/workshop_log_2.tres",
	"workshop_log_3": "res://resources/lore/workshop_log_3.tres",
	"workshop_log_4": "res://resources/lore/workshop_log_4.tres",
}

const DUNGEON_PATHS := {
	"darkwood": "res://resources/dungeons/darkwood.tres",
	"spider_nest": "res://resources/dungeons/spider_nest.tres",
	"sunken_workshop": "res://resources/dungeons/sunken_workshop.tres",
}

const HERO_PATHS := {
	"default_delver": "res://resources/heroes/default_delver.tres",
}

const GEAR_PATHS := {
	"starter_sword": "res://resources/gear/starter_sword.tres",
	"starter_bow": "res://resources/gear/starter_bow.tres",
	"starter_shield": "res://resources/gear/starter_shield.tres",
	"starter_helmet": "res://resources/gear/starter_helmet.tres",
	"starter_armor": "res://resources/gear/starter_armor.tres",
	"fast_dagger": "res://resources/gear/fast_dagger.tres",
	"heavy_axe": "res://resources/gear/heavy_axe.tres",
	"iron_shod_boots": "res://resources/gear/iron_shod_boots.tres",
	"goblin_work_gauntlets": "res://resources/gear/goblin_work_gauntlets.tres",
	"studded_belt": "res://resources/gear/studded_belt.tres",
	"silk_hood": "res://resources/gear/silk_hood.tres",
	"chitin_shield": "res://resources/gear/chitin_shield.tres",
	"chitin_armor": "res://resources/gear/chitin_armor.tres",
	"iron_greaves": "res://resources/gear/iron_greaves.tres",
	"wardens_pauldrons": "res://resources/gear/wardens_pauldrons.tres",
	"silk_bracers": "res://resources/gear/silk_bracers.tres",
	"weavers_cloak": "res://resources/gear/weavers_cloak.tres",
	"oiled_leathers": "res://resources/gear/oiled_leathers.tres",
	"sprung_boots": "res://resources/gear/sprung_boots.tres",
	"engineers_goggles": "res://resources/gear/engineers_goggles.tres",
}

const SKILL_PATHS := {
	"auto_attack": "res://resources/skills/auto_attack.tres",
	"arrow_shot": "res://resources/skills/arrow_shot.tres",
	"frost_nova": "res://resources/skills/frost_nova.tres",
	"hamstring": "res://resources/skills/hamstring.tres",
	"charge": "res://resources/skills/charge.tres",
	"heal": "res://resources/skills/heal.tres",
	"cleave": "res://resources/skills/cleave.tres",
	"whirlwind": "res://resources/skills/whirlwind.tres",
	"renew": "res://resources/skills/renew.tres",
	"shield_wall": "res://resources/skills/shield_wall.tres",
	"thunderclap": "res://resources/skills/thunderclap.tres",
	"multishot": "res://resources/skills/multishot.tres",
	"piercing_shot": "res://resources/skills/piercing_shot.tres",
	"battle_shout": "res://resources/skills/battle_shout.tres",
	"rally": "res://resources/skills/rally.tres",
}

## Items serialize as {id, level, quality} and rebuild deterministically
## through LootTable.materialize.
static func _gear_entry(gear) -> Dictionary:
	return {
		"id": gear.gear_id,
		"level": gear.item_level,
		"quality": int(gear.quality),
		"affix": gear.affix_id,
		"name": gear.gear_name,
	}

static func save(roster, path := SAVE_PATH) -> void:
	var heroes := []
	for hero in roster.heroes:
		var equipped := {}
		for pos in hero.equipped:
			equipped[str(pos)] = _gear_entry(hero.equipped[pos])
		heroes.append({
			"template": "default_delver",
			"name": hero.hero_name,
			"equipped": equipped,
			"bonus_skills": hero.bonus_skills.map(
				func(s): return s.skill_id if s is SkillDefinition else null
			),
			"tactic": hero.tactic,
			"mastery": hero.mastery,
			"custom_tree": hero.custom_tree,
		})

	var data := {
		"version": VERSION,
		"battles_fought": roster.battles_fought,
		"adventures_completed": roster.adventures_completed,
		"last_battle_won": roster.last_battle_won,
		"bonus_skill_slots": roster.bonus_skill_slots,
		"heroes": heroes,
		"stash": roster.gear_stash.map(_gear_entry),
		"materials": roster.material_stash,
		"known_recipes": roster.known_recipes,
		"known_affixes": roster.known_affixes,
		"known_lore": roster.known_lore,
		"known_tactics": roster.known_tactics,
		"known_engineering": roster.known_engineering,
		"purchased_unlocks": roster.purchased_unlocks,
		"unlocked_dungeons": roster.unlocked_dungeons,
		"current_dungeon": roster.current_dungeon,
		"enemy_priority": roster.enemy_priority,
		"dungeon_progress": roster.dungeon_progress,
		"rooms_since_knowledge": roster.rooms_since_knowledge,
		"seen_enemies": roster.seen_enemies,
	}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))

## Restores the roster from disk. Returns false (leaving the roster
## untouched) when there is no save or it can't be read.
static func load_into(roster, path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		return false
	# v5 saves load forward: they simply predate guild purchases.
	var version = int(data.get("version", 0))
	if version < 5 or version > VERSION:
		return false

	var heroes := []
	for entry in data.get("heroes", []):
		var hero = _restore_hero(entry)
		if hero:
			heroes.append(hero)
	if heroes.is_empty():
		return false

	roster.heroes = heroes
	for hero in roster.heroes:
		roster._sync_role(hero)

	roster.gear_stash = []
	for entry in data.get("stash", []):
		var gear = _gear_from_entry(entry)
		if gear:
			roster.gear_stash.append(gear)
	roster.sort_gear_stash()

	roster.battles_fought = int(data.get("battles_fought", 0))
	roster.adventures_completed = int(data.get("adventures_completed", 0))
	roster.last_battle_won = bool(data.get("last_battle_won", false))
	roster.bonus_skill_slots = int(data.get("bonus_skill_slots", 1))

	roster.material_stash = {}
	var materials = data.get("materials", {})
	for material_id in materials:
		if MATERIAL_PATHS.has(material_id):
			roster.material_stash[material_id] = int(materials[material_id])

	roster.known_recipes = []
	for recipe_id in data.get("known_recipes", []):
		if RECIPE_PATHS.has(recipe_id) and not roster.known_recipes.has(recipe_id):
			roster.known_recipes.append(recipe_id)

	roster.known_affixes = []
	for affix_id in data.get("known_affixes", []):
		if AFFIX_PATHS.has(affix_id) and not roster.known_affixes.has(affix_id):
			roster.known_affixes.append(affix_id)

	roster.known_lore = []
	for lore_id in data.get("known_lore", []):
		if LORE_PATHS.has(lore_id) and not roster.known_lore.has(lore_id):
			roster.known_lore.append(lore_id)

	roster.known_tactics = ["nearest"]
	for tactic_id in data.get("known_tactics", []):
		if not roster.known_tactics.has(tactic_id):
			roster.known_tactics.append(tactic_id)
	roster.known_engineering = []
	for entry_id in data.get("known_engineering", []):
		if (Doctrines.CAPACITY.has(entry_id) or Doctrines.TOOLS.has(entry_id)) \
				and not roster.known_engineering.has(entry_id):
			roster.known_engineering.append(entry_id)

	# Veterans predate doctrines: what they have fought with, they keep.
	if not data.has("known_tactics") and roster.battles_fought > 0:
		for doctrine_id in Doctrines.ALL:
			if not roster.known_tactics.has(doctrine_id):
				roster.known_tactics.append(doctrine_id)

	roster.purchased_unlocks = []
	for unlock_id in data.get("purchased_unlocks", []):
		if not roster.purchased_unlocks.has(unlock_id):
			roster.purchased_unlocks.append(unlock_id)

	roster.unlocked_dungeons = ["darkwood"]
	for dungeon_id in data.get("unlocked_dungeons", []):
		if DUNGEON_PATHS.has(dungeon_id) and not roster.unlocked_dungeons.has(dungeon_id):
			roster.unlocked_dungeons.append(dungeon_id)
	roster.current_dungeon = data.get("current_dungeon", "darkwood")
	if not roster.unlocked_dungeons.has(roster.current_dungeon):
		roster.current_dungeon = "darkwood"
	roster.enemy_priority = []
	for enemy_id in data.get("enemy_priority", []):
		if not roster.enemy_priority.has(enemy_id):
			roster.enemy_priority.append(enemy_id)
	roster.rooms_since_knowledge = int(data.get("rooms_since_knowledge", 0))
	roster.dungeon_progress = {}
	var progress = data.get("dungeon_progress", {})
	for dungeon_id in progress:
		if DUNGEON_PATHS.has(dungeon_id):
			roster.dungeon_progress[dungeon_id] = int(progress[dungeon_id])

	roster.seen_enemies = []
	for enemy_id in data.get("seen_enemies", []):
		if not roster.seen_enemies.has(enemy_id):
			roster.seen_enemies.append(enemy_id)
	# Veterans predate sightings: what they've clearly fought is seen.
	if roster.seen_enemies.is_empty():
		if roster.adventures_completed >= 1:
			roster.seen_enemies = ["green_slime", "goblin_archer",
				"goblin_warrior", "venomous_spider", "slime_king"]
		elif roster.battles_fought > 0:
			roster.seen_enemies = ["green_slime", "goblin_archer",
				"goblin_warrior"]

	# Veterans predate mastery: seasoned delvers start two stars deep
	# in whatever they are carrying right now.
	if roster.battles_fought > 0:
		for hero in roster.heroes:
			if not hero.mastery.is_empty():
				continue
			for discipline in Mastery.active_disciplines(hero):
				hero.mastery[discipline] = {"xp": 24, "best_xp": 24}

	# A pre-update save may already hold the first victory: the
	# companion arrives the moment the camp loads.
	roster.check_milestones()
	return true

static func _restore_hero(entry):
	var template_path = HERO_PATHS.get(entry.get("template", "default_delver"))
	if template_path == null:
		return null
	var hero = load(template_path).duplicate(true)
	hero.hero_name = entry.get("name", hero.hero_name)

	hero.equipped = {}
	var equipped = entry.get("equipped", {})
	for pos_key in equipped:
		var gear = _gear_from_entry(equipped[pos_key])
		if gear:
			hero.equipped[int(pos_key)] = gear

	hero.bonus_skills = []
	for skill_id in entry.get("bonus_skills", []):
		hero.bonus_skills.append(_skill_from_id(skill_id))
	hero.tactic = entry.get("tactic", "nearest")
	hero.custom_tree = entry.get("custom_tree", []) if entry.get("custom_tree", []) is Array else []
	hero.mastery = {}
	var mastery = entry.get("mastery", {})
	for discipline in mastery:
		hero.mastery[discipline] = {
			"xp": int(mastery[discipline].get("xp", 0)),
			"best_xp": int(mastery[discipline].get("best_xp", 0)),
		}
	return hero

## Unknown ids (e.g. content removed in an update) drop the item.
static func _gear_from_entry(entry):
	if not (entry is Dictionary) or not GEAR_PATHS.has(entry.get("id")):
		return null
	var affix_id = entry.get("affix", "")
	if affix_id != "" and not AFFIX_PATHS.has(affix_id):
		affix_id = ""
	var gear = LootTable.materialize(
		entry.get("id"),
		int(entry.get("level", 1)),
		int(entry.get("quality", ItemQuality.Tier.COMMON)),
		affix_id
	)
	if gear and entry.get("name", "") != "":
		gear.gear_name = entry.get("name")
	return gear

static func _skill_from_id(skill_id):
	if skill_id == null:
		return null
	# Older saves slotted core techniques; mastery owns them now.
	if Mastery.is_core(skill_id):
		return null
	var path = SKILL_PATHS.get(skill_id)
	return load(path) if path else null
