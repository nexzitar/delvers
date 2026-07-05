extends Node

## The Restoration: Wren by the fire with the arrival line, then the
## Guild panel with the milestone beat and purchasable unlocks.

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.adventures_completed = 1
	PlayerRoster.battles_fought = 12
	PlayerRoster.material_stash = {
		"gel": 6, "ash_wood": 4, "corrosion_core": 1,
		"iron_scrap": 6, "leather": 2,
	}
	PlayerRoster.check_milestones()

	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	get_tree().current_scene = camp
	await get_tree().create_timer(0.6).timeout
	await _snap("guild_arrival")

	camp._on_guild_pressed()
	await get_tree().create_timer(0.3).timeout
	await _snap("guild_panel")
	get_tree().quit()

func _snap(file_name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])
