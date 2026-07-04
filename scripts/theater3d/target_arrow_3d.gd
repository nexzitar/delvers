extends Node3D

## Flat ground arrow at a unit's feet pointing at its current target.

var _head: MeshInstance3D
var _tail: MeshInstance3D

func _init(color: Color):
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Triangular head lying flat, apex toward local +Z.
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(0.26, 0.22, 0.04)
	_head = MeshInstance3D.new()
	_head.mesh = head_mesh
	_head.material_override = mat
	_head.rotation_degrees = Vector3(90, 0, 0)
	_head.position = Vector3(0, 0.02, 0.5)
	add_child(_head)

	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.09, 0.04, 0.22)
	_tail = MeshInstance3D.new()
	_tail.mesh = tail_mesh
	_tail.material_override = mat
	_tail.position = Vector3(0, 0.02, 0.3)
	add_child(_tail)

## Sits at the owner's feet, rotated so local +Z faces the target.
func point(from: Vector3, to: Vector3):
	position = Vector3(from.x, 0.0, from.z)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(flat.x, flat.z)
