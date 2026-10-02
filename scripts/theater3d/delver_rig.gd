extends Node3D

## Poseable delver: the same primitive parts as delver_builder, but
## grouped under hip/shoulder/spine pivots so procedural walk, idle,
## and sword-swing cycles can drive them.

const Builder = preload("res://scripts/theater3d/delver_builder.gd")

const SWING_T := 0.95
const SHOOT_T := 1.4
const DEATH_T := 0.9

var spine: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var sword: Node3D
var off_sword: Node3D
var shield: Node3D
var bow: Node3D
var arrow: Node3D

## Carry: limbs horizontal (top tip forward, belly down), so the string
## runs perpendicular to the hanging arm. Aim: rolled up vertical, belly
## forward. Only the Z component differs, so the draw sweeps smoothly.
const BOW_REST := Vector3(0, -90, -90)
const BOW_AIM := Vector3(0, -90, 0)

## Carry grip: blade tips 45 degrees forward instead of straight up.
const SWORD_REST := Vector3(45, 0, 20)
## The swing arc below was tuned around this grip; windup/recovery blend
## between the carry grip and it (the 55-degree pitch offset).
const SWORD_SWING_BASE := Vector3(-10, 0, 20)
## Off-hand (left) mirrors the Z cant.
const OFF_SWORD_REST := Vector3(45, 0, -20)
const OFF_SWORD_SWING_BASE := Vector3(-10, 0, -20)

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

	if opts.get("off_sword", false):
		off_sword = Builder.build_sword()
		off_sword.position = Vector3(0.02, -0.36, 0.07)
		off_sword.rotation_degrees = OFF_SWORD_REST
		# A touch smaller so the off-hand blade reads as the lighter one.
		off_sword.scale = Vector3.ONE * 0.88
		arm_l.add_child(off_sword)

	if opts.get("shield", false):
		shield = Builder.build_shield()
		shield.position = Vector3(0.09, -0.16, 0.07)
		shield.rotation_degrees = Vector3(90, 45, 0)
		arm_l.add_child(shield)

	# --- Worn gear: basic but visible. Every slot earns its silhouette.
	if opts.has("shoulders"):
		var pad_color: Color = opts.shoulders
		for pair in [[arm_l, 1.0], [arm_r, -1.0]]:
			Builder._box(pair[0], Vector3(0.21, 0.1, 0.2), pad_color,
				Vector3(pair[1] * 0.03, 0.1, 0))
			Builder._box(pair[0], Vector3(0.16, 0.06, 0.16),
				pad_color.lightened(0.18), Vector3(pair[1] * 0.03, 0.17, 0))
	if opts.has("cloak"):
		var cloth := Builder._box(spine, Vector3(0.38, 0.52, 0.045),
			opts.cloak, Vector3(0, -0.02, -0.155))
		cloth.rotation_degrees = Vector3(-4, 0, 0)
		Builder._box(spine, Vector3(0.4, 0.05, 0.05),
			Color("d8c684"), Vector3(0, 0.36, -0.14))
	if opts.has("chest_plate"):
		Builder._box(spine, Vector3(0.36, 0.3, 0.045), opts.chest_plate,
			Vector3(0, 0.2, 0.125))
	if opts.has("belt_trim"):
		Builder._box(spine, Vector3(0.43, 0.09, 0.27),
			opts.belt_trim, Vector3(0, 0.005, 0))
		Builder._box(spine, Vector3(0.09, 0.09, 0.03),
			Color("c7a94a"), Vector3(0, 0.005, 0.135))
	if opts.has("gauntlets"):
		for arm in [arm_l, arm_r]:
			Builder._box(arm, Vector3(0.115, 0.12, 0.14), opts.gauntlets,
				Vector3(0, -0.36, 0))
	if opts.has("bracers"):
		for arm in [arm_l, arm_r]:
			Builder._box(arm, Vector3(0.115, 0.15, 0.13), opts.bracers,
				Vector3(0, -0.2, 0))
	if opts.has("greaves"):
		for leg in [leg_l, leg_r]:
			Builder._box(leg, Vector3(0.145, 0.2, 0.16), opts.greaves,
				Vector3(0, -0.17, 0.005))
	if opts.has("boots_gear"):
		for leg in [leg_l, leg_r]:
			Builder._box(leg, Vector3(0.16, 0.13, 0.22), opts.boots_gear,
				Vector3(0, -0.34, 0.025))
			Builder._box(leg, Vector3(0.14, 0.09, 0.05),
				opts.boots_gear.lightened(0.25), Vector3(0, -0.35, 0.13))

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
	if off_sword:
		off_sword.rotation_degrees = OFF_SWORD_REST
	if bow:
		bow.rotation_degrees = BOW_REST
		arrow.visible = false
		if bow is BowProp:
			bow.set_draw(0.0)

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

