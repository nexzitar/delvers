extends Node3D

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")

## The imported delver next to his procedural ancestor: idle, walk,
## swing, cast, death - the promotion audition.

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 4.2)
	cam.look_at_from_position(cam.position, Vector3(0, 0.55, 0))
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.19, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.65, 0.7, 0.65)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.3, 0.22)
	ground.material_override = mat
	add_child(ground)

	var out = ProjectSettings.globalize_path("res://capture/proto3d/renders")
	var poses = [["idle", 3.0], ["swing", 0.15], ["swing", 0.45], ["swing", 0.55], ["swing", 0.8], ["sit", 2.0]]
	var counter := 0
	for pose in poses:
		for child in get_children():
			if child.name.begins_with("actor_"):
				child.free()
		var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
		config.merge({"sword": true, "shield": true}, true)
		var imported = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
		imported.name = "actor_imported"
		imported.position = Vector3(-0.7, 0, 0)
		add_child(imported)
		var rig = DelverRig.new({"sword": true, "shield": true})
		rig.name = "actor_rig"
		rig.position = Vector3(0.7, 0, 0)
		add_child(rig)
		match pose[0]:
			"idle":
				imported.pose_idle(pose[1])
				rig.pose_idle(pose[1])
			"swing":
				imported.pose_swing(pose[1])
				rig.pose_swing(pose[1])
			"sit":
				imported.pose_sit(pose[1])
				rig.pose_sit(pose[1])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img = get_viewport().get_texture().get_image()
		img.save_png("%s/model_%d_%s.png" % [out, counter, pose[0]])
		counter += 1
	print("MODEL SHOTS DONE")
	get_tree().quit()
