extends Node3D
func _ready():
	var config = ActorFactory3D.MODEL_CONFIGS["res://resources/models/delver_male.glb"].duplicate(true)
	config.merge({"chest_plate": true, "chest_gear": "derived_leathers"}, true)
	var actor = AnimatedActor.new(load("res://resources/models/delver_male.glb"), config)
	add_child(actor)
	await get_tree().process_frame
	await get_tree().process_frame
	print("mounts: ", actor.worn_mounts.keys())
	if actor.worn_mounts.has("derived_chest"):
		var piece = actor.worn_mounts["derived_chest"][0]
		print("piece valid: ", is_instance_valid(piece), " visible: ", piece.visible)
		print("piece global: ", piece.global_position)
		print("skeleton global: ", actor._skeleton.global_position)
		print("piece local: ", piece.position)
		var mesh_inst: MeshInstance3D = null
		var stack = [piece]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is MeshInstance3D:
				mesh_inst = n
			stack.append_array(n.get_children())
		if mesh_inst:
			var aabb = mesh_inst.global_transform * mesh_inst.get_aabb()
			print("shell AABB pos ", aabb.position, " size ", aabb.size)
	get_tree().quit()
