extends Node3D

## Calibration: three shield orientations on three arms; read which
## faces outward. Left: (0,0,0). Mid: (0,90,0). Right: (90,0,0).

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 3.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0.6, 0))
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.14, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var rotations = [Vector3(0, 0, 0), Vector3(0, 90, 0), Vector3(90, 0, 0)]
	for i in 3:
		var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
		var actor = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
		actor.position = Vector3(-1.1 + i * 1.1, 0, 0)
		add_child(actor)
		actor.pose_idle(2.0)
		var mount := BoneAttachment3D.new()
		actor._skeleton.add_child(mount)
		mount.bone_name = "L_Forearm"
		var shield = load("res://resources/models/gear_shield.glb").instantiate()
		shield.position = Vector3(0, 0.12, -0.06)
		shield.rotation_degrees = rotations[i]
		shield.scale = Vector3.ONE * 0.4
		mount.add_child(shield)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/calib.png"))
	print("CALIB DONE")
	get_tree().quit()
