extends Node

## Regenerates the README screenshots into docs/screenshots/ from the
## live game: menu, restored camp, both dungeon theaters, and the
## camp interface tabs.

var out := ProjectSettings.globalize_path("res://docs/screenshots")

func _ready():
	PlayerRoster.autosave = false
	_run()

func _staged_roster():
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.battles_fought = 26
	PlayerRoster.adventures_completed = 2
	PlayerRoster.purchased_unlocks = []
	PlayerRoster.check_milestones()
	PlayerRoster.known_recipes = ["iron_sword", "hunter_bow", "reinforced_shield",
		"iron_helm", "leather_hood", "silk_hood", "chitin_shield", "chitin_armor",
		"studded_belt", "iron_greaves"]
	PlayerRoster.known_affixes = ["virulent", "guarding", "frostforged"]
	PlayerRoster.known_tactics = ["nearest", "lowest", "priority", "spread", "guard", "protect"]
	PlayerRoster.known_engineering = ["doctrine_capacity_2"]
	PlayerRoster.known_lore = ["expedition_log_1", "expedition_log_2", "expedition_nest_1"]
	PlayerRoster.unlocked_dungeons = ["darkwood", "spider_nest"]
	PlayerRoster.dungeon_progress = {"darkwood": 2}
	PlayerRoster.seen_enemies = ["green_slime", "goblin_archer", "goblin_warrior",
		"venomous_spider", "slime_king", "nest_spiderling", "web_weaver",
		"chitin_crawler", "brood_tender"]
	PlayerRoster.material_stash = {"iron_scrap": 12, "gel": 9, "leather": 6,
		"ash_wood": 5, "bow_string": 4, "poison_sac": 3, "silk_thread": 6,
		"chitin_plate": 4, "corrosion_core": 2, "royal_jelly": 1}
	PlayerRoster.heroes[0].mastery = {
		"sword": {"xp": 90, "best_xp": 90}, "shield": {"xp": 48, "best_xp": 48}}
	PlayerRoster.heroes[0].equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 6, 1, "virulent"),
		Equip.Position.OFF_HAND: LootTable.materialize("chitin_shield", 14, 1),
		Equip.Position.HEAD: LootTable.materialize("starter_helmet", 6, 1),
		Equip.Position.CHEST: LootTable.materialize("chitin_armor", 14, 1),
		Equip.Position.SHOULDER: LootTable.materialize("wardens_pauldrons", 6, 1),
		Equip.Position.WAIST: LootTable.materialize("studded_belt", 5, 1),
		Equip.Position.LEGS: LootTable.materialize("iron_greaves", 6, 1),
	}
	PlayerRoster._sync_role(PlayerRoster.heroes[0])
	if PlayerRoster.heroes.size() > 1:
		PlayerRoster.heroes[1].mastery = {
			"bow": {"xp": 48, "best_xp": 48},
			"restoration": {"xp": 24, "best_xp": 30}}
		PlayerRoster.equip_bonus_skill(1, load("res://resources/skills/heal.tres"), 1)
	PlayerRoster.heroes[0].custom_tree = [
		{"when": [{"cond": "healer_threatened"}], "target": "healer_attacker"},
		{"when": [{"cond": "enemy_count_gte", "n": 4}], "cast": "thunderclap"},
		{"when": [], "target": "least_threat"},
	]

func _run():
	_staged_roster()

	# Main menu (the ruined clearing behind the sign).
	PlayerRoster.adventures_completed = 0
	PlayerRoster.battles_fought = 0
	var menu = load("res://scenes/menus/menu.tscn").instantiate()
	add_child(menu)
	get_tree().current_scene = menu
	await get_tree().create_timer(1.2).timeout
	await _snap("main_menu")
	menu.queue_free()
	await _settle()

	# The camp, restored: banner, anvil, dummy, two delvers.
	_staged_roster()
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	get_tree().current_scene = camp
	await get_tree().create_timer(1.0).timeout
	await _snap("camp")

	# Interface tabs.
	var loadout = camp.loadout
	loadout.open(0)
	await _settle()
	await _snap("loadout_open")
	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 2
	loadout._forge_selected = "iron_sword"
	loadout._forge_affix_choice["iron_sword"] = "virulent"
	loadout._fill_forge()
	await _settle()
	await _snap("forge")
	loadout.hide_tooltip()
	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 3
	await _settle()
	await _snap("library")
	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 4
	loadout._fill_tactics()
	await _settle()
	await _snap("tactics")
	loadout.close()
	await _settle()
	camp._on_guild_pressed()
	await _settle()
	await _snap("guild")
	camp.queue_free()
	await _settle()

	# The Darkwood, mid-brawl.
	PlayerRoster.start_delve("darkwood", 1)
	PlayerRoster.delve_room = 6
	var theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(theater)
	get_tree().current_scene = theater
	await get_tree().create_timer(7.0).timeout
	await _snap("battle")
	theater.queue_free()
	await _settle()

	# The Nest, swarming.
	PlayerRoster.start_delve("spider_nest", 1)
	PlayerRoster.delve_room = 5
	var nest = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(nest)
	get_tree().current_scene = nest
	await get_tree().create_timer(9.0).timeout
	await _snap("battle_nest")

	print("README SHOTS DONE")
	get_tree().quit()

func _settle():
	await get_tree().process_frame
	await get_tree().process_frame

func _snap(file_name: String):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, file_name])
