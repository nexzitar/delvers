extends Node

## Salvaging: gear breaks down into materials, and studying an unknown
## enchantment teaches it. Boss trophies always carry an affix; normal
## enemies drop no finished gear at all.

func _ready():
	var roster = load("res://scripts/game/player_roster.gd").new()
	roster.autosave = false
	roster._build_heroes()
	roster._build_stash()

	# A crafted sword gives back about half its bill.
	roster.known_recipes = ["iron_sword"]
	roster.material_stash = {"iron_scrap": 3, "gel": 2}
	var sword = roster.craft(load("res://resources/recipes/iron_sword.tres"))
	assert(roster.material_stash.is_empty(), "bill consumed")
	var yields = roster.salvage(sword)
	assert(not roster.gear_stash.has(sword), "salvaged item is gone")
	assert(roster.material_stash.get("iron_scrap", 0) == 1, "half the iron back")
	assert(roster.material_stash.get("gel", 0) == 1, "half the gel back")
	assert(not yields.has("__learned"), "nothing to study on a plain blade")

	# A rare trophy with an unknown affix teaches it when studied.
	var trophy = LootTable.materialize("fast_dagger", 10, ItemQuality.Tier.RARE, "frostforged")
	roster.gear_stash.append(trophy)
	assert(not roster.known_affixes.has("frostforged"), "not yet known")
	var studied = roster.salvage(trophy)
	assert(studied.get("__learned", "") == "frostforged", "enchantment studied")
	assert(roster.known_affixes.has("frostforged"), "affix learned forever")
	assert(roster.material_stash.get("corrosion_core", 0) >= 1, "rare salvage bonus")
	assert(roster.material_stash.get("iron_scrap", 0) >= 2, "weapon scrap")

	# Already-known affixes just yield materials.
	var second = LootTable.materialize("fast_dagger", 10, ItemQuality.Tier.RARE, "frostforged")
	roster.gear_stash.append(second)
	assert(not roster.salvage(second).has("__learned"), "no double study")

	# Not in the stash: no-op.
	assert(roster.salvage(second).is_empty(), "gone is gone")

	# Boss trophies always carry an affix; normals never drop gear.
	var darkwood = load("res://resources/dungeons/darkwood.tres")
	var king = load("res://resources/enemies/slime_king.tres")
	for i in 5:
		var bounty = LootTable.roll_enemy_drops([king], 10, [], [], [], darkwood, [])
		assert(bounty.gear.size() == 1, "boss drops a trophy")
		assert(bounty.gear[0].affix_id != "", "the trophy is enchanted")
	var slime = load("res://resources/enemies/green_slime.tres")
	var warrior = load("res://resources/enemies/goblin_warrior.tres")
	for i in 100:
		assert(LootTable.roll_enemy_drops([slime, warrior], 3, [], [], [], darkwood, []).gear.is_empty(),
			"normals drop no finished gear")

	roster.free()
	print("PASS salvage")
	get_tree().quit()
