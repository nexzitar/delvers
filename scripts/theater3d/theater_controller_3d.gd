extends Node3D
class_name TheaterController3D

## 3D battle theater: runs the headless sim, then replays its event log
## in real time. Events are dispatched from a pre-built timeline (log
## events plus derived animation cues, so melee contact lands ON the
## DAMAGE event); rig poses are driven continuously from _process.

const TargetArrow3D = preload("res://scripts/theater3d/target_arrow_3d.gd")
const AoeTelegraph3D = preload("res://scripts/theater3d/aoe_telegraph_3d.gd")
const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")
const SlimeRig = preload("res://scripts/theater3d/slime_rig.gd")

const GREEN_SLIME = preload("res://resources/enemies/green_slime.tres")
const GOBLIN_ARCHER = preload("res://resources/enemies/goblin_archer.tres")
const MELEE_HIT_SOUND = preload("res://audio/melee_hit.wav")
const ARROW_HIT_SOUND = preload("res://audio/arrow_hit.wav")
const FONT = preload("res://art/fonts/Herculanum.ttf")

const WORLD_SCALE := 1.0 / 32.0
const MOVE_TWEEN_T := 0.15
const STRIDE_RATE := 7.0
## pose_swing / slime pose_attack contact points, for cue scheduling.
const SWING_LEAD := 0.475
const SLIME_LEAD := 0.4
## Angled off the battle axis so the line of fight runs diagonally
## across the screen instead of hiding under the sidebar panels.
const CAMERA_OFFSET := Vector3(0.55, 0.63, 0.76)

const HERO_ARROW_COLOR := Color(0.92, 0.76, 0.3, 0.75)
const ENEMY_ARROW_COLOR := Color(0.85, 0.32, 0.25, 0.75)

const STATUS_TEXT := {
	"frost_nova_root": "Rooted!",
	"hamstring_slow": "Slowed!",
	"charge_stun": "Stunned!",
}

var actors := {}
var arrows := {}
var sidebars_by_entity := {}
var hero_sidebar: BattleSidebar
var enemy_sidebar: BattleSidebar
var camera: Camera3D

var combat_result: CombatResult
var _timeline := []
var _cast_durations := {}
var _clock := 0.0
var _cursor := 0
var _playing := false
var _wrapping_up := false

static func to_world(sim_pos: Vector2) -> Vector3:
	return Vector3(sim_pos.x * WORLD_SCALE, 0.0, sim_pos.y * WORLD_SCALE)

const ARENA_POOL := [
	"res://resources/arenas/open_arena.tres",
	"res://resources/arenas/pillared_hall.tres",
	"res://resources/arenas/broken_wall.tres",
	"res://resources/arenas/scattered_rocks.tres",
]

## Harness hook: force a specific arena (set before adding to the tree).
var forced_arena_path := ""

func _ready():
	get_viewport().msaa_3d = Viewport.MSAA_4X

	var room = maxi(1, PlayerRoster.delve_room)
	var combat = CombatState.new()
	# Rooms deepen: bigger packs, higher enemy levels.
	combat.enemy_level_bonus = (room - 1) / 4
	combat.setup_combat(PlayerRoster.heroes, roll_encounter(room), _pick_arena(room))
	while not combat.combat_over:
		combat.update(0.1)
	combat_result = combat.build_result()

	_setup_world(combat.arena)
	_setup_ui()
	_show_room_banner(room)
	_build_timeline(combat_result.combat_log)
	_playing = true

## A random pack of enemies, growing with the delve's depth.
func roll_encounter(room: int) -> Array:
	var pool = [GREEN_SLIME, GREEN_SLIME, GOBLIN_ARCHER]
	var low = clampi(2 + (room - 1) / 4, 2, 4)
	var high = clampi(3 + (room - 1) / 2, 3, 6)
	var encounter = []
	for i in randi_range(low, high):
		encounter.append(pool.pick_random())
	return encounter

## The first room is always the open field; deeper rooms draw from the
## full arena pool.
func _pick_arena(room: int) -> BattleArena:
	if forced_arena_path != "":
		return load(forced_arena_path)
	if room <= 1:
		return load(ARENA_POOL[0])
	return load(ARENA_POOL.pick_random())

