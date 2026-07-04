extends Node3D

## Renders the 3D prototype: a cast lineup (melee, archer, base body)
## and a floating gear rack, saved as PNGs into capture/proto3d/renders/.

const Builder = preload("res://scripts/theater3d/delver_builder.gd")

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

var camera: Camera3D
var rack: Node3D

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_world()
	_setup_cast()
	_setup_gear_rack()
	_run()

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

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.35
	add_child(fill)

	# Ground plane shared by both shots.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("55584a")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(0, 0, -6)
	add_child(ground)

	camera = Camera3D.new()
	camera.fov = 32
	add_child(camera)

func _setup_cast():
	var melee := Builder.build_delver({"sword": true, "shield": true, "helmet": true})
	melee.position = Vector3(0, 0, 0)
	add_child(melee)

	var archer := Builder.build_delver({"bow": true})
	archer.position = Vector3(1.0, 0, 0)
	archer.rotation_degrees = Vector3(0, -14, 0)
	add_child(archer)

	var base := Builder.build_delver()
	base.position = Vector3(-1.0, 0, 0)
	base.rotation_degrees = Vector3(0, 18, 0)
	add_child(base)

func _setup_gear_rack():
	rack = Node3D.new()
	rack.position = Vector3(0, 0, -12)
	add_child(rack)

	# Item, vertical offset so its visual center sits on the row line.
	var items := [
		[Builder.build_sword(), -0.22],
		[Builder.build_axe(), 0.0],
		[Builder.build_dagger(), -0.12],
		[Builder.build_bow(), 0.0],
		[Builder.build_shield(), 0.0],
		[Builder.build_helmet(), -0.06],
	]
	for i in items.size():
		var item: Node3D = items[i][0]
		var lift: float = items[i][1]
		var col := i % 3
		var row := i / 3
		item.position = Vector3(-0.85 + col * 0.85, 1.0 - row * 0.65 + lift, 0)
		item.rotation_degrees = Vector3(0, 25, 0)
		if i == 4:
			# Shield faces the camera.
			item.rotation_degrees = Vector3(75, 15, 0)
		if i == 5:
			# Helmet tips back a little so the nose guard shows.
			item.rotation_degrees = Vector3(-14, 20, 0)
		rack.add_child(item)

func _snap(file_name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])

func _run():
	rack.visible = false
	camera.position = Vector3(0, 1.35, 3.4)
	camera.look_at(Vector3(0, 0.55, 0))
	await get_tree().create_timer(0.4).timeout
	await _snap("proto3d_cast")

	rack.visible = true
	camera.position = Vector3(0, 2.1, -9.0)
	camera.look_at(Vector3(0, 0.6, -12))
	await get_tree().process_frame
	await get_tree().process_frame
	await _snap("proto3d_gear")

	get_tree().quit()
