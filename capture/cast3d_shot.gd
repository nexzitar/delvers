extends Node

## Renders the cast as transparent full-body 3D portraits for the
## README gallery.

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")
const SlimeRig = preload("res://scripts/theater3d/slime_rig.gd")

var out_dir := ProjectSettings.globalize_path("res://docs/screenshots")

func _ready():
	_run()

func _run():
	var sword = load("res://resources/gear/starter_sword.tres")
	var shield = load("res://resources/gear/starter_shield.tres")
	var helmet = load("res://resources/gear/starter_helmet.tres")
	var bow = load("res://resources/gear/starter_bow.tres")

	await _shoot(ActorFactory3D.build_hero({
		Equip.Position.MAIN_HAND: sword,
		Equip.Position.OFF_HAND: shield,
		Equip.Position.HEAD: helmet,
	}), "cast_delver", 1.35)

	await _shoot(ActorFactory3D.build_hero({
		Equip.Position.MAIN_HAND: bow,
	}), "cast_delver_archer", 1.35)

	await _shoot(ActorFactory3D.build_enemy(
		load("res://resources/enemies/goblin_archer.tres")
	), "cast_goblin_archer", 1.2)

	await _shoot(ActorFactory3D.build_enemy(
		load("res://resources/enemies/green_slime.tres")
	), "cast_green_slime", 0.85)

	await _shoot(ActorFactory3D.build_enemy(
		load("res://resources/enemies/slime_king.tres")
	), "cast_slime_king", 1.6)

	get_tree().quit()

func _shoot(rig: Node3D, file_name: String, frame_height: float):
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 640)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -28, 0)
	key_light.light_energy = 1.2
	vp.add_child(key_light)

	var camera := Camera3D.new()
	camera.fov = 30
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.85
	camera.environment = env
	vp.add_child(camera)

	vp.add_child(rig)
	rig.rotation_degrees = Vector3(0, 22, 0)
	var mid = frame_height * 0.5
	camera.position = Vector3(0, mid + 0.1, frame_height * 2.3)
	camera.look_at(Vector3(0, mid, 0))

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])
	vp.queue_free()
