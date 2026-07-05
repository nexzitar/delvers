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
	PlayerRoster.known_recipes = ["iron_sword", "hunter_bow", "reinforced_shield"]
	PlayerRoster.known_affixes = ["virulent", "frostforged", "guarding"]
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

	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/forge_tab.png" % out_dir)
	get_tree().quit()
