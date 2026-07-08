extends Node3D

## THE GUILD ANIMATOR: live pose tuning for ANY animation. Run this
## scene (F6), then in the editor: Scene panel -> Remote tab -> select
## GuildAnimator, and drag the exported sliders. Everything re-poses
## live. Camera: LEFT-drag orbits, wheel zooms, MIDDLE-drag (or
## shift+drag) pans.
##
## SAVING: toggle save_tuning and the current sit values write to
## resources/tuning/pose_tuning.json - the game reads that file, so
## the camp updates on its next load. No screenshots needed.
##
## - pose: which animation plays (authored poses and baked clips both)
## - scrub + playing: freeze at a moment or let it run
## - grip: seat the sword in the fist (position in hand-space, meters)
## - joint offsets: degrees, added ON TOP of the pose every frame
## When it looks right, screenshot the inspector and hand it over.

## Toggle to write the sit tuning to disk (acts as a button).
@export var save_tuning := false:
	set(value):
		save_tuning = false
		if value:
			_save()

@export_enum("sit", "swing", "idle", "walk", "shoot", "cast", "spin", "death") \
	var pose := "sit":
	set(value):
		pose = value
@export var playing := true
## Freeze-frame position when playing is OFF (works for every pose).
@export_range(0.0, 1.0, 0.01) var scrub := 0.5
## Animation speed while playing.
@export_range(0.1, 3.0, 0.05) var speed := 1.0
## How far the polish strokes travel (sit only).
@export_range(0.0, 2.0, 0.05) var stroke_scale := 1.0
## Where the delver stands (sink him onto the seat).
@export var delver_position := Vector3(0, 0.31, 0)

@export_group("Resting shield")
@export var shield_pos := Vector3(0.4, 0.0, 0.2)
@export var shield_tilt := Vector3(32, 60, 60)

@export_group("Sword grip")
@export var grip_position := Vector3(0.0, 0.05, 0.0)
@export var grip_rotation := Vector3(-115, 0, 0)

@export_group("Joint offsets (degrees)")
@export var right_shoulder := Vector3.ZERO
@export var right_elbow := Vector3.ZERO
@export var right_hand := Vector3.ZERO
@export var left_hand := Vector3.ZERO
@export var left_shoulder := Vector3.ZERO
@export var left_elbow := Vector3.ZERO
@export var head := Vector3.ZERO
@export var spine := Vector3.ZERO

var garrick: AnimatedActor
var clock := 0.0

func _sync_from_tuning():
	var sit = garrick.tuning.get("sit", {})
	var joints = sit.get("joints", {})
	for knob in JOINTS:
		if joints.has(JOINTS[knob]):
			var deg = joints[JOINTS[knob]]
			set(knob, Vector3(deg[0], deg[1], deg[2]))
	grip_position = AnimatedActor._vec(sit.get("grip_position", [0, 0.05, 0]))
	grip_rotation = AnimatedActor._vec(sit.get("grip_rotation", [-50, 0, -40]))
	shield_pos = AnimatedActor._vec(sit.get("shield_position", [0.4, 0, 0.2]))
	shield_tilt = AnimatedActor._vec(sit.get("shield_tilt", [32, 70, 60]))
	stroke_scale = sit.get("stroke_scale", 1.0)
	speed = sit.get("stroke_speed", 1.0)

func _apply_to_tuning():
	var joints := {}
	for knob in JOINTS:
		var v: Vector3 = get(knob)
		joints[JOINTS[knob]] = [v.x, v.y, v.z]
	garrick.tuning["sit"] = {
		"joints": joints,
		"grip_position": [grip_position.x, grip_position.y, grip_position.z],
		"grip_rotation": [grip_rotation.x, grip_rotation.y, grip_rotation.z],
		"shield_position": [shield_pos.x, shield_pos.y, shield_pos.z],
		"shield_tilt": [shield_tilt.x, shield_tilt.y, shield_tilt.z],
		"seat_offset": [delver_position.x - 0.0, delver_position.y - 0.31,
			delver_position.z - 0.0],
		"stroke_scale": stroke_scale,
		"stroke_speed": speed,
	}

func _save():
	_apply_to_tuning()
	var file = FileAccess.open(AnimatedActor.TUNING_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(garrick.tuning, "\t"))
	file = null
	AnimatedActor._tuning_cache = null
	print("TUNING SAVED to ", AnimatedActor.TUNING_PATH)

const JOINTS := {
	"right_shoulder": "R_Upperarm", "right_elbow": "R_Forearm",
	"right_hand": "R_Hand", "left_hand": "L_Hand",
	"left_shoulder": "L_Upperarm",
	"left_elbow": "L_Forearm", "head": "Head", "spine": "Spine01",
}

func _ready():
	var cam := OrbitCamera.new()
	cam.enabled = true
	cam.allow_pan = true
	cam.target = Vector3(0, 0.55, 0)
	cam.distance = 2.3
	cam.min_distance = 0.3
	cam.yaw = 0.4
	cam.pitch = 0.35
	add_child(cam)
	cam._refresh()
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
	add_child(garrick)
	_sync_from_tuning()
	delver_position = Vector3(0, 0.31, 0) \
		+ AnimatedActor._vec(garrick.tuning.get("sit", {}).get("seat_offset", [0, 0, 0]))

func _process(delta):
	if playing:
		clock += delta * speed
	garrick.position = delver_position
	# Paused: scrub places every pose at an exact moment.
	var cycle = clock if playing else scrub * 2.42
	var shot = fposmod(clock * 0.6, 1.0) if playing else scrub
	match pose:
		"sit": garrick.pose_sit(cycle, stroke_scale)
		"swing": garrick.pose_swing(fposmod(clock * 0.8, 1.0) if playing else scrub)
		"idle": garrick.pose_idle(clock if playing else scrub * 4.0)
		"walk": garrick.pose_walk(clock * 7.0 if playing else scrub * TAU)
		"shoot": garrick.pose_shoot(shot)
		"cast": garrick.pose_spellcast(shot)
		"spin": garrick.pose_spin(shot)
		"death": garrick.pose_death(clampf(fposmod(clock * 0.4, 1.4), 0.0, 1.0) if playing else scrub)

	if pose == "sit":
		# The knobs ARE the tuning: pose_sit consumes them next frame.
		_apply_to_tuning()
	else:
		# Other poses: knobs ride on top as additive experiments.
		if garrick._sword_node and (grip_position != Vector3.ZERO
				or grip_rotation != Vector3(-115, 0, 0)):
			garrick._sword_node.position = grip_position
			garrick._sword_node.rotation_degrees = grip_rotation
		for knob in JOINTS:
			var offset: Vector3 = get(knob)
			if offset != Vector3.ZERO:
				for axis in 3:
					if offset[axis] != 0.0:
						var axis_vec = [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis]
						garrick._rotate_bone(JOINTS[knob], axis_vec, deg_to_rad(offset[axis]))
