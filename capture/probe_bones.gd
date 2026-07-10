extends Node
func _ready():
	var model = load("res://resources/models/delver_male.glb").instantiate()
	add_child(model)
	var skeleton: Skeleton3D = null
	var stack = [model]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Skeleton3D: skeleton = n
		stack.append_array(n.get_children())
	for pair in [["L_Foot", "R_Foot"], ["L_Calf", "R_Calf"], ["L_Hand", "R_Hand"], ["L_Forearm", "R_Forearm"], ["L_Upperarm", "R_Upperarm"]]:
		var li = skeleton.find_bone(pair[0])
		var ri = skeleton.find_bone(pair[1])
		var lb = skeleton.get_bone_global_rest(li).basis
		var rb = skeleton.get_bone_global_rest(ri).basis
		# If R equals L reflected across X, locals auto-mirror.
		var mirror = Basis(Vector3(-1,0,0), Vector3(0,1,0), Vector3(0,0,1))
		var reflected = mirror * lb * mirror
		var diff = (reflected.inverse() * rb).get_euler().length()
		var rot_diff = (lb.inverse() * rb).get_euler().length()
		print("%s: reflect-diff %.2f, same-diff %.2f" % [pair[1], diff, rot_diff])
	get_tree().quit()
