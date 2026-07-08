class_name SpringTail
extends Node3D

## Secondary motion for hair (and one day cloaks): a short verlet
## chain hanging from its anchor, lagging behind movement and settling
## under gravity - the difference between hair and a helmet.

@export var segment_length := 0.09
@export var segment_count := 3
@export var thickness := 0.055
## Optional rectangular cross-section (cloaks); zero = use thickness.
@export var width := 0.0
@export var depth := 0.0
@export var gravity := Vector3(0, -9.0, 0)
@export var damping := 0.88
@export var stiffness := 0.35
@export var tail_color := Color(0.24, 0.18, 0.12)

var _points: Array[Vector3] = []
var _prev: Array[Vector3] = []
var _segments: Array[MeshInstance3D] = []
## Rest direction in the anchor's local space (down and slightly out).
var rest_local := Vector3(0, -0.8, 0.55)

func _ready():
	for i in segment_count:
		var seg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var taper = 1.0 - 0.25 * i
		var w = width if width > 0.0 else thickness
		var d = depth if depth > 0.0 else thickness
		mesh.size = Vector3(w * (1.0 - 0.08 * i), segment_length, d * taper)
		seg.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tail_color.darkened(0.06 * i)
		mat.roughness = 0.9
		seg.material_override = mat
		seg.top_level = true
		add_child(seg)
		_segments.append(seg)
	_reset_points()

func _reset_points():
	_points.clear()
	_prev.clear()
	var dir = (global_transform.basis * rest_local).normalized()
	for i in segment_count + 1:
		var p = global_position + dir * segment_length * i
		_points.append(p)
		_prev.append(p)

func _process(delta):
	simulate(delta)

func simulate(delta: float):
	if _points.is_empty():
		return
	var dt = clampf(delta, 0.001, 0.05)
	# The root rides the anchor; a teleport (scene swap, spawn) resets
	# the chain instead of whipping it across the field.
	if _points[0].distance_to(global_position) > 1.5:
		_reset_points()
	_points[0] = global_position

	var rest_dir = (global_transform.basis * rest_local).normalized()
	for i in range(1, _points.size()):
		var velocity = (_points[i] - _prev[i]) * damping
		_prev[i] = _points[i]
		_points[i] += velocity + gravity * dt * dt
		# A gentle pull toward the combed rest shape.
		var rest_point = _points[i - 1] + rest_dir * segment_length
		_points[i] = _points[i].lerp(rest_point, stiffness * dt * 10.0)
		# Inextensible strand: keep segment length from the parent.
		var span = _points[i] - _points[i - 1]
		var dist = span.length()
		if dist > 0.0001:
			_points[i] = _points[i - 1] + span / dist * segment_length

	for i in _segments.size():
		var a = _points[i]
		var b = _points[i + 1]
		var seg = _segments[i]
		seg.global_position = (a + b) * 0.5
		var up = (b - a).normalized()
		var side = up.cross(Vector3.FORWARD)
		if side.length() < 0.01:
			side = up.cross(Vector3.RIGHT)
		side = side.normalized()
		seg.global_basis = Basis(side, up, side.cross(up)).orthonormalized()
