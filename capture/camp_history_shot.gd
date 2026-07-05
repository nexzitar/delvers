extends Node

## The camp's environmental storytelling: the ruined clearing of a
## fresh guild, then the same clearing after real progress.

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	PlayerRoster.autosave = false
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()

	var stage = CampfireStage3D.new()
	add_child(stage)
	await get_tree().create_timer(0.4).timeout
	await _snap("camp_ruined")
	stage.queue_free()

	PlayerRoster.adventures_completed = 1
	PlayerRoster.known_recipes = ["iron_sword", "hunter_bow", "reinforced_shield"]
	PlayerRoster.battles_fought = 20
	var rebuilt = CampfireStage3D.new()
	add_child(rebuilt)
	await get_tree().create_timer(0.4).timeout
	await _snap("camp_restored")
	get_tree().quit()

func _snap(file_name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])
