extends Node3D
## The goblin family: same proportions, same equipment language,
## different silhouettes - a civilization, not a bestiary page.
func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.0, 3.6)
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
	var family := ["goblin_scout_m", "goblin_archer_m", "goblin_warrior_m",
		"goblin_shaman_m", "goblin_chief_m"]
	for i in family.size():
		var path = "res://resources/models/%s.glb" % family[i]
		var config = ActorFactory3D.MODEL_CONFIGS[path].duplicate(true)
		var actor = AnimatedActor.new(load(path), config)
		actor.position = Vector3(-1.7 + i * 0.85, 0, 0)
		actor.rotation.y = 0.2 - i * 0.1
		add_child(actor)
		if i == 2:
			actor.pose_swing(0.55)
		else:
			actor.pose_idle(0.4 + i * 1.3)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/goblin_shot.png"))
	print("GOBLIN DONE")
	get_tree().quit()
