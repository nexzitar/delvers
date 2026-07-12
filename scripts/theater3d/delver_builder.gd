## Procedural low-poly delver + gear built entirely from Godot primitive
## meshes. Prototype for judging a possible 2D -> 3D art direction:
## every part is a flat-colored box/cylinder/sphere, Crossy-Road style.

const SKIN := Color("e8b98a")
const HAIR := Color("6b4a2f")
const TUNIC := Color("4a6a8a")
const SLEEVE := Color("3e5a76")
const PANTS := Color("5a4636")
const BOOTS := Color("3d2f22")
const LEATHER := Color("7a5230")
const WOOD := Color("8a5a33")
const METAL := Color("b9c2cc")
const DARK_METAL := Color("6f7680")
const EYES := Color("2a2320")
const FLETCH := Color("b04a3a")

static func _mat(color: Color, metallic := 0.0, roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

static func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3,
		rot := Vector3.ZERO, metallic := 0.0, roughness := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, metallic, roughness)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3,
		rot := Vector3.ZERO, metallic := 0.0, roughness := 0.85) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, color, pos, rot, metallic, roughness)

static func _cylinder(parent: Node3D, radius: float, height: float, color: Color,
		pos: Vector3, rot := Vector3.ZERO, metallic := 0.0, roughness := 0.85) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	return _add(parent, c, color, pos, rot, metallic, roughness)

