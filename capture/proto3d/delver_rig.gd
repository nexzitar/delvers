extends Node3D

## Poseable delver: the same primitive parts as delver_builder, but
## grouped under hip/shoulder/spine pivots so procedural walk, idle,
## and sword-swing cycles can drive them.

const Builder = preload("res://capture/proto3d/delver_builder.gd")

const SWING_T := 0.95
const SHOOT_T := 1.4

var spine: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var sword: Node3D
var bow: Node3D
var arrow: Node3D

## Bow carry and aim share the sagittal plane: belly forward, string
## toward the archer.
const BOW_REST := Vector3(0, -90, 0)
const BOW_AIM := Vector3(0, -90, 0)

## Carry grip: blade tips 45 degrees forward instead of straight up.
const SWORD_REST := Vector3(45, 0, 20)
## The swing arc below was tuned around this grip; windup/recovery blend
## between the carry grip and it (the 55-degree pitch offset).
const SWORD_SWING_BASE := Vector3(-10, 0, 20)

## opts also takes a palette (skin/tunic/sleeve/pants/eyes as Colors,
## hair as Color or null for bald) plus ears:true for goblin-style ears,
## so one rig serves heroes and humanoid enemies alike.
func _init(opts := {}):
	var skin: Color = opts.get("skin", Builder.SKIN)
	var tunic: Color = opts.get("tunic", Builder.TUNIC)
	var sleeve: Color = opts.get("sleeve", Builder.SLEEVE)
	var pants: Color = opts.get("pants", Builder.PANTS)
	var eyes: Color = opts.get("eyes", Builder.EYES)
	var hair = opts.get("hair", Builder.HAIR)

	# Legs hang from hip pivots so rotation swings them.
	leg_l = _pivot(self, Vector3(-0.09, 0.4, 0))
	leg_r = _pivot(self, Vector3(0.09, 0.4, 0))
	for leg in [leg_l, leg_r]:
		Builder._box(leg, Vector3(0.13, 0.3, 0.15), pants, Vector3(0, -0.15, 0))
		Builder._box(leg, Vector3(0.15, 0.12, 0.2), Builder.BOOTS, Vector3(0, -0.34, 0.02))

	# Everything above the belt pivots on the spine (twist and lean).
	spine = _pivot(self, Vector3(0, 0.4, 0))
	Builder._box(spine, Vector3(0.4, 0.42, 0.24), tunic, Vector3(0, 0.18, 0))
	Builder._box(spine, Vector3(0.42, 0.07, 0.26), Builder.LEATHER, Vector3.ZERO)

	head = _pivot(spine, Vector3(0, 0.54, 0))
	Builder._box(head, Vector3(0.3, 0.28, 0.28), skin, Vector3.ZERO)
	for side in [-1, 1]:
		Builder._box(head, Vector3(0.035, 0.055, 0.012), eyes,
			Vector3(side * 0.07, 0.01, 0.143))
	if opts.get("ears", false):
		for side in [-1, 1]:
			var ear := Builder._box(head, Vector3(0.14, 0.06, 0.03), skin,
				Vector3(side * 0.2, 0.06, -0.02))
			ear.rotation_degrees = Vector3(0, 0, side * 18)
	if opts.get("helmet", false):
		var helmet := Builder.build_helmet()
		helmet.position = Vector3(0, 0.04, 0)
		head.add_child(helmet)
	elif hair != null:
		Builder._box(head, Vector3(0.34, 0.09, 0.32), hair, Vector3(0, 0.16, 0))
		Builder._box(head, Vector3(0.34, 0.2, 0.07), hair, Vector3(0, 0.06, -0.135))

	# Facing local +Z, the character's left side is +X, right side -X.
	arm_l = _pivot(spine, Vector3(0.27, 0.28, 0))
	arm_r = _pivot(spine, Vector3(-0.27, 0.28, 0))
	for arm in [arm_l, arm_r]:
		Builder._box(arm, Vector3(0.14, 0.13, 0.16), sleeve, Vector3(0, 0.04, 0))
		Builder._box(arm, Vector3(0.1, 0.32, 0.12), skin, Vector3(0, -0.18, 0))
		Builder._box(arm, Vector3(0.09, 0.09, 0.11), skin, Vector3(0, -0.36, 0))

	if opts.get("sword", false):
		sword = Builder.build_sword()
		sword.position = Vector3(-0.02, -0.36, 0.07)
		sword.rotation_degrees = SWORD_REST
		arm_r.add_child(sword)

	if opts.get("shield", false):
		var shield := Builder.build_shield()
		shield.position = Vector3(0.09, -0.16, 0.07)
		shield.rotation_degrees = Vector3(90, 45, 0)
		arm_l.add_child(shield)

	if opts.get("bow", false):
		bow = Builder.build_bow()
		bow.position = Vector3(0.04, -0.36, 0.08)
		bow.rotation_degrees = BOW_REST
		arm_l.add_child(bow)
		var quiver := Builder.build_quiver()
		quiver.position = Vector3(-0.1, 0.28, -0.19)
		quiver.rotation_degrees = Vector3(8, 0, 18)
		spine.add_child(quiver)
		# The arrow lives on the rig root so its flight path is simple
		# rig-local forward; hidden except while nocked or flying.
		arrow = _build_arrow()
		arrow.visible = false
		add_child(arrow)

