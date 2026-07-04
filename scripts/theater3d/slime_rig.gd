extends Node3D

## Green slime: a faceted blob that lives on squash-and-stretch.
## Root sits on the ground; `body` scales/lifts for wobble and hops.

const Builder = preload("res://scripts/theater3d/delver_builder.gd")

const HOP_T := 1.1
const ATTACK_T := 0.8
const DEATH_T := 0.7

const SLIME := Color("4fae4f")
const SLIME_DARK := Color("3c8a3f")

var body: Node3D

func _init():
	body = Node3D.new()
	add_child(body)

	# Main blob, slightly flattened; low segment counts keep it faceted.
	var blob := SphereMesh.new()
	blob.radius = 0.34
	blob.height = 0.68
	blob.radial_segments = 10
	blob.rings = 5
	var blob_mesh := Builder._add(body, blob, SLIME, Vector3(0, 0.24, 0))
	blob_mesh.scale = Vector3(1, 0.72, 1)

	# Base skirt where it meets the ground.
	var skirt := SphereMesh.new()
	skirt.radius = 0.37
	skirt.height = 0.74
	skirt.radial_segments = 10
	skirt.rings = 5
	var skirt_mesh := Builder._add(body, skirt, SLIME_DARK, Vector3(0, 0.13, 0))
	skirt_mesh.scale = Vector3(1, 0.35, 1)

	for side in [-1, 1]:
		Builder._box(body, Vector3(0.05, 0.09, 0.02), Builder.EYES,
			Vector3(side * 0.11, 0.28, 0.29))

func _reset_pose():
	body.scale = Vector3.ONE
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO

## Restful blorp: slow asymmetric breathing wobble.
func pose_idle(t: float):
	_reset_pose()
	var w := sin(t * 2.6)
	body.scale = Vector3(1.0 + 0.05 * w, 1.0 - 0.07 * w, 1.0 + 0.05 * w)

## One hop forward (rig-local +Z). Returns to rest; loop for travel.
func pose_hop(t: float):
	_reset_pose()
	var p := clampf(t / HOP_T, 0.0, 1.0)
	if p < 0.3:
		# Crouch: gather like a spring.
		var k := smoothstep(0.0, 1.0, p / 0.3)
		body.scale = Vector3(1.0 + 0.18 * k, 1.0 - 0.3 * k, 1.0 + 0.18 * k)
	elif p < 0.7:
		# Airborne: stretched, parabolic arc.
		var k := (p - 0.3) / 0.4
		var arc := 4.0 * k * (1.0 - k)
		body.position.y = 0.42 * arc
		body.position.z = 0.5 * k
		var stretch := 0.75 + 0.5 * arc
		body.scale = Vector3(2.0 - stretch, stretch, 2.0 - stretch)
	else:
		# Land: splat and re-settle.
		var k := smoothstep(0.0, 1.0, (p - 0.7) / 0.3)
		body.position.z = 0.5
		var splat := 1.0 + 0.35 * sin(k * PI)
		body.scale = Vector3(splat, 2.0 - splat, splat)

## Travel: bounces in place while the root slides along its path, so
## replayed movement reads as hopping. t is continuous seconds.
func pose_travel(t: float):
	_reset_pose()
	var phase := fmod(t, 0.5) / 0.5
	var arc := 4.0 * phase * (1.0 - phase)
	body.position.y = 0.18 * arc
	var stretch := 0.85 + 0.3 * arc
	body.scale = Vector3(2.0 - stretch, stretch, 2.0 - stretch)

## Deflates into a puddle; holds the final frame as a corpse.
func pose_death(t: float):
	_reset_pose()
	var k := smoothstep(0.0, 1.0, clampf(t / DEATH_T, 0.0, 1.0))
	body.scale = Vector3(1.0 + 0.6 * k, maxf(0.07, 1.0 - 0.93 * k), 1.0 + 0.6 * k)

## Aggressive lunge at a melee target: fast low hop with a splat.
func pose_attack(t: float):
	_reset_pose()
	var p := clampf(t / ATTACK_T, 0.0, 1.0)
	if p < 0.35:
		var k := smoothstep(0.0, 1.0, p / 0.35)
		body.scale = Vector3(1.0 + 0.22 * k, 1.0 - 0.35 * k, 1.0 + 0.22 * k)
		body.position.z = -0.12 * k
	elif p < 0.6:
		var k := (p - 0.35) / 0.25
		var arc := 4.0 * k * (1.0 - k)
		body.position.y = 0.22 * arc
		body.position.z = lerpf(-0.12, 0.55, k)
		var stretch := 0.8 + 0.45 * arc
		body.scale = Vector3(2.0 - stretch, stretch, 2.0 - stretch)
	else:
		# Splat against the target, then spring back to anchor.
		var k := smoothstep(0.0, 1.0, (p - 0.6) / 0.4)
		body.position.z = lerpf(0.55, 0.0, k)
		var splat := 1.0 + 0.4 * sin(minf(k * 2.0, 1.0) * PI)
		body.scale = Vector3(splat, 2.0 - splat, splat)
