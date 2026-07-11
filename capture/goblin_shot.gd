extends Node3D
## The modeled goblin warrior: idle, mid-swing, dying.
func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.9, 2.8)
	cam.look_at_from_position(cam.position, Vector3(0, 0.55, 0))
	cam.fov = 38
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	for i in 3:
		var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/goblin_warrior_m.glb"].duplicate(true)
		var actor = AnimatedActor.new(load("res://resources/models/goblin_warrior_m.glb"), config)
		actor.position = Vector3(-0.9 + i * 0.9, 0, 0)
		actor.rotation.y = -0.4 + i * 0.4
		add_child(actor)
		if i == 0:
			actor.pose_idle(0.5)
		elif i == 1:
			actor.pose_swing(0.55)
		else:
			actor.pose_death(0.8)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/goblin_shot.png"))
	print("GOBLIN DONE")
	get_tree().quit()
