extends Node3D

## Close-up render of the weapon grips: idle and mid-swing, camera
## at hand height. Iterating socket placement lives or dies here.

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.85, 1.7)
	cam.look_at_from_position(cam.position, Vector3(0, 0.62, 0))
	cam.fov = 35
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

	for i in 2:
		var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
		config.merge({"sword": true, "shield": true,
			"main_gear": "starter_sword", "off_gear": "starter_shield"}, true)
		var actor = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
		actor.position = Vector3(-0.45 + i * 0.9, 0, 0)
		actor.rotation.y = -0.5 + i * 0.6
		add_child(actor)
		if i == 0:
			actor.pose_idle(0.0)
		else:
			actor.pose_swing(0.55)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/hands_shot.png"))
	print("HANDS DONE")
	get_tree().quit()
