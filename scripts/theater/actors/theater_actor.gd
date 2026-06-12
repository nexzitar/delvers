extends Node2D
class_name TheaterActor

const SWING_SOUND = preload("res://audio/melee_swing.wav")
const BOW_SOUND = preload("res://audio/bow_release.wav")

@onready var sprite = $Sprite2D
@onready var animation_player = $AnimationPlayer
@export var attack_direction := 1

## Optional attack pose shown while winding up an attack.
@export var attack_texture: Texture2D
## Extra scale applied to the attack pose, relative to the idle sprite scale.
@export var attack_texture_scale := 1.0

enum DeathStyle {
	FALL,
	SQUASH
}

enum IdleStyle {
	BREATHE,
	WOBBLE
}

@export var death_style: DeathStyle = DeathStyle.FALL
@export var idle_style: IdleStyle = IdleStyle.BREATHE

## Where projectiles leave this actor, relative to its origin.
## The x component is flipped by attack_direction.
@export var projectile_origin := Vector2(70, -10)

var entity_id : int

var weapon_type := GearDefinition.WeaponType.NONE
var weapon_node: Sprite2D
var arm_pivot: Node2D

var _idle_texture: Texture2D
var _idle_region_enabled: bool
var _idle_sprite_scale: Vector2
var _idle_sprite_position: Vector2
var _idle_tween: Tween

func _ready():
	_idle_texture = sprite.texture
	_idle_region_enabled = sprite.region_enabled
	_idle_sprite_scale = sprite.scale
	_idle_sprite_position = sprite.position
	arm_pivot = sprite.get_node_or_null("ArmPivot")
	_start_idle()

func _start_idle():

	_stop_idle()

	# Slightly randomized period so units don't move in lockstep.
	var period = randf_range(0.9, 1.1)

	if idle_style == IdleStyle.WOBBLE:
		_start_wobble(period * 1.4)
	else:
		_start_breathe(period * 2.6)

func _stop_idle():

	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null

	sprite.scale = _idle_sprite_scale
	sprite.position = _idle_sprite_position

