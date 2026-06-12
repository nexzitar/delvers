extends Node
class_name TheaterController

const GREEN_SLIME = preload(
	"res://resources/enemies/green_slime.tres"
)

const GOBLIN_ARCHER = preload(
	"res://resources/enemies/goblin_archer.tres"
)

const MELEE_STRIKE_DISTANCE = 140

const MELEE_HIT_SOUND = preload("res://audio/melee_hit.wav")
const ARROW_HIT_SOUND = preload("res://audio/arrow_hit.wav")


@export var battlefield: BattlefieldLayout

## Y-sorted container the actors spawn into, so units lower on the
## screen draw in front of units behind them.
@export var actors_root: Node2D

@export var hero_sidebar: BattleSidebar
@export var enemy_sidebar: BattleSidebar

var actors = {}
var sidebars_by_entity = {}

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

	sidebars_by_entity[event.source_id].add_damage(
		event.source_id, event.amount, event.time
	)

	if is_projectile(event.skill):
		await play_ranged_attack(source, target, event)
	else:
		await play_melee_attack(source, target, event)

	await get_tree().create_timer(0.3).timeout

func is_projectile(skill):
	return (
		skill != null
		and skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
	)

func play_melee_attack(source, target, event):

	var home = source.position
	var strike_position = (
		target.position
		+ Vector2(-MELEE_STRIKE_DISTANCE * source.attack_direction, 0)
	)

	await source.jump_to(strike_position)
	await source.play_windup()

	# play_attack returns at the moment of impact.
	await source.play_attack()
	spawn_slash(source, target)
	await get_tree().create_timer(0.05).timeout

	apply_hit(target, event)
	await get_tree().create_timer(0.2).timeout

	await source.jump_to(home)

func play_ranged_attack(source, target, event):

	await source.play_windup()

	# play_attack returns at the moment of release.
	await source.play_attack()
	await spawn_projectile(source, target, event.skill)
	apply_hit(target, event)

func apply_hit(target, event):

	var hit_sound = (
		ARROW_HIT_SOUND if is_projectile(event.skill)
		else MELEE_HIT_SOUND
	)
	UiSounds.play(hit_sound, "SFX", -4.0, randf_range(0.9, 1.1))

	target.play_hit()

	sidebars_by_entity[event.target_id].set_health(
		event.target_id,
		event.remaining_health,
		event.max_health
	)

	spawn_damage_number(
		target.global_position,
		event.amount
	)

func spawn_projectile(source, target, skill):

	var projectile = skill.projectile_scene.instantiate()
	add_child(projectile)

	# Launch from the actor's bow position, aim at the target's torso.
	var from = source.global_position + Vector2(
		source.projectile_origin.x * source.attack_direction,
		source.projectile_origin.y
	)
	var to = target.global_position + Vector2(0, -20)

	projectile.global_position = from
	projectile.rotation = (to - from).angle()

	var tween = create_tween()
	tween.tween_property(projectile, "global_position", to, 0.3)

	await tween.finished
	projectile.queue_free()
	
func play_death(event):

	var target = actors[event.target_id]

	sidebars_by_entity[event.target_id].mark_dead(event.target_id)

	await target.play_death()

	actors.erase(event.target_id)
	target.queue_free()
	
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

	# Wait one frame so sibling nodes (e.g. BattlefieldLayout) finish _ready
	# before playback starts querying them.
	await get_tree().process_frame

	var combat = CombatState.new()

	combat.setup_combat(
		PlayerRoster.heroes,
		roll_encounter()
	)

	while not combat.combat_over:
		combat.update(0.1)

	var result = combat.build_result()

	await play_combat(result)

	PlayerRoster.battles_fought += 1
	PlayerRoster.last_battle_won = result.victory
	if result.victory:
		PlayerRoster.adventures_completed += 1

	await show_battle_result(result.victory)
	await get_tree().create_timer(2.2).timeout

	get_tree().change_scene_to_file("res://scenes/camp/camp.tscn")

## A random pack of enemies for this adventure.
func roll_encounter() -> Array:

	var pool = [GREEN_SLIME, GREEN_SLIME, GOBLIN_ARCHER]
	var encounter = []

	for i in randi_range(2, 4):
		encounter.append(pool.pick_random())

	return encounter

func show_battle_result(victory):

	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var label = Label.new()
	label.text = "Victory!" if victory else "Defeat..."
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(
		"font", load("res://art/fonts/Herculanum.ttf")
	)
	label.add_theme_font_size_override("font_size", 150)
	label.add_theme_color_override(
		"font_color",
		Color(0.85, 0.7, 0.25) if victory else Color(0.7, 0.2, 0.15)
	)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 18)
	label.modulate.a = 0.0
	layer.add_child(label)

	var fade = create_tween()
	fade.tween_property(label, "modulate:a", 1.0, 0.6)
	await fade.finished
	
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

	actors_root.add_child(actor)

	actor.position = get_slot_position(
		event.team,
		event.formation_slot
	)

	actor.setup_spawn(event.entity_id)
	actor.equip_gear(event.gear)

	actors[event.entity_id] = actor

	var sidebar = (
		hero_sidebar if event.team == CombatEntity.Team.HERO
		else enemy_sidebar
	)
	sidebar.add_unit(event)
	sidebars_by_entity[event.entity_id] = sidebar
	
func get_slot_position(team, formation_slot):

	if team == CombatEntity.Team.HERO:
		return battlefield.hero_slot(formation_slot)

	return battlefield.enemy_slot(formation_slot)
