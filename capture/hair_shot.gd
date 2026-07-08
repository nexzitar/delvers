extends Node3D

## The spring hair in motion: the actor sweeps sideways then stops -
## frames show the tail lagging, swinging through, settling.

var actor: AnimatedActor
var frame := 0
var out := ProjectSettings.globalize_path("res://capture/proto3d/renders")
var shots := {20: "hair_moving", 34: "hair_overshoot", 75: "hair_settled"}

func _ready():
	var cam := Camera3D.new()
	cam.position = Vector3(0.9, 1.3, 1.7)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0))
	add_child(cam)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.15, 0.17, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	add_child(env)
	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_female.glb"].duplicate(true)
	actor = AnimatedActor.new(load("res://resources/models/delver_female.glb"), config)
	add_child(actor)

func _process(_delta):
	frame += 1
	# Sweep right for 30 frames, then hold still.
	if frame <= 30:
		actor.position.x = -0.6 + frame * 0.04
		actor.pose_walk(frame * 0.3)
	else:
		actor.pose_idle(frame * 0.016)
	if shots.has(frame):
		var img = get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, shots[frame]])
	if frame > 80:
		print("HAIR SHOTS DONE")
		get_tree().quit()
