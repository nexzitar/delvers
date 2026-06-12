extends Node

## Captures README screenshots: menu, camp, and a battle in progress.

var out_dir := ProjectSettings.globalize_path("res://docs/screenshots")

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _snap(name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])

func _show(path):
	var scene = load(path).instantiate()
	add_child(scene)
	return scene

func _run():
	var menu = _show("res://scenes/menus/menu.tscn")
	await get_tree().create_timer(1.4).timeout
	await _snap("main_menu")
	menu.queue_free()
	await get_tree().process_frame

	var camp = _show("res://scenes/camp/camp.tscn")
	await get_tree().create_timer(0.8).timeout
	await _snap("camp")
	camp.queue_free()
	await get_tree().process_frame

	_show("res://scenes/theater/battle_theater.tscn")
	await get_tree().create_timer(14.0).timeout
	await _snap("battle")

	get_tree().quit()
