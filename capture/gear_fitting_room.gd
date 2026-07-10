@tool
extends Node3D

## THE FITTING ROOM: open this scene IN THE EDITOR (double-click
## gear_fitting_room.tscn - do NOT run it). A fully kitted delver
## stands in the viewport; every gear piece is a real node named
## FIT_<piece> in the Scene dock. Select one, move/rotate/scale it
## with the standard gizmos (W/E/R), then tick save_fits here on the
## root node - the transforms write to pose_tuning.json and the game
## wears them. Tick rebuild to re-dress from the saved file.
## DON'T Ctrl+S the scene itself; the json is the save.

@export var wear_robe := false:
	set(value):
		wear_robe = value
		_build()

@export var rebuild := false:
	set(value):
		rebuild = false
		if value:
			_build()

@export var save_fits := false:
	set(value):
		save_fits = false
		if value:
			_save()

var actor: AnimatedActor

func _ready():
	_build()

func _build():
	for child in get_children():
		if child.name == "FittingActor":
			child.free()
	AnimatedActor._tuning_cache = null
	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
	config.merge({
		"sword": true, "shield": true, "helmet": true,
		"helmet_gear": "starter_helmet", "main_gear": "starter_sword",
		"off_gear": "starter_shield", "shoulders": true,
		"shoulder_gear": "wardens_pauldrons",
		"chest_plate": true,
		"chest_gear": "showcase_robe" if wear_robe else "chitin_armor",
		"belt_trim": true, "belt_gear": "studded_belt",
	}, true)
	actor = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
	actor.name = "FittingActor"
	add_child(actor)
	for extra in ["iron_shod_boots", "iron_greaves", "silk_bracers",
			"goblin_work_gauntlets"]:
		actor._mount_worn_model(extra)
	actor.pose_idle(0.0)

	# Expose the pieces to the Scene dock with honest names.
	var root = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	for fit_key in actor.worn_mounts:
		var pieces: Array = actor.worn_mounts[fit_key]
		for i in pieces.size():
			var piece = pieces[i]
			piece.name = "FIT_%s%s" % [fit_key, "_mirror" if i == 1 else ""]
			var walker = piece
			while walker != self and walker != null:
				walker.owner = root
				walker = walker.get_parent()

func _save():
	if actor == null:
		return
	var fits := {}
	for fit_key in actor.worn_mounts:
		var pieces: Array = actor.worn_mounts[fit_key]
		var saved := []
		for piece in pieces:
			if not is_instance_valid(piece):
				continue
			saved.append({
				"position": [piece.position.x, piece.position.y, piece.position.z],
				"rotation": [piece.rotation_degrees.x, piece.rotation_degrees.y,
					piece.rotation_degrees.z],
				"scale": [piece.scale.x, piece.scale.y, piece.scale.z],
			})
		if not saved.is_empty():
			fits[fit_key] = {"pieces": saved}
	var tuning = AnimatedActor._load_tuning().duplicate(true)
	tuning["fits"] = fits
	var file = FileAccess.open(AnimatedActor.TUNING_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(tuning, "\t"))
	file = null
	AnimatedActor._tuning_cache = null
	print("FITS SAVED to ", AnimatedActor.TUNING_PATH)
