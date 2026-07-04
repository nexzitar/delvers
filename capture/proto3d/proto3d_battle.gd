extends Node3D

## Mock battle at gameplay camera distance: two sword delvers trade
## blows with slimes while a hero archer and a goblin archer exchange
## arrows across the field. Pure choreography (no sim) on a 4.8s loop.

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")
const SlimeRig = preload("res://scripts/theater3d/slime_rig.gd")

const LOOP := 4.8
const MELEE_CYCLE := 1.6
const RANGED_CYCLE := 2.4

const GOBLIN := {
	"bow": true, "ears": true, "hair": null,
	"skin": Color("7aa54e"), "tunic": Color("8a4b3a"),
	"sleeve": Color("6f3d30"), "pants": Color("4a4a3a"),
	"eyes": Color("b03030"),
}

var auto_play := true
var cycle_len := LOOP
var time := 0.0

var melee_a: Node3D
var melee_b: Node3D
var archer: Node3D
var goblin: Node3D
var slime_a: Node3D
var slime_b: Node3D

func _ready():
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_world()
	_setup_actors()
	apply_time(0.0)

func _process(delta):
	if not auto_play:
		return
	time += delta
	apply_time(time)

func _setup_actors():
	melee_a = _place(DelverRig.new({"sword": true, "shield": true, "helmet": true}),
		Vector3(-0.5, 0, 0.75), 90)
	melee_b = _place(DelverRig.new({"sword": true, "shield": true}),
		Vector3(-0.85, 0, -0.7), 90)
	archer = _place(DelverRig.new({"bow": true}), Vector3(-2.1, 0, 0.05), 90)

	slime_a = _place(SlimeRig.new(), Vector3(0.5, 0, 0.75), -90)
	slime_b = _place(SlimeRig.new(), Vector3(0.2, 0, -0.7), -90)
	goblin = _place(DelverRig.new(GOBLIN), Vector3(2.2, 0, -0.2), -90)
	goblin.scale = Vector3(0.85, 0.85, 0.85)

	# Ground scatter so the field reads as a place, not a void.
	for prop in [
		[Vector3(-1.6, 0, 1.5), 0.1], [Vector3(2.6, 0, 1.2), 0.14],
		[Vector3(-2.9, 0, -1.3), 0.12], [Vector3(1.1, 0, -1.8), 0.09],
		[Vector3(3.4, 0, -0.9), 0.08], [Vector3(-0.2, 0, 2.2), 0.07],
	]:
		var rock := SphereMesh.new()
		rock.radius = prop[1]
		rock.height = prop[1] * 1.2
		rock.radial_segments = 7
		rock.rings = 4
		var mesh := MeshInstance3D.new()
		mesh.mesh = rock
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("6e7266")
		mat.roughness = 1.0
		mesh.material_override = mat
		mesh.position = prop[0]
		add_child(mesh)
	for i in 10:
		var tuft := BoxMesh.new()
		tuft.size = Vector3(0.05, 0.14, 0.05)
		var mesh := MeshInstance3D.new()
		mesh.mesh = tuft
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("5e7a4a")
		mat.roughness = 1.0
		mesh.material_override = mat
		# Deterministic pseudo-scatter ring around the field.
		var a := i * 2.4 + 0.7
		mesh.position = Vector3(3.6 * cos(a), 0.07, 2.3 * sin(a))
		mesh.rotation_degrees = Vector3(0, i * 36.0, 0)
		add_child(mesh)

func _place(rig: Node3D, pos: Vector3, facing_deg: float) -> Node3D:
	rig.position = pos
	rig.rotation_degrees = Vector3(0, facing_deg, 0)
	add_child(rig)
	return rig

func apply_time(t: float):
	t = fmod(t, LOOP)

	# Melee pairs trade blows on offset beats.
	_melee_beat(melee_a, fmod(t, MELEE_CYCLE))
	_melee_beat(melee_b, fmod(t + 0.8, MELEE_CYCLE))
	_slime_beat(slime_a, fmod(t + 0.5, MELEE_CYCLE))
	_slime_beat(slime_b, fmod(t + 1.3, MELEE_CYCLE))

	# Archers exchange volleys; goblin is scaled so flight distance
	# converts to its local units.
	_archer_beat(archer, fmod(t, RANGED_CYCLE), 4.0)
	_archer_beat(goblin, fmod(t + 1.2, RANGED_CYCLE), 4.0 / 0.85)

func _melee_beat(rig: Node3D, local: float):
	if local < DelverRig.SWING_T:
		rig.pose_swing(local)
	else:
		rig.pose_idle(local)

func _slime_beat(rig: Node3D, local: float):
	if local < SlimeRig.ATTACK_T:
		rig.pose_attack(local)
	else:
		rig.pose_idle(local)

func _archer_beat(rig: Node3D, local: float, dist: float):
	if local < DelverRig.SHOOT_T:
		rig.pose_shoot(local, dist)
	else:
		rig.pose_idle(local)

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

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("55584a")
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var camera := Camera3D.new()
	camera.fov = 35
	camera.position = Vector3(0, 2.9, 5.9)
	add_child(camera)
	camera.look_at(Vector3(0, 0.45, 0))
