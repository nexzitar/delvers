extends Node

## The socket contract: a mounted item's grip point coincides with
## its body socket, whatever the fit transforms say.

func _ready():
	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
	config.merge({"sword": true, "main_gear": "starter_sword"}, true)
	var actor = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
	add_child(actor)

	var grip = actor.tuning.get("grips", {}).get("sword_m")
	assert(grip != null, "sword grip missing from tuning")
	var socket = actor.tuning.get("sockets", {}).get(grip.socket)
	assert(socket != null, "socket %s missing" % grip.socket)

	var piece = actor.worn_mounts["sword_m"].back()
	var mount = piece.get_parent()
	assert(mount is BoneAttachment3D and mount.bone_name == socket.bone,
		"sword must ride the socket bone")

	# The grip point, in mount space, must land on the socket point.
	var grip_world = piece.position + piece.basis * actor._vec(grip.position)
	var socket_pos = actor._vec(socket.position)
	assert(grip_world.distance_to(socket_pos) < 0.001,
		"grip point off socket by %f" % grip_world.distance_to(socket_pos))

	# Pose seeks must not disturb the mount (the old fit-reset bug).
	var before = piece.transform
	actor.pose_swing(0.5)
	actor.pose_idle(0.3)
	assert(piece.transform.is_equal_approx(before),
		"pose seek moved the socketed sword")

	print("PASS test_sockets")
	get_tree().quit()
