@tool
extends Node3D

## THE SOCKET WORKSHOP: open this scene IN THE EDITOR (double-click
## socket_workshop.tscn - do NOT run it). Pick a SUBJECT in the
## inspector (delver, goblin_warrior, goblin_archer) and it stands
## with its weapons. Two families of markers appear in the Scene dock:
##
##   SOCKET_<name>  - a point on the BODY (grip_main in the right
##                    palm, grip_off in the left, back between the
##                    shoulders, hip_l / hip_r on the belt line).
##   GRIP_<fit>     - a point on an ITEM (the spot on the sword's
##                    handle the fist closes around). The shield
##                    keeps its Fitting Room fit until you add
##                    "shield_m" to GEAR_GRIP_SOCKETS below.
##
## Select a marker, move/rotate it with the standard gizmos, then
## tick save_sockets on this root node - the game mounts every item
## so its GRIP lands exactly on its SOCKET, in every pose. Tick
## rebuild to re-mount from the saved file and inspect the result.
## Sockets without items yet (back, hips) are the future homes of
## quivers, backpacks and potion pouches. A bow will add a second
## grip for the string hand when the new bows arrive.
## DON'T Ctrl+S the scene itself; pose_tuning.json is the save.

## Sockets every delver body carries, and the bone each rides.
const DEFAULT_SOCKETS := {
	"grip_main": "R_Hand",
	"grip_off": "L_Hand",
	"shield_arm": "L_Forearm",
	"back": "Spine02",
	"hip_l": "Waist",
	"hip_r": "Waist",
}

## Which body stands for fitting. Goblins hold the procedural sword
## and shield through sword_p / shield_p grips.
@export_enum("delver", "goblin_warrior", "goblin_archer") var subject := "delver":
	set(value):
		subject = value
		if is_inside_tree():
			_build()

@export var rebuild := false:
	set(value):
		rebuild = false
		if value:
			_build()

@export var save_sockets := false:
	set(value):
		save_sockets = false
		if value:
			_save()

var actor: AnimatedActor
var _socket_markers := {}
var _grip_markers := {}
var _grip_socket := {}
var _grip_props := {}

## Live preview: every frame, re-mount each prop so its grip marker
## lands on its socket marker - drag a gizmo, watch the weapon move.
func _process(_delta):
	if not Engine.is_editor_hint() or actor == null:
		return
	for grip_key in _grip_markers:
		var marker = _grip_markers.get(grip_key)
		var smarker = _socket_markers.get(_grip_socket.get(grip_key, ""))
		var prop = _grip_props.get(grip_key)
		if not (is_instance_valid(marker) and is_instance_valid(smarker) \
				and is_instance_valid(prop)):
			continue
		var socket_rot := Basis.from_euler(smarker.rotation)
		var grip_rot := Basis.from_euler(marker.rotation)
		var keep_scale = prop.scale
		prop.quaternion = (socket_rot * grip_rot.inverse()).get_rotation_quaternion()
		prop.scale = keep_scale
		prop.position = smarker.position - prop.basis * marker.position

func _ready():
	_build()