func _start_breathe(period):
	# Chest rise: the sprite stretches a bit taller, narrows a touch,
	# and settles back, pivoting around the feet.

	var rest = _idle_sprite_scale
	var base = _idle_sprite_position
	var half = period / 2.0
	var stretch = 0.035

	# Scaling happens around the sprite center, so lift the sprite
	# half the added height to keep the feet planted.
	var rise = sprite.get_rect().size.y * rest.y * stretch / 2.0

	_idle_tween = create_tween().set_loops()

	_idle_tween.tween_property(sprite, "scale:y", rest.y * (1.0 + stretch), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "scale:x", rest.x * (1.0 - stretch * 0.4), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "position:y", base.y - rise, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_idle_tween.chain().tween_property(sprite, "scale:y", rest.y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "scale:x", rest.x, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "position:y", base.y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_wobble(period):
	# Slime-style squash and stretch, compensating the position so
	# the base stays planted on the ground.

	var rest = _idle_sprite_scale
	var base = _idle_sprite_position
	var half = period / 2.0
	var squish = 0.05

	var half_height = sprite.get_rect().size.y * rest.y / 2.0
	var sink = half_height * squish

	_idle_tween = create_tween().set_loops()

	_idle_tween.tween_property(sprite, "scale:y", rest.y * (1.0 - squish), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "scale:x", rest.x * (1.0 + squish * 0.8), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "position:y", base.y + sink, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_idle_tween.chain().tween_property(sprite, "scale:y", rest.y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "scale:x", rest.x, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.parallel().tween_property(sprite, "position:y", base.y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func equip_gear(gear_list):

	for item in gear_list:

		if item.texture == null:
			continue

		var piece = Sprite2D.new()
		piece.texture = item.texture
		piece.position = item.offset
		piece.scale = Vector2(item.scale, item.scale)
		piece.rotation_degrees = item.rotation_degrees

		# The shield arm faces the enemy, strapped outside the armor.
		if item.slot == GearDefinition.Slot.OFF_HAND:
			piece.z_index = 1

		if item.slot == GearDefinition.Slot.MAIN_HAND and arm_pivot:
			# Weapon goes into the hand so it swings with the arm.
			# Gear offsets are body-local, so re-express relative to the pivot.
			piece.position = item.offset - arm_pivot.position
			# Layered above the shield (z 1) but below the arm (z 2),
			# so the fist grips the hilt while the blade clears the shield.
			piece.z_index = 1
			arm_pivot.add_child(piece)
		else:
			sprite.add_child(piece)

		if item.slot == GearDefinition.Slot.MAIN_HAND:
			weapon_node = piece
			weapon_type = item.weapon_type

func play_windup():

	if attack_texture == null:
		return

	_stop_idle()

	sprite.texture = attack_texture
	sprite.region_enabled = false
	sprite.scale = _idle_sprite_scale * attack_texture_scale

	await get_tree().create_timer(0.35).timeout

func end_windup():

	sprite.texture = _idle_texture
	sprite.region_enabled = _idle_region_enabled
	sprite.scale = _idle_sprite_scale

	if _idle_tween == null:
		_start_idle()

func jump_to(target_position):

	# The hop animates the sprite directly, so pause the idle motion.
	_stop_idle()

	var move = create_tween()
	move.set_trans(Tween.TRANS_QUAD)
	move.set_ease(Tween.EASE_OUT)
	move.tween_property(self, "position", target_position, 0.25)

	# Sprite hops in an arc while the actor slides to its destination.
	var hop = create_tween()
	hop.tween_property(sprite, "position:y", -60.0, 0.125) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	hop.tween_property(sprite, "position:y", 60.0, 0.125) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).as_relative()

	await move.finished

	if _idle_tween == null:
		_start_idle()

func play_attack():

	end_windup()

	if arm_pivot and weapon_node and weapon_node.get_parent() == arm_pivot:
		if weapon_type == GearDefinition.WeaponType.BOW:
			await play_bow_attack()
		else:
			await play_arm_attack()
		return

	swing_weapon()

	var original = position

	var tween = create_tween()

	tween.tween_property(
		self,
		"position",
		original + Vector2(20 * attack_direction, 0),
		0.1
	)

	tween.tween_property(
		self,
		"position",
		original,
		0.1
	)

func play_arm_attack():
	# Raise the arm up over the shoulder, then chop down through the
	# target. Returns at the moment of impact; the arm settles back
	# to rest afterwards on its own.

	var dir = attack_direction
	var heavy = weapon_type == GearDefinition.WeaponType.TWO_HANDED
	var raise_time = 0.35 if heavy else 0.25

	var raise = create_tween()
	raise.tween_property(
		arm_pivot, "rotation_degrees", 155.0 * dir, raise_time
	).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await raise.finished

	_spawn_swing_trail(0.15)
	UiSounds.play(SWING_SOUND, "SFX", -6.0, randf_range(0.9, 1.1))

	var chop = create_tween()
	chop.tween_property(
		arm_pivot, "rotation_degrees", 185.0 * dir, 0.12
	).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await chop.finished

	var settle = create_tween()
	settle.tween_property(
		arm_pivot, "rotation_degrees", 20.0 * dir, 0.25
	).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func play_bow_attack():
	# Raise the bow arm level to aim at the target, hold the draw a
	# beat, then return at the moment of release; the arm settles
	# back to rest on its own afterwards.

	var dir = attack_direction

	var aim = create_tween()
	aim.tween_property(
		arm_pivot, "rotation_degrees", -90.0 * dir, 0.25
	).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await aim.finished

	await get_tree().create_timer(0.2).timeout

	UiSounds.play(BOW_SOUND, "SFX", -8.0, randf_range(0.9, 1.1))

	var settle = create_tween()
	settle.tween_property(
		arm_pivot, "rotation_degrees", 90.0 * dir, 0.3
	).as_relative().set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT).set_delay(0.15)

func _spawn_swing_trail(duration):
	# Fading afterimages of the weapon while it swings.

	var steps = int(duration / 0.03)

	for i in steps:
		if weapon_node:
			var ghost = Sprite2D.new()
			ghost.texture = weapon_node.texture
			ghost.modulate = Color(1, 1, 1, 0.4)
			ghost.z_index = 1
			get_parent().add_child(ghost)
			ghost.global_transform = weapon_node.global_transform

			var fade = ghost.create_tween()
			fade.tween_property(ghost, "modulate:a", 0.0, 0.18)
			fade.tween_callback(ghost.queue_free)

		await get_tree().create_timer(0.03).timeout

func swing_weapon():
	# Simple weapon-only swing for actors without an arm rig.

	if weapon_node == null:
		return

	var dir = attack_direction
	var tween = create_tween()

	tween.tween_property(
		weapon_node, "rotation_degrees", 110.0 * dir, 0.12
	).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		weapon_node, "rotation_degrees", -110.0 * dir, 0.2
	).as_relative()

func play_hit():

	modulate = Color(1.5, 0.5, 0.5)

	await get_tree().create_timer(0.08).timeout

	modulate = Color.WHITE

func play_death():

	end_windup()
	_stop_idle()

	if animation_player.has_animation("death"):
		animation_player.play("death")
		await animation_player.animation_finished
	elif death_style == DeathStyle.SQUASH:
		await _death_squash()
	else:
		await _death_fall()

func _death_fall():
	# Topple over backwards, pivoting around the feet, then fade out.

	var half_height = sprite.get_rect().size.y * sprite.scale.y / 2.0

	var fall = create_tween()
	fall.set_parallel(true)
	fall.tween_property(
		sprite, "rotation_degrees", -90.0 * attack_direction, 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(
		sprite,
		"position",
		sprite.position + Vector2(
			-half_height * attack_direction, half_height
		),
		0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await fall.finished
	await _death_fade()

func _death_squash():
	# Flatten into a puddle, then fade out.

	var half_height = sprite.get_rect().size.y * sprite.scale.y / 2.0

	var squash = create_tween()
	squash.set_parallel(true)
	squash.tween_property(
		sprite, "scale", Vector2(sprite.scale.x * 1.5, sprite.scale.y * 0.15), 0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	squash.tween_property(
		sprite, "position:y", sprite.position.y + half_height * 0.85, 0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await squash.finished
	await _death_fade()

func _death_fade():

	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade.finished

func setup_spawn(p_entity_id):

	entity_id = p_entity_id
