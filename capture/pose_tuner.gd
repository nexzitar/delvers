extends Node3D

## Live pose tuning: run this scene (F6), then in the editor pick
## Scene panel -> Remote tab -> PoseTuner, and drag the exported
## sliders. The seated pair re-poses every frame from these values.
## When it looks right, read the numbers off and hand them over.

@export_range(-3.0, 3.0, 0.05) var hand_yaw := 2.5
@export_range(-3.0, 3.0, 0.05) var hand_pitch := 1.75
@export_range(-2.0, 2.0, 0.05) var forearm_bend := 0.65
@export_range(-2.0, 2.0, 0.05) var polish_reach := 0.35
@export var shield_pos := Vector3(0.42, 0.15, 0.24)
@export var shield_tilt := Vector3(32, 18, 78)

var garrick: AnimatedActor
var clock := 0.0

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.8, 1.1, 2.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0.45, 0))
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.15, 0.13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var log_mesh := MeshInstance3D.new()
	var log_cyl := CylinderMesh.new()
	log_cyl.top_radius = 0.16
	log_cyl.bottom_radius = 0.16
	log_cyl.height = 0.9
	log_mesh.mesh = log_cyl
	log_mesh.rotation_degrees = Vector3(0, 0, 90)
	log_mesh.position = Vector3(0, 0.16, -0.05)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.35, 0.22, 0.12)
	log_mesh.material_override = bark
	add_child(log_mesh)

	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
	config.merge({"sword": true, "shield": true, "helmet": true}, true)
	garrick = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
	garrick.position = Vector3(0, 0.31, 0)
	add_child(garrick)

func _process(delta):
	clock += delta
	garrick.pose_sit(clock)
	# Re-apply the tunable joints on top.
	garrick._rotate_bone("R_Forearm", Vector3.RIGHT, forearm_bend - 0.65)
	garrick._rotate_bone("R_Hand", Vector3.UP, hand_yaw - 2.5)
	garrick._rotate_bone("R_Hand", Vector3.RIGHT, hand_pitch - 1.75)
	garrick._rotate_bone("L_Upperarm", Vector3.RIGHT, polish_reach - 0.35)
	if garrick._shield_prop:
		garrick._shield_prop.position = shield_pos
		garrick._shield_prop.rotation_degrees = shield_tilt