func _build():
	for child in get_children():
		if child.name == "WorkshopActor":
			child.free()
	_socket_markers.clear()
	_grip_markers.clear()
	_grip_socket.clear()
	_grip_props.clear()
	AnimatedActor._tuning_cache = null
	var model_paths := {
		"delver": "res://resources/models/delver_male.glb",
		"goblin_warrior": "res://resources/models/goblin_warrior_m.glb",
		"goblin_archer": "res://resources/models/goblin_archer_m.glb",
	}
	var model_path: String = model_paths[subject]
	var config = ActorFactory3D.MODEL_CONFIGS[model_path].duplicate(true)
	if subject == "delver":
		config.merge({"sword": true, "shield": true,
			"main_gear": "starter_sword", "off_gear": "starter_shield"}, true)
	actor = AnimatedActor.new(load(model_path), config)
	actor.name = "WorkshopActor"
	add_child(actor)
	actor.pose_idle(0.0)

	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	var saved_sockets: Dictionary = actor.tuning.get("sockets", {})
	for socket_name in DEFAULT_SOCKETS:
		var saved = saved_sockets.get(socket_name, {})
		var mount = actor._attach(saved.get("bone", DEFAULT_SOCKETS[socket_name]))
		var marker := Marker3D.new()
		marker.name = "SOCKET_" + socket_name
		marker.gizmo_extents = 0.06
		mount.add_child(marker)
		if saved.has("position"):
			marker.position = actor._vec(saved.position)
			marker.rotation_degrees = actor._vec(saved.rotation)
		_socket_markers[socket_name] = marker
		_own(marker, root)

	var saved_grips: Dictionary = actor.tuning.get("grips", {})
	for fit_key in actor.worn_mounts:
		if not GEAR_GRIP_SOCKETS.has(fit_key):
			continue
		_add_grip_marker(fit_key, actor.worn_mounts[fit_key].back(),
			saved_grips, root)
	# Procedural weapons (goblin sword and shield, the bow) fit the
	# same way: their grips live on prop_mounts.
	for grip_key in actor.prop_mounts:
		_add_grip_marker(grip_key, actor.prop_mounts[grip_key],
			saved_grips, root)

func _add_grip_marker(grip_key: String, piece: Node3D,
		saved_grips: Dictionary, root: Node):
	_grip_props[grip_key] = piece
	_grip_socket[grip_key] = GEAR_GRIP_SOCKETS.get(grip_key,
		saved_grips.get(grip_key, {}).get("socket", "grip_main"))
	var marker := Marker3D.new()
	marker.name = "GRIP_" + grip_key
	marker.gizmo_extents = 0.35
	piece.add_child(marker)
	var saved = saved_grips.get(grip_key, {})
	if saved.has("position"):
		marker.position = actor._vec(saved.position)
		marker.rotation_degrees = actor._vec(saved.rotation)
	_grip_markers[grip_key] = marker
	_own(marker, root)

## Which socket each grippable fit hangs from. Add a fit here and
## rebuild to start fitting its grip.
const GEAR_GRIP_SOCKETS := {
	"sword_m": "grip_main",
}

func _own(marker: Node, root: Node):
	var walker: Node = marker
	while walker != self and walker != null:
		walker.owner = root
		walker = walker.get_parent()

func _save():
	if actor == null:
		return
	var tuning = AnimatedActor._load_tuning().duplicate(true)
	var sockets = tuning.get("sockets", {})
	for socket_name in _socket_markers:
		var marker = _socket_markers[socket_name]
		if not is_instance_valid(marker):
			continue
		sockets[socket_name] = {
			"bone": sockets.get(socket_name, {}).get(
				"bone", DEFAULT_SOCKETS[socket_name]),
			"position": [marker.position.x, marker.position.y, marker.position.z],
			"rotation": [marker.rotation_degrees.x, marker.rotation_degrees.y,
				marker.rotation_degrees.z],
		}
	tuning["sockets"] = sockets
	var grips = tuning.get("grips", {})
	for fit_key in _grip_markers:
		var marker = _grip_markers[fit_key]
		if not is_instance_valid(marker):
			continue
		grips[fit_key] = {
			"socket": GEAR_GRIP_SOCKETS.get(fit_key,
				actor.tuning.get("grips", {}).get(fit_key, {}).get("socket", "grip_main")),
			"position": [marker.position.x, marker.position.y, marker.position.z],
			"rotation": [marker.rotation_degrees.x, marker.rotation_degrees.y,
				marker.rotation_degrees.z],
			"scale": marker.get_parent().scale.x,
		}
	tuning["grips"] = grips
	var file = FileAccess.open(AnimatedActor.TUNING_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(tuning, "\t"))
	file = null
	AnimatedActor._tuning_cache = null
	print("SOCKETS SAVED to ", AnimatedActor.TUNING_PATH)
