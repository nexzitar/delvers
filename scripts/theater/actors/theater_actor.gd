extends Node2D
class_name TheaterActor

@onready var sprite = $Sprite2D
@onready var health_bar = $NameLabel/HealthBar
@onready var animation_player = $AnimationPlayer
@onready var hp_label = $NameLabel/HealthBar/HP
@onready var name_label = $NameLabel
@export var attack_direction := 1


var max_health := 10
var current_health := 10
var entity_id : int

func setup(entity):

	entity_id = entity.entity_id
	current_health = entity.current_health
	max_health = entity.template.base_health

	print(
		"SETUP:",
		entity.entity_name,
		" HP:",
		current_health,
		"/",
		max_health
	)

	set_health(
		current_health,
		max_health
	)

	name_label.text = entity.entity_name
	
func set_health(current, maxhp):

	current_health = current
	max_health = maxhp

	health_bar.max_value = max_health
	health_bar.value = current_health

	hp_label.text = str(current_health) + "/" + str(max_health)

func play_attack():

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

func play_hit():

	modulate = Color(1.5, 0.5, 0.5)

	await get_tree().create_timer(0.08).timeout

	modulate = Color.WHITE

func play_death():

	if animation_player.has_animation("death"):
		animation_player.play("death")
	else:
		modulate.a = 0.0

func setup_spawn(
	p_entity_id,
	p_entity_name,
	p_current_health,
	p_max_health
):

	entity_id = p_entity_id

	current_health = p_current_health
	max_health = p_max_health

	set_health(
		current_health,
		max_health
	)

	name_label.text = p_entity_name
