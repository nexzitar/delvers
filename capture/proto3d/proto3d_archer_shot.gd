extends Node

## Captures the archer shoot cycle: a filmstrip plus full-res key frames.

const DelverRig = preload("res://capture/proto3d/delver_rig.gd")

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

var scene: Node3D

func _ready():
	scene = load("res://capture/proto3d/proto3d_archer.tscn").instantiate()
	scene.auto_play = false
	add_child(scene)
	_run()

func _grab(t: float) -> Image:
	scene.apply_time(t)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

func _run():
	await get_tree().create_timer(0.3).timeout

	var start: float = scene.IDLE_T
	var frames := []
	for i in 10:
		frames.append(await _grab(start + DelverRig.SHOOT_T * i / 10.0))
	var cell_h := int(640 * frames[0].get_height() / float(frames[0].get_width()))
	var sheet := Image.create(5 * 640, 2 * cell_h, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var img: Image = frames[i]
		img.resize(640, cell_h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i((i % 5) * 640, (i / 5) * cell_h))
	sheet.save_png("%s/proto3d_shoot_strip.png" % out_dir)

	for key in [[0.6, "draw"], [0.66, "loose"], [0.8, "stuck"]]:
		var img := await _grab(start + DelverRig.SHOOT_T * key[0])
		img.save_png("%s/proto3d_shoot_%s.png" % [out_dir, key[1]])

	get_tree().quit()