## Shared chop envelope: wind up, strike, recover. Sign convention:
## positive X rotation swings a hanging limb BACKWARD. The blade pitch
## makes blade angle (arm_x + pitch) sweep from cocked-behind up over
## the head to forward at contact.
func _swing_envelope(p: float) -> Dictionary:
	var v := {}
	if p < 0.38:
		var k := smoothstep(0.0, 1.0, p / 0.38)
		v.arm_x = lerpf(0.0, 2.2, k)
		v.arm_z = lerpf(0.0, 0.5, k)
		v.twist = lerpf(0.0, -0.35, k)
		v.lean = 0.03
		v.guard = lerpf(0.0, 0.2, k)
		v.lunge = lerpf(0.0, -0.06, k)
		v.pitch = lerpf(55.0, -234.0, k)
	elif p < 0.52:
		var k := smoothstep(0.0, 1.0, (p - 0.38) / 0.14)
		v.arm_x = lerpf(2.2, -1.45, k)
		v.arm_z = lerpf(0.5, -0.1, k)
		v.twist = lerpf(-0.35, 0.4, k)
		v.lean = lerpf(0.03, 0.14, k)
		v.guard = lerpf(0.2, 0.5, k)
		v.lunge = lerpf(-0.06, 0.14, k)
		v.pitch = lerpf(-234.0, 188.0, k)
	else:
		var k := smoothstep(0.0, 1.0, (p - 0.52) / 0.48)
		v.arm_x = lerpf(-1.45, 0.0, k)
		v.arm_z = lerpf(-0.1, 0.0, k)
		v.twist = lerpf(0.4, 0.0, k)
		v.lean = lerpf(0.14, 0.03, k)
		v.guard = lerpf(0.5, 0.0, k)
		v.lunge = lerpf(0.14, 0.0, k)
		v.pitch = lerpf(188.0, 55.0, k)
	return v

## Main-hand overhead chop. t in [0, SWING_T].
func pose_swing(t: float):
	_reset_pose()
	var v := _swing_envelope(clampf(t / SWING_T, 0.0, 1.0))
	arm_r.rotation.x = v.arm_x
	arm_r.rotation.z = v.arm_z
	spine.rotation.y = v.twist
	spine.rotation.x = v.lean
	# Weight shift: sway back on the windup, into the blow on the strike.
	spine.position.z = v.lunge
	arm_l.rotation.x = -v.guard * 0.8
	arm_l.rotation.z = -0.15 * v.guard
	# The blade pitches through the hand so it leads the arc and points
	# at the target on contact instead of staying in carry grip.
	if sword:
		sword.rotation_degrees = SWORD_SWING_BASE + Vector3(v.pitch, 0, 0)
	# Eyes stay on the target through the torso twist.
	head.rotation.y = -v.twist * 0.5

## Mirrored chop with the off-hand weapon (dual wield).
func pose_swing_off(t: float):
	if off_sword == null:
		pose_swing(t)
		return
	_reset_pose()
	var v := _swing_envelope(clampf(t / SWING_T, 0.0, 1.0))
	arm_l.rotation.x = v.arm_x
	arm_l.rotation.z = -v.arm_z
	spine.rotation.y = -v.twist
	spine.rotation.x = v.lean
	spine.position.z = v.lunge
	arm_r.rotation.x = -v.guard * 0.4
	off_sword.rotation_degrees = OFF_SWORD_SWING_BASE + Vector3(v.pitch, 0, 0)
	head.rotation.y = v.twist * 0.5

