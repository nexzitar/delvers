extends Node3D

## The guild portrait: four delvers, four armor identities, one
## campaign. Plate warden, chitin vanguard, leather scout, cloth
## mystic - every piece generated or sculpted, recolored per school.

const DelverRigX = preload("res://scripts/theater3d/delver_rig.gd")

func _actor(model: String, opts: Dictionary, at: Vector3, face := 0.0) -> AnimatedActor:
	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_%s.glb" % model].duplicate(true)
	config.merge(opts, true)
	var actor = AnimatedActor.new(load("res://resources/models/delver_%s.glb" % model), config)
	actor.position = at
	actor.rotation.y = face
	add_child(actor)
	return actor

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.4, 1.5, 4.4)
	cam.look_at_from_position(cam.position, Vector3(0, 0.62, 0))
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
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.5)
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

	# The Warden: full plate, steel and iron.
	var warden = _actor("male", {
		"sword": true, "shield": true, "helmet": true,
		"helmet_gear": "starter_helmet", "main_gear": "starter_sword",
		"off_gear": "starter_shield", "shoulder_gear": "wardens_pauldrons",
		"shoulders": true, "chest_gear": "chitin_armor", "chest_plate": true,
		"belt_gear": "studded_belt", "belt_trim": true,
		"greaves": true, "boots_gear": true,
	}, Vector3(-1.15, 0, 0.1), 0.12)
	# Greaves/boots models via gear ids:
	warden.queue_free()
	warden = _actor("male", {
		"sword": true, "shield": true, "helmet": true,
		"helmet_gear": "starter_helmet", "main_gear": "starter_sword",
		"off_gear": "starter_shield", "shoulder_gear": "wardens_pauldrons",
		"shoulders": true, "chest_gear": "chitin_armor", "chest_plate": true,
		"belt_gear": "studded_belt", "belt_trim": true,
	}, Vector3(-1.15, 0, 0.1), 0.12)
	_extra(warden, ["iron_greaves", "iron_shod_boots", "goblin_work_gauntlets"])
	warden.pose_idle(2.0)

	# The Vanguard: the same steel, drowned in chitin.
	var vanguard = _actor("male", {
		"sword": true, "shield": true,
		"main_gear": "starter_sword", "off_gear": "chitin_shield",
		"chest_gear": "chitin_armor", "chest_plate": true,
		"belt_gear": "studded_belt", "belt_trim": true,
	}, Vector3(-0.38, 0, -0.15), -0.06)
	_extra(vanguard, ["iron_shod_boots"])
	vanguard.pose_swing(0.38)

	# The Scout: oiled leather, quick hands.
	var scout = _actor("female", {
		"bow": true, "chest_gear": "oiled_leathers", "chest_plate": true,
		"belt_gear": "studded_belt", "belt_trim": true,
	}, Vector3(0.42, 0, -0.1), -0.2)
	_extra(scout, ["silk_bracers", "sprung_boots"])
	scout.pose_shoot(0.7)

	# The Mystic: pale silk, deep wells.
	var mystic = _actor("female", {
		"chest_gear": "showcase_robe", "chest_plate": true,
	}, Vector3(1.2, 0, 0.12), -0.35)
	_extra(mystic, ["silk_bracers"])
	mystic.pose_spellcast(0.65)

	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/guild_portrait.png"))
	print("PORTRAIT DONE")
	get_tree().quit()

## Mount additional worn models by gear id directly.
func _extra(actor: AnimatedActor, gear_ids: Array):
	for gear_id in gear_ids:
		actor._mount_worn_model(gear_id)
