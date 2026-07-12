extends Node3D
## Bow draw probe: delver rig (top row) and goblin archer (bottom
## row) at nock / mid-draw / full draw / release, seen from the side
## so the string flex reads. Renders one strip per run.

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.05, 5.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0.8, 0))
	cam.fov = 40
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

	# Side view: archers face +X so the drawn string is silhouetted.
	var phases := [0.35, 0.62, 0.9, 1.05]
	for i in phases.size():
		var rig := DelverRig.new({"bow": true})
		rig.position = Vector3(-2.7 + i * 1.8, 0.9, 0)
		rig.rotation_degrees = Vector3(0, 90, 0)
		add_child(rig)
		rig.pose_shoot(DelverRig.SHOOT_T * 0.62 * phases[i])

		var path := "res://resources/models/goblin_archer_m.glb"
		var config = ActorFactory3D.MODEL_CONFIGS[path].duplicate(true)
		var actor := AnimatedActor.new(load(path), config)
		actor.position = Vector3(-2.7 + i * 1.8, -0.5, 0)
		actor.rotation_degrees = Vector3(0, 90, 0)
		add_child(actor)
		actor.pose_shoot(AnimatedActor.DRAW_RELEASE_T * phases[i])

	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/bowdraw_probe.png"))
	print("BOWDRAW PROBE DONE")
	get_tree().quit()
