extends Node

## Crafting: materials are consumed, knowledge is permanent, and the
## forge turns both into intentional equipment.

func _ready():
	# Registries resolve, ids match their files.
	for material_id in RosterSave.MATERIAL_PATHS:
		var material = load(RosterSave.MATERIAL_PATHS[material_id])
		assert(material.material_id == material_id, "material id matches")
		assert(material.icon != null, "material has an icon")
	for recipe_id in RosterSave.RECIPE_PATHS:
		var recipe = load(RosterSave.RECIPE_PATHS[recipe_id])
		assert(recipe.recipe_id == recipe_id, "recipe id matches")
		assert(RosterSave.GEAR_PATHS.has(recipe.result_gear_id), "result craftable")
		for material_id in recipe.costs:
			assert(RosterSave.MATERIAL_PATHS.has(material_id), "costs exist")

	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()

	# Iron Sword is starting knowledge; Hunter Bow must be found first.
	var sword_recipe = load("res://resources/recipes/iron_sword.tres")
	var bow_recipe = load("res://resources/recipes/hunter_bow.tres")
	assert(roster.known_recipes.has("iron_sword"), "starting knowledge")
	assert(not roster.can_craft(bow_recipe), "unknown recipes can't craft")
	assert(roster.craft(bow_recipe) == null, "craft rejects unknown")

	# Not enough materials -> no craft; enough -> forged into the stash.
	assert(not roster.can_craft(sword_recipe), "bare shelves can't craft")
	roster.material_stash = {"iron_scrap": 4, "gel": 2}
	assert(roster.can_craft(sword_recipe), "materials suffice")
	var before = roster.gear_stash.size()
	var forged = roster.craft(sword_recipe)
	assert(forged != null, "craft succeeds")
	assert(forged.gear_id == "starter_sword", "crafted the right base")
	assert(forged.item_level == 4, "crafted at recipe level")
	assert(forged.quality == ItemQuality.Tier.UNCOMMON, "crafted quality")
	assert(roster.gear_stash.size() == before + 1, "forged into stash")
	assert(roster.material_stash.get("iron_scrap", 0) == 1, "iron consumed")
	assert(not roster.material_stash.has("gel"), "gel fully consumed")
	assert(not roster.can_craft(sword_recipe), "shelves empty again")

	# Banking a delve merges materials and learns recipes exactly once.
	roster.start_delve()
	roster.delve_materials = {"gel": 3, "ash_wood": 2}
	roster.delve_recipes = ["hunter_bow", "hunter_bow"]
	roster.bank_delve_loot()
	assert(roster.material_stash.get("gel", 0) == 3, "materials banked")
	assert(roster.known_recipes.count("hunter_bow") == 1, "knowledge learned once")
	assert(roster.can_craft(bow_recipe) == false, "still short on bow parts")
	roster.material_stash["bow_string"] = 2
	roster.material_stash["iron_scrap"] = 1
	assert(roster.can_craft(bow_recipe), "bow now craftable")

	# Materials and knowledge persist through a save round trip.
	var path := "user://test_crafting_save.json"
	RosterSave.save(roster, path)
	var restored = load("res://scripts/game/player_roster.gd").new()
	assert(RosterSave.load_into(restored, path), "save loads")
	assert(restored.material_stash.get("gel", 0) == 3, "materials persist")
	assert(restored.known_recipes.has("hunter_bow"), "knowledge persists")
	assert(restored.known_recipes.has("iron_sword"), "old knowledge kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	roster.free()
	restored.free()
	print("PASS crafting")
	get_tree().quit()
