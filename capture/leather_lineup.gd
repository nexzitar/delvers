extends Node3D

## The derived leather set, four color schemes: every piece grown
## from the delver's own body.

const SCHEMES = [
	{"name": "tanned", "primary": Color(0.42, 0.3, 0.18), "secondary": Color(0.3, 0.2, 0.12), "trim": Color(0.58, 0.46, 0.3), "flatten": 0.9},
	{"name": "black", "primary": Color(0.13, 0.12, 0.12), "secondary": Color(0.08, 0.08, 0.09), "trim": Color(0.4, 0.38, 0.36), "flatten": 0.9},
	{"name": "forest", "primary": Color(0.2, 0.3, 0.16), "secondary": Color(0.12, 0.18, 0.1), "trim": Color(0.5, 0.45, 0.28), "flatten": 0.9},
	{"name": "oxblood", "primary": Color(0.36, 0.14, 0.12), "secondary": Color(0.2, 0.09, 0.08), "trim": Color(0.6, 0.5, 0.34), "flatten": 0.9},
]

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.3, 1.4, 4.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0.58, 0))
	cam.fov = 42
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 145, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.65, 0.72, 0.9)
	add_child(rim)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.11, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.52, 0.54, 0.52)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.25, 0.19)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	for i in SCHEMES.size():
		var scheme = SCHEMES[i]
		var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
		var actor = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
		actor.position = Vector3(-1.5 + i * 1.0, 0, 0)
		actor.rotation.y = 0.15 - i * 0.1
		add_child(actor)
		for piece_id in ["derived_leathers",
				"derived_set_sleeve_l", "derived_set_sleeve_r"]:
			actor._mount_worn_model(piece_id)
		actor._mount_worn_model("iron_shod_boots")
		# Re-dye everything in this delver's scheme.
		for fit_key in actor.worn_mounts:
			if not fit_key.begins_with("derived"):
				continue
			for piece in actor.worn_mounts[fit_key]:
				actor._recolor(piece, scheme)
		actor.pose_idle(1.0 + i * 1.7)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/leather_lineup.png"))
	print("LINEUP DONE")
	get_tree().quit()
