extends Node

## Steps proto3d_anim's timeline frame by frame and assembles filmstrip
## contact sheets (walk cycle, sword swing) plus key full-res frames.

const DelverRig = preload("res://capture/proto3d/delver_rig.gd")

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

var scene: Node3D

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	scene = load("res://capture/proto3d/proto3d_anim.tscn").instantiate()
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

func _strip(images: Array, cols: int, cell_w: int, file_name: String):
	var cell_h := int(cell_w * images[0].get_height() / float(images[0].get_width()))
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(cols * cell_w, rows * cell_h, false, Image.FORMAT_RGB8)
	for i in images.size():
		var img: Image = images[i]
		img.resize(cell_w, cell_h, Image.INTERPOLATE_LANCZOS)
		var cell := Vector2i((i % cols) * cell_w, (i / cols) * cell_h)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), cell)
	sheet.save_png("%s/%s.png" % [out_dir, file_name])

func _run():
	# Let shadows and exposure settle before grabbing frames.
	await get_tree().create_timer(0.3).timeout

	# Walk cycle: one full stride pair, sampled mid-path.
	var stride: float = TAU / scene.STRIDE_RATE
	var walk_frames := []
	for i in 8:
		walk_frames.append(await _grab(0.35 + stride * i / 8.0))
	_strip(walk_frames, 4, 640, "proto3d_walk_strip")

	# Sword swing: windup through recovery.
	var swing_start: float = scene.walk_t + scene.SETTLE_T
	var swing_frames := []
	for i in 10:
		swing_frames.append(await _grab(swing_start + DelverRig.SWING_T * i / 10.0))
	_strip(swing_frames, 5, 640, "proto3d_swing_strip")

	# Full-res carry grip during the idle settle.
	var idle := await _grab(scene.walk_t + 0.12)
	idle.save_png("%s/proto3d_idle.png" % out_dir)

	# Full-res key poses: windup peak, strike contact, follow-through.
	for key in [[0.36, "windup"], [0.5, "strike"], [0.7, "follow"]]:
		var img := await _grab(swing_start + DelverRig.SWING_T * key[0])
		img.save_png("%s/proto3d_swing_%s.png" % [out_dir, key[1]])

	get_tree().quit()