static func _build_arrow() -> Node3D:
	var root := Node3D.new()
	var shaft := Builder._cylinder(root, 0.012, 0.5, Builder.WOOD, Vector3.ZERO)
	shaft.rotation_degrees = Vector3(90, 0, 0)
	Builder._box(root, Vector3(0.03, 0.03, 0.06), Builder.FLETCH, Vector3(0, 0, -0.25))
	Builder._box(root, Vector3(0.025, 0.025, 0.05), Builder.METAL,
		Vector3(0, 0, 0.26), Vector3.ZERO, 0.7, 0.4)
	return root

static func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	return node

# --- Poses --------------------------------------------------------------

func _reset_pose():
	for pivot in [leg_l, leg_r, arm_l, arm_r, spine, head]:
		pivot.rotation = Vector3.ZERO
	spine.position = Vector3(0, 0.4, 0)
	if sword:
		sword.rotation_degrees = SWORD_REST
	if bow:
		bow.rotation_degrees = BOW_REST
		arrow.visible = false

func pose_idle(t: float):
	_reset_pose()
	var breathe := sin(t * 2.4)
	spine.rotation.x = 0.03 + 0.012 * breathe
	spine.position.y = 0.4 + 0.006 * breathe
	arm_l.rotation.z = -0.06 - 0.02 * breathe
	arm_r.rotation.z = 0.06 + 0.02 * breathe

## phase advances TAU per stride pair; feet plant on the beats.
func pose_walk(phase: float):
	_reset_pose()
	var s := sin(phase)
	leg_l.rotation.x = 0.5 * s
	leg_r.rotation.x = -0.5 * s
	# Damped counter-swing: he's carrying gear.
	arm_l.rotation.x = -0.22 * s
	arm_r.rotation.x = 0.22 * s
	spine.rotation.x = 0.09
	head.rotation.x = -0.06
	spine.position.y = 0.4 + 0.03 * absf(cos(phase))

