extends Node
func _ready():
	for gear in ["gear_shield", "gear_sword", "gear_boot", "gear_greave", "gear_bracer", "gear_gauntlet", "gear_leather_chest", "gear_robe"]:
		var model = load("res://resources/models/%s.glb" % gear).instantiate()
		add_child(model)
		var aabb := AABB()
		var stack = [model]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is MeshInstance3D:
				var b = n.get_aabb()
				b.position += n.global_position
				aabb = b if aabb.size == Vector3.ZERO else aabb.merge(b)
			stack.append_array(n.get_children())
		print(gear, " pos=", aabb.position, " size=", aabb.size)
		model.queue_free()
	get_tree().quit()
