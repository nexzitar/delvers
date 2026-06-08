extends Node
class_name TheaterController

const DEFAULT_DELVER = preload(
	"res://resources/heroes/default_delver.tres"
)

const GREEN_SLIME = preload(
	"res://resources/enemies/green_slime.tres"
)


var actors = {}

var slash_scene = preload("res://art/effects/slash.tscn")
var combat_result: CombatResult

func play(result: CombatResult):

	combat_result = result

	for event in result.combat_log.events:

		await play_event(event)

		
func play_event(event):

	match event.type:

		CombatEvent.EventType.SPAWN:
			play_spawn(event)

		CombatEvent.EventType.DAMAGE:
			await play_damage(event)

		CombatEvent.EventType.DEATH:
			await play_death(event)
			
func play_damage(event):
	
	var source = actors[event.source_id]
	var target = actors[event.target_id]


	source.play_attack()
	spawn_slash(source, target)
	await get_tree().create_timer(0.1).timeout
	target.play_hit()

	target.set_health(
		event.remaining_health,
		event.max_health
	)

	spawn_damage_number(
		target.global_position,
		event.amount
	)

	await get_tree().create_timer(0.5).timeout
	
func play_death(event):
	var target = actors[event.target_id]
	target.play_death()
	
func spawn_damage_number(position, amount):

	var label = Label.new()
	const OFFSET = 450
	const TEXTSIZE = 96
	label.text = str(amount)
	label.global_position = position
	label.position.y -= OFFSET
	label.position.x -= 10
	label.add_theme_font_size_override("font_size", TEXTSIZE)
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position.x += randf_range(-50, 50)

	add_child(label)

	var tween = create_tween()

	tween.tween_property(
		label,
		"position:y",
		position.y - 40,
		3.0
	)

	tween.parallel().tween_property(
		label,
		"modulate:a",
		0.0,
		1.0
	)

	await tween.finished

	label.queue_free()
	
	
func _ready():

	var combat = CombatState.new()
	
	
	combat.setup_combat(
		[DEFAULT_DELVER],[GREEN_SLIME, GREEN_SLIME]
	)
	
	

	while not combat.combat_over:
		combat.update(0.1)

	var result = combat.build_result()

	await play_combat(result)
	
func spawn_slash(source, target):

	var slash = slash_scene.instantiate()
	add_child(slash)
	slash.global_position = source.global_position
	slash.setup(source.attack_direction)

	var tween = create_tween()

	tween.tween_property(
		slash,
		"global_position",
		target.global_position,
		0.15
	)

func play_combat(result):

	await play(result)
		
func clear_battlefield():

	for actor in actors.values():
		actor.queue_free()

	actors.clear()
	
		
func play_spawn(event):

	var actor = event.template.actor_scene.instantiate()

	add_child(actor)

	actor.position = get_slot_position(
		event.team,
		event.formation_slot
	)

	actor.setup_spawn(
		event.entity_id,
		event.entity_name,
		event.current_health,
		event.max_health
	)

	actors[event.entity_id] = actor
	
func get_slot_position(team, formation_slot):

	var x

	if team == CombatEntity.Team.HERO:
		x = 350
	else:
		x = 1250

	return Vector2(
		x,
		400 + formation_slot * 150
	)