## One overhead chop: wind up, strike, recover. t in [0, SWING_T].
func pose_swing(t: float):
	_reset_pose()
	var p := clampf(t / SWING_T, 0.0, 1.0)
	var arm_x: float
	var arm_z: float
	var twist: float
	var lean: float
	var guard: float
	var lunge: float
	var pitch: float
	# Sign convention: positive X rotation swings a hanging limb BACKWARD.
	# The blade pitch is chosen so blade angle (arm_x + pitch) sweeps from
	# cocked-behind (-108deg) up over the head to forward (105deg) at contact.
	if p < 0.38:
		var k := smoothstep(0.0, 1.0, p / 0.38)
		arm_x = lerpf(0.0, 2.2, k)
		arm_z = lerpf(0.0, 0.5, k)
		twist = lerpf(0.0, -0.35, k)
		lean = 0.03
		guard = lerpf(0.0, 0.2, k)
		lunge = lerpf(0.0, -0.06, k)
		pitch = lerpf(55.0, -234.0, k)
	elif p < 0.52:
		var k := smoothstep(0.0, 1.0, (p - 0.38) / 0.14)
		arm_x = lerpf(2.2, -1.45, k)
		arm_z = lerpf(0.5, -0.1, k)
		twist = lerpf(-0.35, 0.4, k)
		lean = lerpf(0.03, 0.14, k)
		guard = lerpf(0.2, 0.5, k)
		lunge = lerpf(-0.06, 0.14, k)
		pitch = lerpf(-234.0, 188.0, k)
	else:
		var k := smoothstep(0.0, 1.0, (p - 0.52) / 0.48)
		arm_x = lerpf(-1.45, 0.0, k)
		arm_z = lerpf(-0.1, 0.0, k)
		twist = lerpf(0.4, 0.0, k)
		lean = lerpf(0.14, 0.03, k)
		guard = lerpf(0.5, 0.0, k)
		lunge = lerpf(0.14, 0.0, k)
		pitch = lerpf(188.0, 55.0, k)
	arm_r.rotation.x = arm_x
	arm_r.rotation.z = arm_z
	spine.rotation.y = twist
	spine.rotation.x = lean
	# Weight shift: sway back on the windup, into the blow on the strike.
	spine.position.z = lunge
	arm_l.rotation.x = -guard * 0.8
	arm_l.rotation.z = -0.15 * guard
	# The blade pitches through the hand so it leads the arc and points
	# at the target on contact instead of staying in carry grip.
	if sword:
		sword.rotation_degrees = SWORD_SWING_BASE + Vector3(pitch, 0, 0)
	# Eyes stay on the target through the torso twist.
	head.rotation.y = -twist * 0.5

## Raise, nock, draw to the cheek, loose, lower. t in [0, SHOOT_T].
## target_dist: rig-local forward distance the arrow flies before sticking.
func pose_shoot(t: float, target_dist := 2.2):
	_reset_pose()
	var p := clampf(t / SHOOT_T, 0.0, 1.0)

	var aim: float    # 0..1 bow arm raised and bow turned to fire position
	var draw: float   # 0..1 string hand pulled back to the cheek
	if p < 0.3:
		aim = smoothstep(0.0, 1.0, p / 0.3)
		draw = 0.0
	elif p < 0.55:
		aim = 1.0
		draw = smoothstep(0.0, 1.0, (p - 0.3) / 0.25)
	elif p < 0.72:
		aim = 1.0
		draw = 1.0
	else:
		var k := smoothstep(0.0, 1.0, (p - 0.72) / 0.28)
		aim = 1.0 - k
		draw = 0.0

	# Bow arm points at the target; bow pivots belly-forward.
	arm_l.rotation.x = lerpf(0.0, -1.35, aim)
	bow.rotation_degrees = BOW_REST.lerp(BOW_AIM, aim)
	# String hand: reaches to the bow, then pulls back toward the cheek.
	arm_r.rotation.x = lerpf(0.0, -1.25, aim) + draw * 0.55
	arm_r.rotation.z = draw * 0.12
	# Slight archer stance: torso turned a touch, lean into the draw.
	spine.rotation.y = lerpf(0.0, -0.15, aim)
	spine.rotation.x = draw * 0.05
	head.rotation.y = -spine.rotation.y * 0.6

	# Arrow: nocked while drawing, released at p=0.62, sticks briefly.
	var release := 0.62
	var flight := 0.06
	if bow == null or arrow == null:
		return
	if p >= 0.34 and p < release:
		arrow.visible = true
		# Rides at aim height; slides back with the draw.
		arrow.position = Vector3(0.24, 0.62, lerpf(0.3, 0.1, draw))
	elif p >= release and p < 0.92:
		arrow.visible = true
		var f := clampf((p - release) / flight, 0.0, 1.0)
		arrow.position = Vector3(0.24, 0.62, lerpf(0.1, target_dist, f))
	else:
		arrow.visible = false