## Seated on a log: legs stretched forward, hands in the lap, a slow
## breathing sway. t is continuous seconds for the idle motion.
func pose_sit(t: float):
	_reset_pose()
	var breathe := sin(t * 1.7)
	# Positive X swings a hanging limb backward, so legs go forward
	# with negative rotation; slight asymmetry keeps it natural.
	leg_l.rotation.x = -1.5
	leg_r.rotation.x = -1.32
	arm_l.rotation.x = -0.35
	arm_r.rotation.x = -0.3
	spine.rotation.x = 0.1 + 0.02 * breathe
	spine.position.y = 0.4 + 0.008 * breathe
	head.rotation.x = -0.08

## Crumple: torso pitches forward, knees fold, body sinks. Holds the
## final frame so corpses can stay on the field. t in [0, DEATH_T].
func pose_death(t: float):
	_reset_pose()
	var k := smoothstep(0.0, 1.0, clampf(t / DEATH_T, 0.0, 1.0))
	spine.rotation.x = 1.35 * k
	spine.position.y = 0.4 - 0.24 * k
	leg_l.rotation.x = -0.85 * k
	leg_r.rotation.x = -0.65 * k
	arm_l.rotation.x = -0.45 * k
	arm_r.rotation.x = -0.55 * k
	head.rotation.x = 0.35 * k

## Raise, nock, draw to the cheek, loose, lower. t in [0, SHOOT_T].
## target_dist: rig-local forward distance the arrow flies before sticking.
func has_bow() -> bool:
	return bow != null

func pose_shoot(t: float, target_dist := 2.2):
	# No bow (a sword hero casting Heal): wind up a spell instead.
	if bow == null:
		pose_spellcast(t)
		return
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

	# Bow arm points at the target. The bow is a child of the arm, so
	# the aim orientation counter-rotates the arm's pitch: at full draw
	# the bow stands world-vertical, top tip up, belly forward.
	arm_l.rotation.x = lerpf(0.0, -1.35, aim)
	var rest_q := Quaternion.from_euler(BOW_REST * (PI / 180.0))
	var aim_q := Quaternion(Vector3.RIGHT, 1.35) \
		* Quaternion.from_euler(BOW_AIM * (PI / 180.0))
	bow.quaternion = rest_q.slerp(aim_q, aim)
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
	# The string follows the same hand: drawn until the release beat,
	# then it snaps home and the bow's own nocked arrow vanishes.
	if bow is BowProp:
		bow.set_draw(draw if p < release else 0.0)
	if p >= release and p < 0.92:
		arrow.visible = true
		var f := clampf((p - release) / flight, 0.0, 1.0)
		arrow.position = Vector3(0.24, 0.62, lerpf(0.1, target_dist, f))
	else:
		arrow.visible = false

## Bow-less cast: both hands raised before the chest, a held focus,
## then a release push. Driven on the same clock as pose_shoot so the
## theater's cast timing needs no special case.
func pose_spellcast(t: float):
	_reset_pose()
	var p := clampf(t / SHOOT_T, 0.0, 1.0)
	var lift: float
	var push := 0.0
	if p < 0.3:
		lift = smoothstep(0.0, 1.0, p / 0.3)
	elif p < 0.72:
		lift = 1.0
		push = 0.15 * sin((p - 0.3) / 0.42 * PI)
	else:
		lift = 1.0 - smoothstep(0.0, 1.0, (p - 0.72) / 0.28)
	arm_l.rotation.x = lerpf(0.0, -1.5, lift) - push
	arm_r.rotation.x = lerpf(0.0, -1.5, lift) - push
	arm_l.rotation.z = lerpf(0.0, 0.35, lift)
	arm_r.rotation.z = lerpf(0.0, -0.35, lift)
	spine.rotation.x = lerpf(0.0, 0.08, lift) - push * 0.5
	head.rotation.x = lerpf(0.0, -0.12, lift)

const SPIN_T := 0.6

## Whirlwind stance: arms flung wide, knees bent; the theater spins
## the whole rig while this holds.
func pose_spin(t: float):
	_reset_pose()
	var p := clampf(t / SPIN_T, 0.0, 1.0)
	var open_arms := sin(minf(p * 1.4, 1.0) * PI)
	arm_l.rotation.z = 1.35 * open_arms
	arm_r.rotation.z = -1.35 * open_arms
	spine.rotation.x = 0.1 * open_arms
	leg_l.rotation.x = -0.25 * open_arms
	leg_r.rotation.x = 0.25 * open_arms