# --- Replay loop --------------------------------------------------------

func _process(delta):
	if not _playing:
		return
	_clock += delta
	while _cursor < _timeline.size() and _timeline[_cursor].time <= _clock:
		_dispatch(_timeline[_cursor])
		_cursor += 1
	_update_actors(delta)
	_update_arrows()
	_update_camera(delta)
	if _cursor >= _timeline.size() and not _wrapping_up:
		_wrapping_up = true
		_finish_battle()

## Log events plus derived cues: melee swings start ahead of their
## DAMAGE so the blade lands on the beat, and casts learn how long the
## sim wind-up actually was so the draw animation matches.
func _build_timeline(log):
	var is_slime := {}
	for event in log.events:
		if event.type == CombatEvent.EventType.SPAWN \
				and event.team == CombatEntity.Team.ENEMY:
			is_slime[event.entity_id] = event.template.enemy_id == "green_slime"

	var events: Array = log.events
	for i in events.size():
		var event = events[i]
		_timeline.append({"time": event.time, "kind": "event", "event": event})
		match event.type:
			CombatEvent.EventType.DAMAGE:
				if event.skill == null or event.skill.delivery_type == SkillDefinition.DeliveryType.MELEE:
					var lead = SLIME_LEAD if is_slime.get(event.source_id, false) else SWING_LEAD
					_timeline.append({
						"time": maxf(0.0, event.time - lead),
						"kind": "swing", "id": event.source_id,
						"off": event.off_hand,
					})
			CombatEvent.EventType.CAST_START:
				var duration := 0.3
				for j in range(i + 1, events.size()):
					if events[j].type == CombatEvent.EventType.CAST_FINISH \
							and events[j].source_id == event.source_id:
						duration = maxf(0.1, events[j].time - event.time)
						break
				if not _cast_durations.has(event.source_id):
					_cast_durations[event.source_id] = []
				_cast_durations[event.source_id].append(duration)
	_timeline.sort_custom(func(a, b): return a.time < b.time)

func _dispatch(item):
	if item.kind == "swing":
		var state = actors.get(item.id)
		if state and state.mode != "dead":
			state.mode = "attack_off" if item.get("off", false) else "attack"
			state.anim_t = 0.0
		return
	_play_event(item.event)

func _play_event(event):
	match event.type:
		CombatEvent.EventType.SPAWN:
			_play_spawn(event)
		CombatEvent.EventType.MOVE:
			_play_move(event)
		CombatEvent.EventType.FACE:
			var state = actors.get(event.entity_id)
			if state:
				state.yaw_target = _yaw_of(event.facing)
		CombatEvent.EventType.TARGET:
			var state = actors.get(event.source_id)
			if state:
				state.target_id = event.target_id
		CombatEvent.EventType.CAST_START:
			_play_cast_start(event)
		CombatEvent.EventType.CAST_FINISH:
			pass  # release timing is baked into the shoot pose speed
		CombatEvent.EventType.DAMAGE:
			_play_damage(event)
		CombatEvent.EventType.HEAL:
			_play_heal(event)
		CombatEvent.EventType.DEATH:
			_play_death(event)
		CombatEvent.EventType.BUFF_APPLIED:
			_play_buff(event)
		CombatEvent.EventType.TELEGRAPH:
			var telegraph = AoeTelegraph3D.new(
				event.telegraph_radius * WORLD_SCALE, event.telegraph_duration
			)
			add_child(telegraph)
			telegraph.position = to_world(event.position)

func _play_spawn(event):
	var rig = ActorFactory3D.build_from_spawn(event)
	add_child(rig)
	rig.position = to_world(event.position)
	rig.rotation.y = _yaw_of(event.facing)

	actors[event.entity_id] = {
		"rig": rig,
		"is_slime": rig is SlimeRig,
		"team": event.team,
		"mode": "idle",
		"anim_t": 0.0,
		"anim_speed": 1.0,
		"walk_phase": 0.0,
		"walk_until": -1.0,
		"move_from": rig.position,
		"move_to": rig.position,
		"move_progress": 1.0,
		"yaw_target": rig.rotation.y,
		"target_id": -1,
		"shoot_dist": 2.0,
	}

	var sidebar = (
		hero_sidebar if event.team == CombatEntity.Team.HERO
		else enemy_sidebar
	)
	sidebar.add_unit(event)
	sidebars_by_entity[event.entity_id] = sidebar

