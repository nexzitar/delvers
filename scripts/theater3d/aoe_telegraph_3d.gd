extends Node3D

## Ground circle that fades in over the telegraph duration, then pops
## and frees itself. Self-managed once added to the tree.

var _duration: float
var _mat: StandardMaterial3D

func _init(radius: float, duration: float):
	_duration = maxf(duration, 0.15)

	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 24

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.55, 0.75, 1.0, 0.0)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh := MeshInstance3D.new()
	mesh.mesh = disc
	mesh.material_override = _mat
	mesh.position.y = 0.02
	add_child(mesh)

func _ready():
	var tween := create_tween()
	tween.tween_property(_mat, "albedo_color:a", 0.45, _duration)
	tween.tween_property(_mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
