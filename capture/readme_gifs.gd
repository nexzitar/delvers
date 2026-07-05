extends Node

## Captures real gameplay frame sequences for the README GIFs.
## Default: main menu -> camera-glide transition -> camp.
## With `-- --battle`: a mid-delve fight in the 3D theater.

const FRAME_DIR := "res://capture/proto3d/renders/gif_frames"
const EVERY_NTH := 2
const WIDTH := 960

var _grab := false
var _rendered := 0
var _saved := 0
var _dir: String

func _ready():
	_dir = ProjectSettings.globalize_path(FRAME_DIR)
	DirAccess.make_dir_recursive_absolute(_dir)
	RenderingServer.frame_post_draw.connect(_on_frame)
	if OS.get_cmdline_user_args().has("--battle"):
		_battle_run()
	else:
		_menu_run()

func _menu_run():
	# The scene must be a direct child of root to be current_scene
	# (SceneFlow frees current_scene on transition).
	await get_tree().process_frame
	var menu = load("res://scenes/menus/menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().create_timer(1.6).timeout
	_grab = true
	await get_tree().create_timer(1.4).timeout
	menu._on_enter_pressed()
	await get_tree().create_timer(6.4).timeout
	_grab = false
	print("saved %d frames" % _saved)
	get_tree().quit()

func _battle_run():
	PlayerRoster.start_delve()
	PlayerRoster.delve_room = 3
	await get_tree().process_frame
	var theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	get_tree().root.add_child(theater)
	get_tree().current_scene = theater
	await get_tree().create_timer(1.2).timeout
	_grab = true
	await get_tree().create_timer(13.0).timeout
	_grab = false
	print("saved %d frames" % _saved)
	get_tree().quit()

func _on_frame():
	if not _grab:
		return
	_rendered += 1
	if _rendered % EVERY_NTH != 0:
		return
	var img = get_viewport().get_texture().get_image()
	var height = int(WIDTH * img.get_height() / float(img.get_width()))
	img.resize(WIDTH, height, Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/frame_%04d.png" % [_dir, _saved])
	_saved += 1