func _play_move(event):
	var state = actors.get(event.entity_id)
	if state == null or state.mode == "dead":
		return
	state.move_from = state.rig.position
	state.move_to = to_world(event.position)
	state.move_progress = 0.0
	state.walk_until = _clock + 0.3

func _play_cast_start(event):
	var state = actors.get(event.source_id)
	if state == null or state.mode == "dead":
		return
	state.target_id = event.target_id
	var queue = _cast_durations.get(event.source_id, [])
	var duration = queue.pop_front() if not queue.is_empty() else 0.3
	if state.rig is DelverRig:
		state.mode = "shoot"
		state.anim_t = 0.0
		# Scale the pose so the arrow releases exactly at CAST_FINISH.
		state.anim_speed = (0.62 * DelverRig.SHOOT_T) / duration
		var target = actors.get(event.target_id)
		if target:
			state.shoot_dist = (
				state.rig.position.distance_to(target.rig.position)
				/ state.rig.scale.x
			)

func _play_damage(event):
	var target = actors.get(event.target_id)
	if target == null:
		return
	var sidebar = sidebars_by_entity.get(event.source_id)
	if sidebar:
		sidebar.add_damage(event.source_id, event.amount, event.time)
	sidebars_by_entity[event.target_id].set_health(
		event.target_id, event.remaining_health, event.max_health
	)
	var ranged = (
		event.skill != null
		and event.skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
	)
	UiSounds.play(
		ARROW_HIT_SOUND if ranged else MELEE_HIT_SOUND,
		"SFX", -4.0, randf_range(0.9, 1.1)
	)
	_spawn_floating_text(
		target.rig.position, str(event.amount), Color(0.9, 0.2, 0.15)
	)

func _play_heal(event):
	var target = actors.get(event.target_id)
	if target == null:
		return
	sidebars_by_entity[event.target_id].set_health(
		event.target_id, event.remaining_health, event.max_health
	)
	_spawn_floating_text(
		target.rig.position, "+%d" % event.amount, Color(0.35, 0.85, 0.3)
	)

func _play_death(event):
	var state = actors.get(event.target_id)
	if state == null:
		return
	state.mode = "dead"
	state.anim_t = 0.0
	sidebars_by_entity[event.target_id].mark_dead(event.target_id)
	var arrow = arrows.get(event.target_id)
	if arrow:
		arrow.queue_free()
		arrows.erase(event.target_id)

func _play_buff(event):
	var target = actors.get(event.target_id)
	if target == null or not STATUS_TEXT.has(event.status_id):
		return
	_spawn_floating_text(
		target.rig.position + Vector3(0, 0.35, 0),
		STATUS_TEXT[event.status_id], Color(0.55, 0.75, 1.0)
	)

# --- Continuous animation ----------------------------------------------

func _update_actors(delta):
	for state in actors.values():
		var rig = state.rig

		if state.move_progress < 1.0 and state.mode != "dead":
			state.move_progress = minf(
				1.0, state.move_progress + delta / MOVE_TWEEN_T
			)
			rig.position = state.move_from.lerp(state.move_to, state.move_progress)

		if state.mode != "dead":
			rig.rotation.y = lerp_angle(
				rig.rotation.y, state.yaw_target, minf(1.0, delta * 10.0)
			)

		match state.mode:
			"dead":
				state.anim_t += delta
				rig.pose_death(state.anim_t)
			"attack", "attack_off":
				state.anim_t += delta
				if state.is_slime:
					rig.pose_attack(state.anim_t)
					if state.anim_t >= SlimeRig.ATTACK_T:
						state.mode = "idle"
				else:
					if state.mode == "attack_off":
						rig.pose_swing_off(state.anim_t)
					else:
						rig.pose_swing(state.anim_t)
					if state.anim_t >= DelverRig.SWING_T:
						state.mode = "idle"
			"shoot":
				state.anim_t += delta * state.anim_speed
				rig.pose_shoot(state.anim_t, state.shoot_dist)
				if state.anim_t >= DelverRig.SHOOT_T:
					state.mode = "idle"
			_:
				if _clock < state.walk_until:
					state.walk_phase += delta * STRIDE_RATE
					if state.is_slime:
						rig.pose_travel(state.walk_phase / STRIDE_RATE)
					else:
						rig.pose_walk(state.walk_phase)
				else:
					rig.pose_idle(_clock)

