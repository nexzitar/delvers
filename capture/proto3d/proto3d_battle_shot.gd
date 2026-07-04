extends Node

## Captures battle stills at a few beats, and optionally the full loop
## as frames for GIF assembly (pass --gif via OS.get_cmdline_user_args).

const FPS := 20

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

var scene: Node3D

func _ready():
	scene = load("res://capture/proto3d/proto3d_battle.tscn").instantiate()
	scene.auto_play = false
	add_child(scene)
	_run()

func _grab(t: float) -> Image:
	scene.apply_time(t)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _run():
	await get_tree().create_timer(0.3).timeout

	for key in [[0.45, "a"], [1.25, "b"], [2.2, "c"]]:
		var img := await _grab(key[0])
		img.save_png("%s/proto3d_battle_%s.png" % [out_dir, key[1]])

	if OS.get_cmdline_user_args().has("--gif"):
		var dir := "%s/battle_frames" % out_dir
		DirAccess.make_dir_recursive_absolute(dir)
		var count := ceili(scene.LOOP * FPS)
		for i in count:
			var img := await _grab(i / float(FPS))
			img.save_png("%s/frame_%04d.png" % [dir, i])
		print("Saved %d battle frames" % count)

	get_tree().quit()
