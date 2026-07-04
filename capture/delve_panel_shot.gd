extends Node

## Renders the delve reward panels (room-cleared and final summary)
## over a battle backdrop for visual verification.

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	# Battle in a pillared room as the backdrop.
	PlayerRoster.start_delve()
	PlayerRoster.delve_room = 4
	var theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	theater.forced_arena_path = "res://resources/arenas/pillared_hall.tres"
	add_child(theater)
	_run(theater)

func _snap(file_name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])

func _run(theater):
	await get_tree().create_timer(4.0).timeout
	await _snap("delve_room_battle")

	PlayerRoster.delve_loot = LootTable.roll_room_loot(3) + LootTable.roll_room_loot(4)
	theater._show_room_cleared(4, PlayerRoster.delve_loot.slice(0, 2))
	await get_tree().create_timer(0.5).timeout
	await _snap("delve_room_cleared")

	get_tree().quit()
