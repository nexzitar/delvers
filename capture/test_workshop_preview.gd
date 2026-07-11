extends Node

## The workshop preview contract: drag a socket or grip marker and
## the prop re-mounts to follow it on the next frame - including
## after a script hot-reload wipes the workshop's plain vars.

func _ready():
	var workshop = load("res://capture/socket_workshop.tscn").instantiate()
	workshop.subject = "goblin_warrior"
	add_child(workshop)
	await get_tree().process_frame

	var smarker = workshop._socket_markers.get("shield_arm")
	var gmarker = workshop._grip_markers.get("shield_p")
	var prop = workshop._grip_props.get("shield_p")
	assert(smarker != null and gmarker != null and prop != null,
		"workshop must fit the goblin shield")

	# Drag the socket marker: the shield follows next frame.
	var before: Vector3 = prop.position
	smarker.position += Vector3(0.1, 0.05, 0)
	await get_tree().process_frame
	assert(prop.position.distance_to(before + Vector3(0.1, 0.05, 0)) < 0.001,
		"shield must follow the socket marker")

	# Rotate the grip marker: the mount math must keep the grip on
	# the socket (prop transform * grip = socket, scale preserved).
	var kept_scale: Vector3 = prop.scale
	gmarker.rotation_degrees += Vector3(0, 30, 0)
	await get_tree().process_frame
	var grip_world: Vector3 = prop.position + prop.basis * gmarker.position
	assert(grip_world.distance_to(smarker.position) < 0.001,
		"grip point must stay pinned to the socket")
	assert(prop.scale.distance_to(kept_scale) < 0.001,
		"preview must not disturb the prop's scale")

	# Hot-reload amnesia: wipe the plain vars, the preview rewires
	# itself from the standing scene and keeps following.
	workshop.actor = null
	workshop._socket_markers = {}
	workshop._grip_markers = {}
	workshop._grip_socket = {}
	workshop._grip_props = {}
	smarker.position += Vector3(0, 0.07, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(prop.position.distance_to(before + Vector3(0.1, 0.12, 0)) < 0.001,
		"preview must survive a script hot-reload")

	print("PASS test_workshop_preview")
	get_tree().quit()
