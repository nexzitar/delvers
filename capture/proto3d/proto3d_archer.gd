extends Node3D

## Archer demo: a bow delver repeatedly draws and shoots the training
## dummy. Run this scene directly to watch it live.

const DelverRig = preload("res://capture/proto3d/delver_rig.gd")
const AnimDemo = preload("res://capture/proto3d/proto3d_anim.gd")

const IDLE_T := 0.6
const REST_T := 0.4
## Rig-local forward distance to the dummy post face (arrow sticks there).
const ARROW_DIST := 2.1

var auto_play := true
var rig: Node3D
var cycle_len: float
var time := 0.0

func _ready():
	cycle_len = IDLE_T + DelverRig.SHOOT_T + REST_T
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_world()

	rig = DelverRig.new({"bow": true})
	rig.position = Vector3(1.6, 0, 0)
	rig.rotation_degrees = Vector3(0, -90, 0)
	add_child(rig)

	var dummy := AnimDemo.build_dummy()
	dummy.position = Vector3(-0.8, 0, -0.1)
	add_child(dummy)

	apply_time(0.0)

func _process(delta):
	if not auto_play:
		return
	time += delta
	apply_time(time)

func apply_time(t: float):
	t = fmod(t, cycle_len)
	if t < IDLE_T:
		rig.pose_idle(t)
		return
	t -= IDLE_T
	if t < DelverRig.SHOOT_T:
		rig.pose_shoot(t, ARROW_DIST)
		return
	t -= DelverRig.SHOOT_T
	rig.pose_idle(t)

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
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("55584a")
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var camera := Camera3D.new()
	camera.fov = 32
	camera.position = Vector3(0.4, 1.4, 3.4)
	add_child(camera)
	camera.look_at(Vector3(0.4, 0.6, 0))