static func _sphere(parent: Node3D, radius: float, color: Color, pos: Vector3,
		metallic := 0.0, roughness := 0.85, hemisphere := false, height := -1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height if height > 0.0 else radius * 2.0
	s.is_hemisphere = hemisphere
	s.radial_segments = 12
	s.rings = 6
	return _add(parent, s, color, pos, Vector3.ZERO, metallic, roughness)

# --- Character ---------------------------------------------------------

## opts: helmet / sword / shield / bow (all bool)
static func build_delver(opts := {}) -> Node3D:
	var root := Node3D.new()

	# Legs and boots.
	for side in [-1, 1]:
		_box(root, Vector3(0.13, 0.3, 0.15), PANTS, Vector3(side * 0.09, 0.25, 0))
		_box(root, Vector3(0.15, 0.12, 0.2), BOOTS, Vector3(side * 0.09, 0.06, 0.02))

	# Torso, belt, shoulders.
	_box(root, Vector3(0.4, 0.42, 0.24), TUNIC, Vector3(0, 0.58, 0))
	_box(root, Vector3(0.42, 0.07, 0.26), LEATHER, Vector3(0, 0.4, 0))
	for side in [-1, 1]:
		_box(root, Vector3(0.14, 0.13, 0.16), SLEEVE, Vector3(side * 0.27, 0.72, 0))
		# Arm and hand.
		_box(root, Vector3(0.1, 0.32, 0.12), SKIN, Vector3(side * 0.27, 0.5, 0))
		_box(root, Vector3(0.09, 0.09, 0.11), SKIN, Vector3(side * 0.27, 0.32, 0))

	# Head and face.
	_box(root, Vector3(0.3, 0.28, 0.28), SKIN, Vector3(0, 0.94, 0))
	for side in [-1, 1]:
		_box(root, Vector3(0.035, 0.055, 0.012), EYES, Vector3(side * 0.07, 0.95, 0.143))

	if opts.get("helmet", false):
		var helmet := build_helmet()
		helmet.position = Vector3(0, 0.98, 0)
		root.add_child(helmet)
	else:
		# Hair: cap plus a back panel.
		_box(root, Vector3(0.34, 0.09, 0.32), HAIR, Vector3(0, 1.1, 0))
		_box(root, Vector3(0.34, 0.2, 0.07), HAIR, Vector3(0, 1.0, -0.135))

	# Facing +Z, the character's right hand is -X and left hand +X.
	if opts.get("sword", false):
		var sword := build_sword()
		sword.position = Vector3(-0.29, 0.32, 0.07)
		# Ready carry: blade tips 45 degrees forward instead of straight up.
		sword.rotation_degrees = Vector3(45, 0, 20)
		root.add_child(sword)

	if opts.get("shield", false):
		var shield := build_shield()
		shield.position = Vector3(0.36, 0.52, 0.07)
		# Angled outward so it reads as carried on the arm, not held up front.
		shield.rotation_degrees = Vector3(90, 45, 0)
		root.add_child(shield)

	if opts.get("bow", false):
		var bow := build_bow()
		bow.position = Vector3(0.31, 0.32, 0.08)
		# Carried with limbs horizontal (top tip forward, belly down), so
		# the string runs perpendicular to the hanging arm.
		bow.rotation_degrees = Vector3(0, -90, -90)
		root.add_child(bow)
		var quiver := build_quiver()
		quiver.position = Vector3(-0.1, 0.68, -0.19)
		quiver.rotation_degrees = Vector3(8, 0, 18)
		root.add_child(quiver)

	return root

# --- Weapons and gear ---------------------------------------------------

## Shared blade-weapon shape; origin at the grip. The blade's wide flat
## faces sideways (+/-X) so the cutting edge leads on a forward chop.
static func _blade_weapon(blade_len: float, blade_w: float, guard_w: float,
		grip_len: float) -> Node3D:
	var root := Node3D.new()
	_cylinder(root, 0.024, grip_len, LEATHER, Vector3.ZERO)
	_sphere(root, 0.034, DARK_METAL, Vector3(0, -grip_len * 0.5 - 0.02, 0), 0.6, 0.4)
	_box(root, Vector3(0.05, 0.035, guard_w), DARK_METAL,
		Vector3(0, grip_len * 0.5 + 0.02, 0), Vector3.ZERO, 0.6, 0.4)
	_box(root, Vector3(0.018, blade_len, blade_w), METAL,
		Vector3(0, grip_len * 0.5 + 0.04 + blade_len * 0.5, 0), Vector3.ZERO, 0.8, 0.3)
	# Tip wedge.
	_box(root, Vector3(0.018, 0.06, blade_w * 0.55), METAL,
		Vector3(0, grip_len * 0.5 + 0.06 + blade_len, 0), Vector3.ZERO, 0.8, 0.3)
	return root

static func build_sword() -> Node3D:
	return _blade_weapon(0.48, 0.055, 0.16, 0.13)

static func build_dagger() -> Node3D:
	return _blade_weapon(0.24, 0.045, 0.1, 0.1)

static func build_axe() -> Node3D:
	var root := Node3D.new()
	_cylinder(root, 0.028, 0.6, WOOD, Vector3.ZERO)
	# Head: cheek, flared blade (rotated boxes fake the curve), back spike.
	_box(root, Vector3(0.16, 0.14, 0.04), DARK_METAL, Vector3(0.08, 0.18, 0), Vector3.ZERO, 0.6, 0.5)
	_box(root, Vector3(0.09, 0.3, 0.045), METAL, Vector3(0.19, 0.18, 0), Vector3.ZERO, 0.7, 0.4)
	_box(root, Vector3(0.09, 0.14, 0.045), METAL, Vector3(0.17, 0.28, 0), Vector3(0, 0, -22), 0.7, 0.4)
	_box(root, Vector3(0.09, 0.14, 0.045), METAL, Vector3(0.17, 0.08, 0), Vector3(0, 0, 22), 0.7, 0.4)
	_box(root, Vector3(0.09, 0.07, 0.04), DARK_METAL, Vector3(-0.08, 0.18, 0), Vector3.ZERO, 0.6, 0.5)
	return root

static func build_shield() -> Node3D:
	var root := Node3D.new()
	_cylinder(root, 0.23, 0.045, WOOD, Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.21
	rim.outer_radius = 0.25
	rim.rings = 24
	rim.ring_segments = 8
	_add(root, rim, DARK_METAL, Vector3.ZERO, Vector3.ZERO, 0.6, 0.4)
	_sphere(root, 0.06, METAL, Vector3(0, 0.03, 0), 0.8, 0.3)
	return root

static func build_helmet() -> Node3D:
	var root := Node3D.new()
	# Dome wide enough to swallow the box head's corners.
	_sphere(root, 0.24, METAL, Vector3.ZERO, 0.4, 0.6, true, 0.2)
	_cylinder(root, 0.25, 0.04, DARK_METAL, Vector3(0, 0.01, 0), Vector3.ZERO, 0.6, 0.5)
	_box(root, Vector3(0.04, 0.16, 0.025), DARK_METAL,
		Vector3(0, -0.07, 0.16), Vector3.ZERO, 0.6, 0.5)
	return root

static func build_bow() -> Node3D:
	# The bow owns its string now: BowProp carries the flexing nock,
	# the draw schedule, and the nocked arrow.
	return BowProp.new()

static func build_quiver() -> Node3D:
	var root := Node3D.new()
	_cylinder(root, 0.055, 0.32, LEATHER, Vector3.ZERO)
	for i in 3:
		var off := Vector3(-0.025 + 0.025 * i, 0.21, -0.02 + 0.02 * i)
		_cylinder(root, 0.008, 0.14, WOOD, off)
		_box(root, Vector3(0.04, 0.05, 0.04), FLETCH, off + Vector3(0, 0.08, 0))
	return root
