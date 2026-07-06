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
const SLIME_KING = preload("res://resources/enemies/slime_king.tres")
const GOBLIN_WARRIOR = preload("res://resources/enemies/goblin_warrior.tres")
const VENOMOUS_SPIDER = preload("res://resources/enemies/venomous_spider.tres")
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

## Persistent badge shown over the head while a status runs.
const STATUS_ICON := {
	"poison_virulent": "res://art/status/status_poison.png",
	"venom_bite_poison": "res://art/status/status_poison.png",
	"thunderclap_daze": "res://art/status/status_daze.png",
	"charge_stun": "res://art/status/status_stun.png",
	"frost_nova_root": "res://art/status/status_root.png",
	"web_root": "res://art/status/status_root.png",
	"hamstring_slow": "res://art/status/status_chill.png",
	"slow_frostforged": "res://art/status/status_chill.png",
	"renew_hot": "res://art/status/status_renew.png",
	"shield_wall": "res://art/status/status_fortify.png",
}

const STATUS_TEXT := {
	"frost_nova_root": "Rooted!",
	"hamstring_slow": "Slowed!",
	"charge_stun": "Stunned!",
	"poison_virulent": "Poisoned!",
	"slow_frostforged": "Chilled!",
	"venom_bite_poison": "Poisoned!",
	"web_root": "Webbed!",
	"renew_hot": "Renewed!",
	"shield_wall": "Shield Wall!",
	"thunderclap_daze": "Dazed!",
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

## The dungeon being delved (drives encounters, loot band, and theme).
var _dungeon_def: DungeonDefinition = null

func dungeon() -> DungeonDefinition:
	if _dungeon_def == null:
		_dungeon_def = load(RosterSave.DUNGEON_PATHS.get(
			PlayerRoster.current_dungeon,
			"res://resources/dungeons/darkwood.tres"
		))
	return _dungeon_def

## Roster indices of the heroes fielded this room (attrition can
## bench the fallen for the rest of the delve).
var _party_indices := []

func _ready():
	get_viewport().msaa_3d = Viewport.MSAA_4X

	var room = maxi(1, PlayerRoster.delve_room)

	# Attrition: health carries between rooms; downed heroes sit out.
	var party := []
	var entry_health := {}
	_party_indices = []
	for i in PlayerRoster.heroes.size():
		var carried = PlayerRoster.delve_health.get(i, -1)
		if carried == 0:
			continue
		if carried > 0:
			entry_health[party.size()] = carried
		party.append(PlayerRoster.heroes[i])
		_party_indices.append(i)

	var combat = CombatState.new()
	combat.enemy_priority = PlayerRoster.enemy_priority.duplicate()
	# Rooms deepen: bigger packs, higher enemy levels.
	combat.enemy_level_bonus = (room - 1) / 4
	combat.setup_combat(party, roll_encounter(room), _pick_arena(room), entry_health)
	while not combat.combat_over:
		combat.update(0.1)
	combat_result = combat.build_result()

	# Win or lose, what walked out of the dark is now seen.
	PlayerRoster.record_seen(combat.enemies.map(
		func(e): return e.template.enemy_id
	))

	# Record how the party came out of the fight.
	for k in combat.heroes.size():
		PlayerRoster.delve_health[_party_indices[k]] = combat.heroes[k].current_health

	_setup_world(combat.arena)
	_setup_ui()
	_show_room_banner(room)
	_build_timeline(combat_result.combat_log)
	_playing = true

## A random pack from the dungeon's pools, growing with depth. One
## guaranteed enemy anchors every room (the farmable identity), and
## the final room is the boss lair.
func roll_encounter(room: int) -> Array:
	var d = dungeon()
	if room >= d.length:
		return d.boss_pack.duplicate()
	# duplicate(): Array(typed) SHARES the resource's buffer — appends
	# would leak into the .tres and balloon every later encounter.
	var pool = d.pool_core.duplicate()
	if room >= d.deep_from:
		pool.append_array(d.pool_deep)
	var low = clampi(2 + (room - 1) / 4, 2, 4)
	var high = clampi(3 + (room - 1) / 2, 3, 6)
	var encounter = d.guaranteed.duplicate()
	var size = maxi(randi_range(low, high), encounter.size())
	for i in range(size - encounter.size()):
		encounter.append(pool.pick_random())
	return encounter

## The first room is always the open field, the boss lair too (a clean
## stage for the fight); rooms between draw from the full arena pool.
func _pick_arena(room: int) -> BattleArena:
	if forced_arena_path != "":
		return load(forced_arena_path)
	if room <= 1 or room >= dungeon().length:
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
			is_slime[event.entity_id] = event.template.enemy_id in ["green_slime", "slime_king", "venomous_spider"]

	var events: Array = log.events
	for i in events.size():
		var event = events[i]
		_timeline.append({"time": event.time, "kind": "event", "event": event})
		match event.type:
			CombatEvent.EventType.DAMAGE:
				if event.dot:
					continue
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
	if item.kind == "spin":
		var state = actors.get(item.id)
		if state and state.mode != "dead" and state.rig.has_method("pose_spin"):
			state.mode = "spin"
			state.anim_t = 0.0
		return
	if item.kind == "clap":
		var state = actors.get(item.id)
		if state and state.mode != "dead":
			if state.rig.has_method("pose_spellcast"):
				state.rig.pose_spellcast(0.5)
			_spawn_shockwave(state.rig.position)
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
		CombatEvent.EventType.BUFF_EXPIRED:
			_play_buff_expired(event)
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

	var badge_row := Node3D.new()
	rig.add_child(badge_row)
	badge_row.position = Vector3(0, 1.95, 0)

	actors[event.entity_id] = {
		"rig": rig,
		"badge_row": badge_row,
		"badges": {},
		"is_slime": rig.has_method("pose_attack"),
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
	# Hits on YOUR party glow red; your hits on the enemy read pale
	# gold — one glance tells who is bleeding.
	var incoming: bool = target.team == CombatEntity.Team.HERO
	if event.dot:
		# Poison ticks: a quiet purple number, no impact sound or swing.
		_spawn_floating_text(
			target.rig.position, str(event.amount),
			Color(0.85, 0.3, 0.55) if incoming else Color(0.7, 0.35, 0.85),
			1.0, event.target_id
		)
		return
	if event.dodged:
		# The swing whiffs: no impact sound, a pale sidestep note.
		_spawn_floating_text(
			target.rig.position, "Dodge!", Color(0.85, 0.85, 0.8),
			1.0, event.target_id
		)
		return
	var ranged = (
		event.skill != null
		and event.skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
	)
	UiSounds.play(
		ARROW_HIT_SOUND if ranged else MELEE_HIT_SOUND,
		"SFX", -4.0, randf_range(0.9, 1.1)
	)
	if event.blocked:
		_spawn_floating_text(
			target.rig.position, "%d (blocked)" % event.amount,
			Color(0.5, 0.7, 0.95), 1.0, event.target_id
		)
	elif event.crit:
		_spawn_floating_text(
			target.rig.position, "%d!" % event.amount,
			Color(1.0, 0.3, 0.15) if incoming else Color(1.0, 0.72, 0.15),
			1.45, event.target_id
		)
	else:
		_spawn_floating_text(
			target.rig.position, str(event.amount),
			Color(0.95, 0.25, 0.2) if incoming else Color(0.95, 0.88, 0.62),
			1.0, event.target_id
		)

func _play_heal(event):
	var target = actors.get(event.target_id)
	if target == null:
		return
	sidebars_by_entity[event.target_id].set_health(
		event.target_id, event.remaining_health, event.max_health
	)
	var caster_bar = sidebars_by_entity.get(event.source_id)
	if caster_bar and event.max_mana > 0:
		caster_bar.set_mana(event.source_id, event.current_mana, event.max_mana)
	_spawn_floating_text(
		target.rig.position, "+%d" % event.amount, Color(0.35, 0.85, 0.3),
		1.0, event.target_id
	)

func _play_death(event):
	var state = actors.get(event.target_id)
	if state == null:
		return
	state.mode = "dead"
	state.anim_t = 0.0
	for status_id in state.badges.keys():
		_remove_badge(state, status_id)
	sidebars_by_entity[event.target_id].mark_dead(event.target_id)
	var arrow = arrows.get(event.target_id)
	if arrow:
		arrow.queue_free()
		arrows.erase(event.target_id)

func _play_buff(event):
	var target = actors.get(event.target_id)
	if target == null:
		return
	if STATUS_TEXT.has(event.status_id):
		_spawn_floating_text(
			target.rig.position + Vector3(0, 0.35, 0),
			STATUS_TEXT[event.status_id], Color(0.55, 0.75, 1.0),
			1.0, event.target_id
		)
	_add_badge(target, event.status_id)

func _play_buff_expired(event):
	var target = actors.get(event.target_id)
	if target:
		_remove_badge(target, event.status_id)

## A little symbol rides above the head for as long as the status runs.
func _add_badge(state, status_id: String):
	if not STATUS_ICON.has(status_id) or state.badges.has(status_id):
		return
	var badge := Sprite3D.new()
	badge.texture = load(STATUS_ICON[status_id])
	badge.pixel_size = 0.011
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.render_priority = 10
	state.badge_row.add_child(badge)
	state.badges[status_id] = badge
	_layout_badges(state)

func _remove_badge(state, status_id: String):
	if not state.badges.has(status_id):
		return
	state.badges[status_id].queue_free()
	state.badges.erase(status_id)
	_layout_badges(state)

func _layout_badges(state):
	var ids = state.badges.keys()
	for i in ids.size():
		state.badges[ids[i]].position = Vector3(
			(i - (ids.size() - 1) * 0.5) * 0.34, 0, 0
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
			"spin":
				state.anim_t += delta
				rig.pose_spin(state.anim_t)
				rig.rotation.y += delta * 10.5
				if state.anim_t >= DelverRig.SPIN_T:
					state.mode = "idle"
			"shoot":
				if not rig.has_method("pose_shoot"):
					state.mode = "idle"
					continue
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

## Bursts of text over the same body claim lanes — keyed by the
## entity when known (position quantization misses fast movers), and
## climbing a half-step per full ring so long bursts stack upward.
var _float_lanes := {}

## Thunderclap's expanding ground ring.
func _spawn_shockwave(at: Vector3):
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.5, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.3, 0.12, 0.3)
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(5.6, 0.12, 5.6), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_floating_text(at: Vector3, text: String, color: Color, size_mult := 1.0, key_id := -1):
	var key = key_id if key_id != -1 else Vector2i(roundi(at.x * 1.5), roundi(at.z * 1.5))
	var lane := 0
	var recent = _float_lanes.get(key)
	if recent != null and _clock - recent.time < 1.1:
		lane = recent.lane + 1
	_float_lanes[key] = {"lane": lane, "time": _clock}
	var side: float = [0.0, -1.0, 1.0, -2.0, 2.0][lane % 5]

	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = int(96 * size_mult)
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at + Vector3(
		side * 0.46 + randf_range(-0.05, 0.05),
		1.5 + 0.24 * float(lane / 5),
		0
	)
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
	label.text = "%s  -  Room %d of %d" % [dungeon().dungeon_name, room, dungeon().length]
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
		if PlayerRoster.autosave:
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

	# Monsters drop resources and knowledge: pouch it all.
	var slain = combat_result.enemies.map(func(e): return e.template)
	var found = LootTable.roll_enemy_drops(
		slain, room,
		PlayerRoster.known_recipes + PlayerRoster.delve_recipes,
		PlayerRoster.known_affixes + PlayerRoster.delve_affixes,
		PlayerRoster.known_lore + PlayerRoster.delve_lore,
		dungeon(),
		PlayerRoster.unlocked_dungeons + PlayerRoster.delve_maps
	)
	PlayerRoster.delve_loot.append_array(found.gear)
	for material_id in found.materials:
		PlayerRoster.delve_materials[material_id] = (
			PlayerRoster.delve_materials.get(material_id, 0)
			+ found.materials[material_id]
		)
	PlayerRoster.delve_recipes.append_array(found.recipes)
	PlayerRoster.delve_affixes.append_array(found.affixes)
	PlayerRoster.delve_lore.append_array(found.lore)
	PlayerRoster.delve_maps.append_array(found.maps)

	# Knowledge pity: three dry rooms guarantee a recipe from the slain
	# enemies' pools. Short failed runs still make progress.
	var learned_something = not (found.recipes.is_empty() and found.affixes.is_empty()
		and found.lore.is_empty() and found.maps.is_empty())
	if learned_something:
		PlayerRoster.rooms_since_knowledge = 0
	else:
		PlayerRoster.rooms_since_knowledge += 1
		if PlayerRoster.rooms_since_knowledge >= 3:
			var known = PlayerRoster.known_recipes + PlayerRoster.delve_recipes
			var pool := []
			for template in slain:
				for recipe_id in template.recipe_loot:
					if not known.has(recipe_id) and not pool.has(recipe_id):
						pool.append(recipe_id)
			if not pool.is_empty():
				var granted = pool.pick_random()
				found.recipes.append(granted)
				PlayerRoster.delve_recipes.append(granted)
				PlayerRoster.rooms_since_knowledge = 0

	if room >= dungeon().length:
		PlayerRoster.adventures_completed += 1
		if PlayerRoster.autosave:
			RosterSave.save(PlayerRoster)
		await _show_battle_result(true)
		await get_tree().create_timer(1.2).timeout
		_show_summary(
			"Delve Complete!",
			"%s is conquered, all %d rooms of it." % [
				dungeon().dungeon_name, dungeon().length
			]
		)
		return

	if PlayerRoster.autosave:
		RosterSave.save(PlayerRoster)
	_show_room_toast(room, _drop_entries(found.gear, found.materials, found.recipes, found.affixes, found.lore, found.maps))
	await get_tree().create_timer(2.6).timeout
	PlayerRoster.delve_room += 1
	SceneFlow.change_scene("res://scenes/theater/battle_theater_3d.tscn")

## Display entries for spoils: gear, materials with counts, and the
## crown jewels — newly learned recipes and affixes.
func _drop_entries(gear: Array, materials: Dictionary, recipes: Array, affixes: Array = [], lore: Array = [], maps: Array = []) -> Array:
	var entries := []
	for dungeon_id in maps:
		var mapped = load(RosterSave.DUNGEON_PATHS[dungeon_id])
		entries.append({
			"texture": preload("res://art/tomes/tome_journal.png"),
			"text": "Weathered Map:\n%s" % mapped.dungeon_name,
			"color": Color(0.95, 0.8, 0.35),
		})
	for lore_id in lore:
		var fragment = load(RosterSave.LORE_PATHS[lore_id])
		entries.append({
			"texture": preload("res://art/tomes/tome_journal.png"),
			"text": fragment.title,
			"color": Color("d8c684"),
		})
	for affix_id in affixes:
		var affix = load(RosterSave.AFFIX_PATHS[affix_id])
		entries.append({
			"texture": preload("res://art/tomes/tome_affix.png"),
			"text": "%s\nTeaches: %s" % [affix.tome_name, affix.affix_name],
			"color": ItemQuality.color(ItemQuality.Tier.EPIC),
		})
	for recipe_id in recipes:
		var recipe = load(RosterSave.RECIPE_PATHS[recipe_id])
		entries.append({
			"texture": preload("res://art/tomes/tome_recipe.png"),
			"text": "%s\nTeaches: %s" % [recipe.tome_name, recipe.recipe_name],
			"color": ItemQuality.color(ItemQuality.Tier.RARE),
		})
	for item in gear:
		entries.append({
			"texture": item.icon if item.icon else item.texture,
			"text": item.gear_name,
			"color": ItemQuality.color(item.quality),
		})
	for material_id in materials:
		var material = load(RosterSave.MATERIAL_PATHS[material_id])
		entries.append({
			"texture": material.icon,
			"text": "%s x%d" % [material.material_name, materials[material_id]],
			"color": ItemQuality.color(material.tier),
		})
	return entries

## Brief bottom-center spoils toast; the delve marches on by itself.
func _show_room_toast(room: int, entries: Array):
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.06, 0.92)
	style.border_color = Color(0.35, 0.28, 0.16, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -235
	panel.offset_bottom = -30
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = (
		"Room %d cleared — pressing on..." % room
		if not entries.is_empty()
		else "Room %d cleared — nothing worth carrying. Pressing on..." % room
	)
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.85, 0.72, 0.42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if not entries.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		for entry in entries:
			row.add_child(DelvePanel.loot_entry(entry))

	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)

## Final spoils screen: everything gathered this delve, then camp.
func _show_summary(title: String, subtitle: String):
	var panel := DelvePanel.new()
	add_child(panel)
	var entries = _drop_entries(
		PlayerRoster.delve_loot,
		PlayerRoster.delve_materials,
		PlayerRoster.delve_recipes,
		PlayerRoster.delve_affixes,
		PlayerRoster.delve_lore,
		PlayerRoster.delve_maps
	)
	panel.setup(title, subtitle, entries, "Return to Camp")
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
	# Each dungeon dresses its own stage: the Darkwood is a moonlit
	# forest clearing; the Nest a warm webbed cavern.
	var nest: bool = dungeon().theme == "nest"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("140e14") if nest else Color("0d1118")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7a5e6e") if nest else Color("66748e")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("1c1218") if nest else Color("131a22")
	env.fog_density = 0.014 if nest else 0.011
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -30, 0)
	moon.light_energy = 0.9 if nest else 1.0
	moon.light_color = Color(1.0, 0.86, 0.72) if nest else Color(0.82, 0.88, 1.0)
	moon.shadow_enabled = true
	add_child(moon)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 140, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.6, 0.45, 0.6) if nest else Color(0.55, 0.7, 0.55)
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
	mat.albedo_color = Color("332631") if nest else Color("2c3626")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = center
	add_child(ground)

	# The treeline: rings of low-poly firs just beyond the field.
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("32251a")
	trunk_mat.roughness = 1.0
	# The backdrop ring hugs the visible clearing, but only behind and
	# beside the fight — the camera's foreground stays clear.
	var cam_dir = Vector3(CAMERA_OFFSET.x, 0, CAMERA_OFFSET.z).normalized()
	for i in 30:
		var a = TAU * i / 30.0 + 0.35 * sin(i * 3.1)
		var ring = 0.35 * ((i * 7) % 4)
		var offset = Vector3(
			(8.6 + 1.4 * ring) * cos(a), 0,
			(6.0 + 1.1 * ring) * sin(a)
		)
		if offset.normalized().dot(cam_dir) > 0.25:
			continue
		var tree := Node3D.new()
		tree.position = center + offset
		var height = 1.0 + 0.5 * ((i * 5) % 4) / 3.0
		tree.scale = Vector3.ONE * height
		add_child(tree)
		if nest:
			# Stalagmite columns wrapped in pale silk, egg sacs at the base.
			var spire := CylinderMesh.new()
			spire.top_radius = 0.05
			spire.bottom_radius = 0.5
			spire.height = 2.6
			spire.radial_segments = 7
			var spire_mesh := MeshInstance3D.new()
			spire_mesh.mesh = spire
			var spire_mat := StandardMaterial3D.new()
			spire_mat.albedo_color = Color("453242") * (0.85 + 0.3 * ((i * 11) % 3) / 2.0)
			spire_mat.roughness = 1.0
			spire_mesh.material_override = spire_mat
			spire_mesh.position.y = 1.3
			tree.add_child(spire_mesh)
			var wrap := CylinderMesh.new()
			wrap.top_radius = 0.16
			wrap.bottom_radius = 0.3
			wrap.height = 0.8
			wrap.radial_segments = 7
			var wrap_mesh := MeshInstance3D.new()
			wrap_mesh.mesh = wrap
			var wrap_mat := StandardMaterial3D.new()
			wrap_mat.albedo_color = Color("cfc8b8")
			wrap_mat.roughness = 0.9
			wrap_mesh.material_override = wrap_mat
			wrap_mesh.position.y = 0.9 + 0.5 * ((i * 7) % 3) / 2.0
			tree.add_child(wrap_mesh)
			if i % 3 == 0:
				var sac := SphereMesh.new()
				sac.radius = 0.22
				sac.height = 0.4
				sac.radial_segments = 7
				sac.rings = 4
				var sac_mesh := MeshInstance3D.new()
				sac_mesh.mesh = sac
				var sac_mat := StandardMaterial3D.new()
				sac_mat.albedo_color = Color("ded6c2")
				sac_mat.roughness = 0.85
				sac_mesh.material_override = sac_mat
				sac_mesh.position = Vector3(0.5, 0.2, 0.2)
				tree.add_child(sac_mesh)
			continue
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.09
		trunk.bottom_radius = 0.13
		trunk.height = 0.9
		trunk.radial_segments = 6
		var trunk_mesh := MeshInstance3D.new()
		trunk_mesh.mesh = trunk
		trunk_mesh.material_override = trunk_mat
		trunk_mesh.position.y = 0.45
		tree.add_child(trunk_mesh)
		var shade = 0.85 + 0.3 * ((i * 11) % 3) / 2.0
		var leaf_mat := StandardMaterial3D.new()
		leaf_mat.albedo_color = Color("1c2e1f") * shade
		leaf_mat.roughness = 1.0
		for layer in 2:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.85 - 0.3 * layer
			cone.height = 1.15 - 0.2 * layer
			cone.radial_segments = 7
			var cone_mesh := MeshInstance3D.new()
			cone_mesh.mesh = cone
			cone_mesh.material_override = leaf_mat
			cone_mesh.position.y = 1.0 + 0.72 * layer
			tree.add_child(cone_mesh)

	# Blocked tiles rise as stone pillars: the same cells the sim's
	# pathfinding and line of sight respect.
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color("42463e")
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
			prop_mat.albedo_color = Color("4a4f45")
		else:
			var tuft := BoxMesh.new()
			tuft.size = Vector3(0.05, 0.14, 0.05)
			mesh.mesh = tuft
			mesh.position.y = 0.07
			prop_mat.albedo_color = Color("3f5a33")
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
