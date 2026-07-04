class_name RosterSave

## Saves and restores the player's roster: heroes (name, loadout, skill
## slots), the shared gear stash, and party progress. Items serialize
## by stable id and are rebuilt as fresh duplicates on load, preserving
## the "each item is one physical object" model.

const SAVE_PATH := "user://delvers_save.json"
const VERSION := 1

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
}

const SKILL_PATHS := {
	"auto_attack": "res://resources/skills/auto_attack.tres",
	"arrow_shot": "res://resources/skills/arrow_shot.tres",
	"frost_nova": "res://resources/skills/frost_nova.tres",
	"hamstring": "res://resources/skills/hamstring.tres",
	"charge": "res://resources/skills/charge.tres",
	"heal": "res://resources/skills/heal.tres",
}

static func save(roster, path := SAVE_PATH) -> void:
	var heroes := []
	for hero in roster.heroes:
		var equipped := {}
		for pos in hero.equipped:
			equipped[str(pos)] = hero.equipped[pos].gear_id
		heroes.append({
			"template": "default_delver",
			"name": hero.hero_name,
			"equipped": equipped,
			"bonus_skills": hero.bonus_skills.map(
				func(s): return s.skill_id if s is SkillDefinition else null
			),
		})

	var data := {
		"version": VERSION,
		"battles_fought": roster.battles_fought,
		"adventures_completed": roster.adventures_completed,
		"last_battle_won": roster.last_battle_won,
		"heroes": heroes,
		"stash": roster.gear_stash.map(func(g): return g.gear_id),
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
	if data == null or int(data.get("version", 0)) != VERSION:
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
	for gear_id in data.get("stash", []):
		var gear = _gear_from_id(gear_id)
		if gear:
			roster.gear_stash.append(gear)
	roster.sort_gear_stash()

	roster.battles_fought = int(data.get("battles_fought", 0))
	roster.adventures_completed = int(data.get("adventures_completed", 0))
	roster.last_battle_won = bool(data.get("last_battle_won", false))
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
		var gear = _gear_from_id(equipped[pos_key])
		if gear:
			hero.equipped[int(pos_key)] = gear

	hero.bonus_skills = []
	for skill_id in entry.get("bonus_skills", []):
		hero.bonus_skills.append(_skill_from_id(skill_id))
	return hero

## Unknown ids (e.g. content removed in an update) drop the item.
static func _gear_from_id(gear_id):
	var path = GEAR_PATHS.get(gear_id)
	return load(path).duplicate() if path else null

static func _skill_from_id(skill_id):
	if skill_id == null:
		return null
	var path = SKILL_PATHS.get(skill_id)
	return load(path) if path else null
