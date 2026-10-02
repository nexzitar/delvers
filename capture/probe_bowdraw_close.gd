extends Node3D
## Close-up: goblin archer at full draw, side view (left) and front
## view (right), plus mid-draw side (center). For aim/cant tuning.

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.75, 2.6)
	cam.look_at_from_position(cam.position, Vector3(0, 0.62, 0))
	cam.fov = 38
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)

	var path := "res://resources/models/goblin_archer_m.glb"
	var setups := [
		{"pos": Vector3(-1.5, 0, 0), "yaw": 90.0, "u": 0.9},
		{"pos": Vector3(-0.5, 0, 0), "yaw": 180.0, "u": 0.9},
	]
	for s in setups:
		var config = ActorFactory3D.MODEL_CONFIGS[path].duplicate(true)
		var actor := AnimatedActor.new(load(path), config)
		actor.position = s.pos
		actor.rotation_degrees = Vector3(0, s.yaw, 0)
		add_child(actor)
		actor.pose_shoot(AnimatedActor.DRAW_RELEASE_T * s.u)

	# Wren: the hero archer, garments and all, side + front.
	var equipped := {Equip.Position.MAIN_HAND: load("res://resources/gear/starter_bow.tres")}
	for s in [{"pos": Vector3(0.55, 0, 0), "yaw": 90.0},
			{"pos": Vector3(1.55, 0, 0), "yaw": 180.0}]:
		var wren = ActorFactory3D.build_hero(equipped,
			"res://resources/models/delver_female.glb")
		wren.position = s.pos
		wren.rotation_degrees = Vector3(0, s.yaw, 0)
		add_child(wren)
		wren.pose_shoot(AnimatedActor.DRAW_RELEASE_T * 0.9)

	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/bowdraw_close.png"))
	print("BOWDRAW CLOSE DONE")
	get_tree().quit()
