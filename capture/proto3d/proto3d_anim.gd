extends Node3D

## Animated 3D prototype: a delver walks in, chops a training dummy
## twice, turns, and walks back — looping. Run this scene directly to
## watch it live; proto3d_anim_shot.tscn captures filmstrips from it.

const Builder = preload("res://capture/proto3d/delver_builder.gd")
const DelverRig = preload("res://capture/proto3d/delver_rig.gd")

## He walks left-to-right so his (true right) sword arm faces the camera.
const WALK_SPEED := 1.15
const STRIDE_RATE := 7.0
const X_START := -2.4
const X_STOP := -0.85
const SETTLE_T := 0.25
const ADMIRE_T := 0.4
const TURN_T := 0.35

var auto_play := true
var rig: Node3D
var walk_t: float
var cycle_len: float
var time := 0.0

func _ready():
	walk_t = (X_STOP - X_START) / WALK_SPEED
	cycle_len = (walk_t + SETTLE_T + 2.0 * DelverRig.SWING_T
		+ ADMIRE_T + TURN_T + walk_t + TURN_T)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_world()
	_setup_actors()
	apply_time(0.0)

func _process(delta):
	if not auto_play:
		return
	time += delta
	apply_time(time)

## Deterministic pose for any point in the loop, so the live scene and
## the frame-capture harness replay the exact same motion.
func apply_time(t: float):
	t = fmod(t, cycle_len)

	if t < walk_t:
		rig.rotation_degrees.y = 90
		rig.position.x = X_START + WALK_SPEED * t
		rig.pose_walk(t * STRIDE_RATE)
		return
	t -= walk_t

	if t < SETTLE_T:
		rig.position.x = X_STOP
		rig.rotation_degrees.y = 90
		rig.pose_idle(t)
		return
	t -= SETTLE_T

	if t < 2.0 * DelverRig.SWING_T:
		rig.pose_swing(fmod(t, DelverRig.SWING_T))
		return
	t -= 2.0 * DelverRig.SWING_T

	if t < ADMIRE_T:
		rig.pose_idle(t)
		return
	t -= ADMIRE_T

	if t < TURN_T:
		# 90 -> -90 sweeps through 0: he turns facing the camera.
		rig.rotation_degrees.y = lerpf(90, -90, smoothstep(0.0, 1.0, t / TURN_T))
		rig.pose_idle(t)
		return
	t -= TURN_T

	if t < walk_t:
		rig.rotation_degrees.y = -90
		rig.position.x = X_STOP - WALK_SPEED * t
		rig.pose_walk(t * STRIDE_RATE)
		return
	t -= walk_t

	rig.rotation_degrees.y = lerpf(-90, 90, smoothstep(0.0, 1.0, t / TURN_T))
	rig.pose_idle(t)

func _setup_actors():
	rig = DelverRig.new({"sword": true, "shield": true, "helmet": true})
	rig.position = Vector3(X_START, 0, 0)
	add_child(rig)
	var dummy := build_dummy()
	dummy.position = Vector3(0.15, 0, -0.1)
	add_child(dummy)

## Training dummy: post, crossbar arms, straw head.
static func build_dummy() -> Node3D:
	var dummy := Node3D.new()
	Builder._cylinder(dummy, 0.2, 0.08, Builder.BOOTS, Vector3(0, 0.04, 0))
	Builder._cylinder(dummy, 0.06, 1.1, Builder.WOOD, Vector3(0, 0.55, 0))
	Builder._box(dummy, Vector3(0.56, 0.07, 0.07), Builder.WOOD, Vector3(0, 0.78, 0))
	Builder._sphere(dummy, 0.13, Color("d9b46a"), Vector3(0, 1.22, 0))
	return dummy

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
	camera.position = Vector3(-1.0, 1.5, 3.6)
	add_child(camera)
	camera.look_at(Vector3(-1.0, 0.55, 0))
