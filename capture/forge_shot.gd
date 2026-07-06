extends Node

## Opens the loadout on the Forge tab with a stocked material shelf.

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.material_stash = {
		"gel": 5, "iron_scrap": 3, "ash_wood": 2, "bow_string": 1,
		"poison_sac": 2, "royal_jelly": 1,
	}
	PlayerRoster.known_recipes = ["iron_sword", "hunter_bow", "reinforced_shield", "iron_helm", "leather_hood", "silk_hood", "chitin_shield", "chitin_armor"]
	PlayerRoster.known_affixes = ["virulent", "frostforged", "guarding"]
	PlayerRoster.known_lore = ["expedition_log_1", "expedition_log_2"]
	PlayerRoster.material_stash["corrosion_core"] = 2

	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame

	var loadout = camp.loadout
	loadout.open(0)
	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 2
	await get_tree().create_timer(0.4).timeout

	# Select the sword with Virulent chosen: pinned preview + effects.
	loadout._forge_affix_choice["iron_sword"] = "virulent"
	loadout._forge_selected = "iron_sword"
	loadout._fill_forge()
	await get_tree().create_timer(0.2).timeout

	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/forge_tab.png" % out_dir)

	loadout.hide_tooltip()
	PlayerRoster.seen_enemies = ["green_slime", "goblin_archer",
		"goblin_warrior", "venomous_spider", "web_weaver"]
	PlayerRoster.enemy_priority = ["venomous_spider", "web_weaver"]
	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 4
	loadout._fill_tactics()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	img = get_viewport().get_texture().get_image()
	img.save_png("%s/tactics_tab.png" % out_dir)

	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 3
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	img = get_viewport().get_texture().get_image()
	img.save_png("%s/library_tab.png" % out_dir)
	get_tree().quit()
