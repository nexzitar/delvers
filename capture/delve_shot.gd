extends Node

## Runs a real continuous Darkwood delve and captures the replay at
## three beats: setting out, the first pull, deep in the run.

const SHOTS := [7.0, 22.0, 45.0]

func _ready():
	PlayerRoster.autosave = false
	PlayerRoster.start_delve("darkwood", 1)
	var theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(theater)
	var clock := 0.0
	for i in SHOTS.size():
		while clock < SHOTS[i]:
			await get_tree().process_frame
			clock += get_process_delta_time()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(
				"res://capture/proto3d/renders/delve_shot_%d.png" % i))
		print("DELVE SHOT %d" % i)
	print("DELVE SHOTS DONE")
	get_tree().quit()
