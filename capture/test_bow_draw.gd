extends Node

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")

## The bowstring contract: the nock pulls back with the draw, the
## string segments stay tip-to-nock, the nocked arrow rides the
## string, and everything snaps home at release - on both rig kinds.

func _ready():
	# The prop itself.
	var bow := BowProp.new()
	add_child(bow)
	var rest: Vector3 = bow.nock.position
	bow.set_draw(1.0)
	assert(is_equal_approx(rest.x - bow.nock.position.x, BowProp.DRAW_LEN),
		"full draw pulls the nock back by DRAW_LEN")
	assert(bow._nocked_arrow.visible, "an arrow rides the drawn string")
	assert(bow._nocked_arrow.position.is_equal_approx(bow.nock.position),
		"the arrow sits on the nock")
	var upper = bow._string_upper
	var seg_tip: Vector3 = upper.position - upper.quaternion \
		* Vector3(0, upper.scale.y * 0.5, 0)
	var seg_nock: Vector3 = upper.position + upper.quaternion \
		* Vector3(0, upper.scale.y * 0.5, 0)
	assert(seg_tip.distance_to(Vector3(bow.TIP_X, bow.TIP_Y, 0)) < 0.001,
		"the upper string segment stays anchored to the tip")
	assert(seg_nock.distance_to(bow.nock.position) < 0.001,
		"the upper string segment reaches the nock")
	bow.set_draw(0.0)
	assert(bow.nock.position.is_equal_approx(rest), "release snaps home")
	assert(not bow._nocked_arrow.visible, "no arrow at rest")

	# Hand-following stays plausible: a wild hand point is clamped.
	bow.draw_toward(Vector3(2.0, 5.0, -3.0), 1.0)
	assert(bow.nock.position.x >= rest.x - BowProp.DRAW_LEN * 1.2 - 0.001,
		"the nock never over-draws")
	assert(absf(bow.nock.position.y) <= bow.TIP_Y * 0.4 + 0.001,
		"the nock stays between the limbs")
	bow.set_draw(0.0)

	# The shared schedule: nothing early, full near the hold, snap at 1.
	assert(BowProp.draw_amount(0.1) == 0.0, "no draw while nocking")
	assert(BowProp.draw_amount(0.8) == 1.0, "full draw at the hold")
	assert(BowProp.draw_amount(1.01) == 0.0, "released past the beat")

	# A modeled archer draws toward its real string hand.
	var path := "res://resources/models/goblin_archer_m.glb"
	var config = ActorFactory3D.MODEL_CONFIGS[path].duplicate(true)
	var actor := AnimatedActor.new(load(path), config)
	add_child(actor)
	assert(actor._bow_node is BowProp, "the archer carries a live bow")
	var arest: Vector3 = actor._bow_node.nock.position
	actor.pose_shoot(AnimatedActor.DRAW_RELEASE_T * 0.85)
	assert(actor._bow_node.nock.position.distance_to(arest) > 0.05,
		"mid-draw the string is pulled")
	actor.pose_shoot(AnimatedActor.DRAW_RELEASE_T * 1.05)
	assert(actor._bow_node.nock.position.is_equal_approx(arest),
		"past release the string is home")
	actor.pose_walk(0.3)
	assert(actor._bow_node.nock.position.is_equal_approx(arest),
		"other poses never leave the string drawn")

	# The procedural rig ties the string to its authored draw.
	var rig := DelverRig.new({"bow": true})
	add_child(rig)
	assert(rig.bow is BowProp, "the delver rig carries a live bow")
	var rrest: Vector3 = rig.bow.nock.position
	rig.pose_shoot(DelverRig.SHOOT_T * 0.58)
	assert(rig.bow.nock.position.distance_to(rrest) > 0.1,
		"the delver draw bends the string")
	rig.pose_shoot(DelverRig.SHOOT_T * 0.7)
	assert(rig.bow.nock.position.is_equal_approx(rrest),
		"the delver release snaps the string")

	print("PASS test_bow_draw")
	get_tree().quit()