func _update_arrows():
	for entity_id in actors:
		var state = actors[entity_id]
		var target = actors.get(state.target_id)
		var visible_arrow = (
			state.mode != "dead"
			and target != null and target.mode != "dead"
		)
		if not visible_arrow:
			if arrows.has(entity_id):
				arrows[entity_id].visible = false
			continue
		if not arrows.has(entity_id):
			var color = (
				HERO_ARROW_COLOR if state.team == CombatEntity.Team.HERO
				else ENEMY_ARROW_COLOR
			)
			var arrow = TargetArrow3D.new(color)
			add_child(arrow)
			arrows[entity_id] = arrow
		arrows[entity_id].visible = true
		arrows[entity_id].point(state.rig.position, target.rig.position)

## The camera frames all living combatants: centered on their bounding
## box, pulled back far enough to fit the spread.
func _update_camera(delta):
	var low := Vector3(INF, 0, INF)
	var high := Vector3(-INF, 0, -INF)
	var count := 0
	for state in actors.values():
		if state.mode != "dead":
			var p = state.rig.position
			low.x = minf(low.x, p.x)
			low.z = minf(low.z, p.z)
			high.x = maxf(high.x, p.x)
			high.z = maxf(high.z, p.z)
			count += 1
	if count == 0:
		return
	var center = (low + high) * 0.5
	var spread = (high - low).length()
	# Generous distance so the fight stays inside the strip between the
	# sidebar panels rather than hiding behind them.
	var distance = clampf(4.0 + spread * 0.95, 8.0, 16.0)
	var goal = center + CAMERA_OFFSET.normalized() * distance
	var blend = 1.0 - exp(-2.5 * delta)
	camera.position = camera.position.lerp(goal, blend)
	camera.look_at(center + Vector3(0, 0.4, 0))

# --- Presentation helpers -----------------------------------------------

func _yaw_of(facing: Vector2) -> float:
	return atan2(facing.x, facing.y)

func _spawn_floating_text(at: Vector3, text: String, color: Color):
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 96
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at + Vector3(randf_range(-0.15, 0.15), 1.5, 0)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

## Fades a "Room N of 10" banner at the top as the fight opens.
func _show_room_banner(room: int):
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	var label := Label.new()
	label.text = "Room %d of %d" % [room, PlayerRoster.DELVE_LENGTH]
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_top = 40
	label.offset_bottom = 110
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.42))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.modulate.a = 0.0
	layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)

func _finish_battle():
	await get_tree().create_timer(1.4).timeout

	var room = maxi(1, PlayerRoster.delve_room)
	PlayerRoster.battles_fought += 1
	PlayerRoster.last_battle_won = combat_result.victory

	if not combat_result.victory:
		RosterSave.save(PlayerRoster)
		await _show_battle_result(false)
		await get_tree().create_timer(1.2).timeout
		_show_summary(
			"The Party Falls...",
			"%d room%s cleared. Their spoils make it home." % [
				room - 1, "" if room == 2 else "s"
			]
		)
		return

	var found = LootTable.roll_room_loot(room)
	PlayerRoster.delve_loot.append_array(found)

	if room >= PlayerRoster.DELVE_LENGTH:
		PlayerRoster.adventures_completed += 1
		RosterSave.save(PlayerRoster)
		await _show_battle_result(true)
		await get_tree().create_timer(1.2).timeout
		_show_summary(
			"Delve Complete!",
			"All %d rooms conquered." % PlayerRoster.DELVE_LENGTH
		)
		return

	RosterSave.save(PlayerRoster)
	await _show_battle_result(true)
	await get_tree().create_timer(1.2).timeout
	_show_room_cleared(room, found)

