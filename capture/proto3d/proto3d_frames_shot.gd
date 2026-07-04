extends Node

## Renders the full proto3d_anim loop as a numbered frame sequence,
## ready for ffmpeg assembly into a GIF/MP4.

const FPS := 20

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders/frames")

var scene: Node3D

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://capture/proto3d/proto3d_anim.tscn").instantiate()
	scene.auto_play = false
	add_child(scene)
	_run()

func _run():
	# Let shadows and exposure settle before the first frame.
	await get_tree().create_timer(0.3).timeout
	var frame_count := ceili(scene.cycle_len * FPS)
	for i in frame_count:
		scene.apply_time(i / float(FPS))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img = get_viewport().get_texture().get_image()
		img.save_png("%s/frame_%04d.png" % [out_dir, i])
	print("Saved %d frames to %s" % [frame_count, out_dir])
	get_tree().quit()
