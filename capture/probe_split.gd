extends Node
func _ready():
	for who in ["male", "female"]:
		var model = load("res://resources/models/delver_%s.glb" % who).instantiate()
		add_child(model)
		var names := []
		var player: AnimationPlayer = null
		var stack = [model]
		while not stack.is_empty():
			var n = stack.pop_back()
			if n is MeshInstance3D:
				names.append(n.name)
			if n is AnimationPlayer:
				player = n
			stack.append_array(n.get_children())
		print(who, " meshes: ", names)
		if player:
			print(who, " clips: ", player.get_animation_list())
		model.queue_free()
	get_tree().quit()
