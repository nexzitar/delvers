extends Node

## Snapshots the live 3D battle theater (real sim + replay) at a few
## points into capture/proto3d/renders/ for visual verification.

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	PlayerRoster.start_delve()
	PlayerRoster.delve_room = 5
	var scene = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(scene)
	_run()

func _snap(file_name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])

func _run():
	await get_tree().create_timer(2.0).timeout
	await _snap("battle3d_early")
	await get_tree().create_timer(4.0).timeout
	await _snap("battle3d_mid")
	await get_tree().create_timer(6.0).timeout
	await _snap("battle3d_late")
	get_tree().quit()
