extends Node3D

## Venomous spider: dark chitin, eight two-segment legs on scuttling
## pivots, red eyes and a venom-green abdomen marking. Faces +Z, and
## shares the slime family's pose API (idle/travel/attack/death).

const Builder = preload("res://scripts/theater3d/delver_builder.gd")

const ATTACK_T := 0.8
const DEATH_T := 0.9

## Per-leg outward yaw, front to back.
const FAN := [0.5, 0.18, -0.18, -0.5]
const SIDES := [-1, 1]

const CHITIN := Color("332823")
const CHITIN_DARK := Color("241b17")
const MARKING := Color("7fae3c")
const EYES := Color("c03434")
const FANG := Color("d8cfc0")

var body: Node3D
## Leg pivots: [side(-1|1)][0..3 front-to-back].
var legs := []

func _init(_opts := {}):
	body = Node3D.new()
	body.position.y = 0.22
	add_child(body)

	# Cephalothorax (front) and abdomen (rear).
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	head.radial_segments = 8
	head.rings = 4
	Builder._add(body, head, CHITIN, Vector3(0, 0.02, 0.14))

	var abdomen := SphereMesh.new()
	abdomen.radius = 0.2
	abdomen.height = 0.4
	abdomen.radial_segments = 8
	abdomen.rings = 4
	var rear := Builder._add(body, abdomen, CHITIN_DARK, Vector3(0, 0.05, -0.16))
	rear.scale = Vector3(1.0, 0.85, 1.15)

	# Venom-green marking hugging the abdomen's back.
	Builder._box(body, Vector3(0.08, 0.015, 0.12), MARKING, Vector3(0, 0.2, -0.16))

	# Eyes and fangs up front.
	for side in [-1, 1]:
		Builder._box(body, Vector3(0.035, 0.035, 0.02), EYES,
			Vector3(side * 0.05, 0.06, 0.27))
		var fang := CylinderMesh.new()
		fang.top_radius = 0.018
		fang.bottom_radius = 0.0
		fang.height = 0.09
		fang.radial_segments = 5
		Builder._add(body, fang, FANG, Vector3(side * 0.05, -0.06, 0.25))

	# Eight thin two-segment legs, fanned front-to-back: pivot at the
	# flank yawed outward, upper segment slanting up-and-out, lower
	# segment dropping to the ground.
	for side in SIDES:
		var row := []
		for i in 4:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.08, 0.05, 0.12 - i * 0.11)
			pivot.rotation.y = -side * FAN[i]
			body.add_child(pivot)
			var upper := Builder._box(
				pivot, Vector3(0.26, 0.024, 0.024), CHITIN,
				Vector3(side * 0.13, 0.07, 0)
			)
			upper.rotation.z = side * -0.6
			var lower := Builder._box(
				pivot, Vector3(0.024, 0.3, 0.024), CHITIN_DARK,
				Vector3(side * 0.25, -0.07, 0)
			)
			lower.rotation.z = side * 0.28
			row.append(pivot)
		legs.append(row)

func _reset_pose():
	body.position = Vector3(0, 0.22, 0)
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	# Legs keep their fan yaw; poses drive rotation.x on top of it.
	for s in 2:
		for i in 4:
			legs[s][i].rotation = Vector3(0, -SIDES[s] * FAN[i], 0)
			legs[s][i].scale = Vector3.ONE

## At rest: a slow breath and tiny leg shifts.
func pose_idle(t: float):
	_reset_pose()
	body.position.y = 0.22 + 0.012 * sin(t * 2.2)
	for s in 2:
		for i in 4:
			legs[s][i].rotation.x = 0.03 * sin(t * 2.2 + i * 1.7 + s * 0.8)

## Scuttle: alternating-tripod leg swings while the root slides.
## t is continuous seconds.
func pose_travel(t: float):
	_reset_pose()
	var stride := t * 14.0
	body.position.y = 0.22 + 0.015 * absf(sin(stride))
	for s in 2:
		for i in 4:
			# Neighbouring legs move in anti-phase.
			var phase = stride + PI * ((i + s) % 2)
			legs[s][i].rotation.x = 0.35 * sin(phase)

## Rear up and lunge with the fangs; contact lands around t=0.4.
func pose_attack(t: float):
	_reset_pose()
	var p := clampf(t / ATTACK_T, 0.0, 1.0)
	if p < 0.4:
		# Rear back onto the hind legs, front legs raised.
		var k := smoothstep(0.0, 1.0, p / 0.4)
		body.rotation.x = -0.55 * k
		body.position.y = 0.22 + 0.1 * k
		for s in 2:
			legs[s][0].rotation.x = -0.9 * k
			legs[s][1].rotation.x = -0.5 * k
	else:
		# Strike down and forward, then settle.
		var k := smoothstep(0.0, 1.0, (p - 0.4) / 0.6)
		var lunge := sin(minf(k * 1.6, 1.0) * PI)
		body.rotation.x = lerpf(-0.55, 0.12 * (1.0 - k), k)
		body.position.z = 0.28 * lunge
		body.position.y = 0.22 + 0.1 * (1.0 - k)
		for s in 2:
			legs[s][0].rotation.x = lerpf(-0.9, 0.0, k)
			legs[s][1].rotation.x = lerpf(-0.5, 0.0, k)

## Collapses, legs curling underneath; holds as a corpse.
func pose_death(t: float):
	_reset_pose()
	var k := smoothstep(0.0, 1.0, clampf(t / DEATH_T, 0.0, 1.0))
	body.position.y = 0.22 - 0.13 * k
	body.rotation.z = 0.5 * k
	for s in 2:
		for i in 4:
			legs[s][i].rotation.x = 1.1 * k * (1 if (i + s) % 2 == 0 else -1)
			legs[s][i].scale = Vector3.ONE * (1.0 - 0.25 * k)
