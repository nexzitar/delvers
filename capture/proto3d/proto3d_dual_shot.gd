extends Node3D

## Renders a dual-wielding delver at carry, off-hand strike contact,
## and main-hand strike contact, for visual verification.

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_world()

	var carry = DelverRig.new({"sword": true, "off_sword": true})
	carry.position = Vector3(-1.3, 0, 0)
	carry.rotation_degrees = Vector3(0, 15, 0)
	add_child(carry)
	carry.pose_idle(0.0)

	var off_strike = DelverRig.new({"sword": true, "off_sword": true})
	off_strike.position = Vector3(0, 0, 0)
	off_strike.rotation_degrees = Vector3(0, 35, 0)
	add_child(off_strike)
	off_strike.pose_swing_off(0.5 * DelverRig.SWING_T)

	var main_strike = DelverRig.new({"sword": true, "off_sword": true})
	main_strike.position = Vector3(1.3, 0, 0)
	main_strike.rotation_degrees = Vector3(0, 35, 0)
	add_child(main_strike)
	main_strike.pose_swing(0.5 * DelverRig.SWING_T)

	_run()

func _run():
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/proto3d_dual.png" % out_dir)
	get_tree().quit()

func _setup_world():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("23242c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c0d6")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("55584a")
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var camera := Camera3D.new()
	camera.fov = 32
	camera.position = Vector3(0, 1.5, 3.8)
	add_child(camera)
	camera.look_at(Vector3(0, 0.55, 0))