func _show_room_cleared(room: int, found: Array):
	var panel := DelvePanel.new()
	add_child(panel)
	panel.setup(
		"Room %d Cleared!" % room,
		"The pouch holds %d item%s. Deeper rooms hold deadlier foes." % [
			PlayerRoster.delve_loot.size(),
			"" if PlayerRoster.delve_loot.size() == 1 else "s",
		],
		found,
		"Delve Deeper",
		"Retreat with Spoils"
	)
	panel.primary_pressed.connect(func():
		PlayerRoster.delve_room += 1
		SceneFlow.change_scene("res://scenes/theater/battle_theater_3d.tscn"))
	panel.secondary_pressed.connect(_bank_and_return)

## Final spoils screen: everything gathered this delve, then camp.
func _show_summary(title: String, subtitle: String):
	var panel := DelvePanel.new()
	add_child(panel)
	panel.setup(title, subtitle, PlayerRoster.delve_loot, "Return to Camp")
	panel.primary_pressed.connect(_bank_and_return)

func _bank_and_return():
	PlayerRoster.bank_delve_loot()
	SceneFlow.change_scene("res://scenes/camp/camp.tscn")

func _show_battle_result(victory):
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var label = Label.new()
	label.text = "Victory!" if victory else "Defeat..."
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
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

# --- World & UI ---------------------------------------------------------

func _setup_world(arena):
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("23242c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c0d6")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.35
	add_child(fill)

	var center = to_world(Vector2(
		arena.width * arena.tile_size * 0.5,
		arena.height * arena.tile_size * 0.5
	))

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(arena.width + 40, arena.height + 40)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("55584a")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = center
	add_child(ground)

	# Blocked tiles rise as stone pillars: the same cells the sim's
	# pathfinding and line of sight respect.
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color("5b5e57")
	pillar_mat.roughness = 1.0
	for tile in arena.blocked_tiles:
		var pillar := BoxMesh.new()
		var wobble = 0.15 * ((tile.x * 7 + tile.y * 13) % 5) / 4.0
		pillar.size = Vector3(1.0, 1.3 + wobble, 1.0)
		var mesh := MeshInstance3D.new()
		mesh.mesh = pillar
		mesh.material_override = pillar_mat
		var base = to_world(Vector2(
			(tile.x + 0.5) * arena.tile_size,
			(tile.y + 0.5) * arena.tile_size
		))
		mesh.position = base + Vector3(0, pillar.size.y * 0.5, 0)
		add_child(mesh)

	# Deterministic scatter so the field reads as a place.
	for i in 14:
		var a := i * 2.4 + 0.7
		var mesh := MeshInstance3D.new()
		var prop_mat := StandardMaterial3D.new()
		prop_mat.roughness = 1.0
		if i % 2 == 0:
			var rock := SphereMesh.new()
			rock.radius = 0.08 + 0.02 * (i % 3)
			rock.height = rock.radius * 1.2
			rock.radial_segments = 7
			rock.rings = 4
			mesh.mesh = rock
			prop_mat.albedo_color = Color("6e7266")
		else:
			var tuft := BoxMesh.new()
			tuft.size = Vector3(0.05, 0.14, 0.05)
			mesh.mesh = tuft
			mesh.position.y = 0.07
			prop_mat.albedo_color = Color("5e7a4a")
		mesh.material_override = prop_mat
		mesh.position += center + Vector3(7.5 * cos(a), 0, 4.6 * sin(a))
		add_child(mesh)

	camera = Camera3D.new()
	camera.fov = 35
	camera.position = center + CAMERA_OFFSET.normalized() * 13.0
	add_child(camera)
	camera.look_at(center)

func _setup_ui():
	var layer := CanvasLayer.new()
	add_child(layer)

	hero_sidebar = BattleSidebar.new()
	hero_sidebar.title = "Delvers"
	hero_sidebar.position = Vector2(12, 12)
	hero_sidebar.size = Vector2(260, 876)
	layer.add_child(hero_sidebar)

	enemy_sidebar = BattleSidebar.new()
	enemy_sidebar.title = "Enemies"
	enemy_sidebar.position = Vector2(1328, 12)
	enemy_sidebar.size = Vector2(260, 876)
	layer.add_child(enemy_sidebar)
