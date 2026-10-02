class_name BowProp
extends Node3D

## A bow that knows its own string. The limbs are the familiar swept
## arc; the string is two live segments meeting at a movable nock, so
## a draw actually bends something. Rigs drive it two ways:
##   set_draw(k)            - pull the nock straight back, 0..1
##   draw_toward(p_local, k) - pull it toward the draw hand instead,
##                             clamped so the string stays plausible
## The nocked arrow appears while drawn and vanishes on release.
## Bow-local space: grip at the origin, tips at (TIP_X, +-TIP_Y, 0),
## the arrow flies along +X, a draw pulls the nock along -X.

const WOOD := Color("8a5a33")
const LEATHER := Color("7a5230")
const STRING_COLOR := Color("d8d2c2")
const RADIUS := 0.45
const HALF_ARC := 55.0
const DRAW_LEN := 0.26

var TIP_X := RADIUS * cos(deg_to_rad(HALF_ARC)) - RADIUS
var TIP_Y := RADIUS * sin(deg_to_rad(HALF_ARC))

var nock_rest: Vector3
var nock: Marker3D
var _string_upper: MeshInstance3D
var _string_lower: MeshInstance3D
var _nocked_arrow: Node3D

## The shared draw timing for clip-scrubbed rigs: u is progress with
## release exactly at u = 1 (theater paces the pose so the release
## beat lands on CAST_FINISH). Nock, pull, hold - then the snap.
static func draw_amount(u: float) -> float:
	if u < 0.2 or u >= 1.0:
		return 0.0
	if u < 0.75:
		return smoothstep(0.0, 1.0, (u - 0.2) / 0.55)
	return 1.0

func _init():
	var segments := 7
	for i in segments:
		var a := deg_to_rad(-HALF_ARC + (2.0 * HALF_ARC) * i / (segments - 1))
		var pos := Vector3(RADIUS * cos(a) - RADIUS, RADIUS * sin(a), 0)
		# Segments overlap so the limb reads as one curved piece.
		_box(Vector3(0.035, 0.17, 0.045), WOOD, pos, Vector3(0, 0, rad_to_deg(a)))
	# Grip wrap in the middle.
	_box(Vector3(0.045, 0.1, 0.055), LEATHER, Vector3.ZERO)

	nock_rest = Vector3(TIP_X, 0, 0)
	nock = Marker3D.new()
	nock.name = "Nock"
	nock.position = nock_rest
	add_child(nock)
	_string_upper = _string_segment()
	_string_lower = _string_segment()
	_nocked_arrow = _build_arrow()
	_nocked_arrow.visible = false
	add_child(_nocked_arrow)
	set_draw(0.0)

## Straight pull along the bow's own axis.
func set_draw(k: float):
	_place_nock(nock_rest + Vector3(-DRAW_LEN * clampf(k, 0.0, 1.0), 0, 0),
		clampf(k, 0.0, 1.0))

## Pull toward the draw hand (bow-local point), so hand and string
## stay connected on rigs whose arms we don't author. Clamped: the
## nock never leaves a plausible draw cone.
func draw_toward(hand_local: Vector3, k: float):
	k = clampf(k, 0.0, 1.0)
	var goal := Vector3(
		clampf(hand_local.x, nock_rest.x - DRAW_LEN * 1.2, nock_rest.x),
		clampf(hand_local.y, -TIP_Y * 0.4, TIP_Y * 0.4),
		clampf(hand_local.z, -0.12, 0.12),
	)
	_place_nock(nock_rest.lerp(goal, k), k)

func _place_nock(p: Vector3, k: float):
	nock.position = p
	_stretch(_string_upper, Vector3(TIP_X, TIP_Y, 0), p)
	_stretch(_string_lower, Vector3(TIP_X, -TIP_Y, 0), p)
	_nocked_arrow.visible = k > 0.01
	if _nocked_arrow.visible:
		_nocked_arrow.position = p

func _string_segment() -> MeshInstance3D:
	var seg := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 1.0, 0.012)
	seg.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STRING_COLOR
	mat.roughness = 0.9
	seg.material_override = mat
	add_child(seg)
	return seg

func _stretch(seg: MeshInstance3D, a: Vector3, b: Vector3):
	var d := b - a
	var len := maxf(d.length(), 0.001)
	seg.position = (a + b) * 0.5
	seg.quaternion = Quaternion(Vector3.UP, d / len)
	seg.scale = Vector3(1, len, 1)

## The arrow rests on the string, shaft toward the grip and beyond.
func _build_arrow() -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = 0.5
	shaft.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WOOD.lightened(0.2)
	shaft.material_override = mat
	shaft.rotation_degrees = Vector3(0, 0, -90)
	shaft.position = Vector3(0.25, 0, 0)
	root.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.05, 0.02, 0.006)
	tip.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color("b9c2cc")
	tip.material_override = tip_mat
	tip.position = Vector3(0.5, 0, 0)
	root.add_child(tip)
	var fletch := MeshInstance3D.new()
	var fletch_mesh := BoxMesh.new()
	fletch_mesh.size = Vector3(0.06, 0.03, 0.004)
	fletch.mesh = fletch_mesh
	var fletch_mat := StandardMaterial3D.new()
	fletch_mat.albedo_color = Color("c8443a")
	fletch.material_override = fletch_mat
	fletch.position = Vector3(0.03, 0, 0)
	root.add_child(fletch)
	return root

func _box(size: Vector3, color: Color, pos: Vector3, rot := Vector3.ZERO):
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	inst.material_override = mat
	inst.position = pos
	inst.rotation_degrees = rot
	add_child(inst)
