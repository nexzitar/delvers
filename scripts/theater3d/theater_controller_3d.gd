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

## The generated library (ElevenLabs batch): loaded on demand,
## guarded - a missing file falls back to the old wavs or silence.
var _sfx_cache := {}
func _sfx(name: String, db := -4.0, pitch := 1.0):
	if not _sfx_cache.has(name):
		var path = "res://audio/sfx/%s.mp3" % name
		_sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	if _sfx_cache[name] != null:
		UiSounds.play(_sfx_cache[name], "SFX", db, pitch)
		return true
	return false

func _sfx_pick(names: Array, db := -4.0):
	_sfx(names.pick_random(), db, randf_range(0.92, 1.08))

## The family a template belongs to (creature voices).
static func _family_of(template) -> String:
	if template == null:
		return ""
	var eid := String(template.enemy_id) if "enemy_id" in template else ""
	if "spider" in eid or "brood" in eid or "weaver" in eid:
		return "spider"
	if "slime" in eid or "ooze" in eid or "slick" in eid:
		return "slime"
	if "goblin" in eid:
		return "goblin"
	return ""
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
	"battle_shout": "res://art/status/status_empower.png",
	"gum_strike": "res://art/status/status_daze.png",
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
	"battle_shout": "Emboldened!",
	"gum_strike": "Gummed!",
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

## One level of elevation in world units.
const HEIGHT_Y := 0.55
var _height_grid: Dictionary = {}
var _height_tile_size := 32

## Sim position to world WITH the ground under it.
func world_at(sim_pos: Vector2) -> Vector3:
	var w = to_world(sim_pos)
	w.y = ground_y(sim_pos)
	return w

func ground_y(sim_pos: Vector2) -> float:
	var tile = Vector2i(floori(sim_pos.x / _height_tile_size),
		floori(sim_pos.y / _height_tile_size))
	return _height_grid.get(tile, 0.0) * HEIGHT_Y

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

## Architecture kit: per-theme dye palettes for the compiled masonry
## (ArchPrimary/ArchSecondary/ArchTrim tint like garment surfaces).
const ARCH_THEMES := {
	"forest": {"primary": Color(0.3, 0.32, 0.28), "secondary": Color(0.22, 0.25, 0.21), "trim": Color(0.34, 0.42, 0.28)},
	"nest": {"primary": Color(0.3, 0.24, 0.3), "secondary": Color(0.2, 0.16, 0.21), "trim": Color(0.74, 0.7, 0.6)},
	"workshop": {"primary": Color(0.33, 0.29, 0.23), "secondary": Color(0.25, 0.21, 0.16), "trim": Color(0.55, 0.43, 0.22)},
}

## Continuous delve: the compiled layout being walked, sidebar entries
## deferred until packs wake, and how deep the party got.
var _layout: DungeonLayout = null
var _pending_units := {}
var _spawn_events := {}
var _room_reached := 1

func _ready():
	get_viewport().msaa_3d = Viewport.MSAA_4X
	if forced_arena_path == "":
		# The stems own the delve; the old theme must not leak in
		# while the sim compiles the dungeon.
		var old_music = get_node_or_null("Music")
		if old_music:
			old_music.stop()

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
	if forced_arena_path != "":
		# Harness mode: one arena, one encounter (shots and probes).
		combat.enemy_level_bonus = (room - 1) / 4 + (PlayerRoster.current_tier - 1) * 2
		combat.setup_combat(party, roll_encounter(room), _pick_arena(room), entry_health)
	else:
		# The continuous dungeon: one place, walked end to end.
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		_layout = DungeonLayout.generate(dungeon(), rng)
		combat.setup_delve(party, _layout, entry_health,
			(PlayerRoster.current_tier - 1) * 2)
	var guard := 60000
	while not combat.combat_over and guard > 0:
		combat.update(0.1)
		guard -= 1
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
	if _layout == null:
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
	var low = clampi(2 + (room - 1) / 4, 2, 4) + d.pack_bonus
	var high = clampi(3 + (room - 1) / 2, 3, 6) + d.pack_bonus
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

var replay_speed := 1.0

func _process(delta):
	if not _playing:
		return
	delta *= replay_speed
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

	var burst_keys := {}
	var events: Array = log.events
	for i in events.size():
		var event = events[i]
		_timeline.append({"time": event.time, "kind": "event", "event": event})
		match event.type:
			CombatEvent.EventType.DAMAGE:
				if event.dot:
					continue
				# Archer behaviors: a quick draw cue plus an arrow
				# streak per victim at impact.
				if event.skill_name in ["Multishot", "Piercing Shot"]:
					var draw_key = "%d:%.2f:draw" % [event.source_id, event.time]
					if not burst_keys.has(draw_key):
						burst_keys[draw_key] = true
						_timeline.append({
							"time": maxf(0.0, event.time - 0.35),
							"kind": "quickdraw", "id": event.source_id,
						})
					_timeline.append({
						"time": event.time, "kind": "streak",
						"from": event.source_id, "to": event.target_id,
					})
					continue
				# AoE bursts get one distinctive cue, not a swing per victim.
				if event.skill_name in ["Whirlwind", "Thunderclap"]:
					var burst_key = "%d:%s:%.2f" % [event.source_id, event.skill_name, event.time]
					if not burst_keys.has(burst_key):
						burst_keys[burst_key] = true
						_timeline.append({
							"time": maxf(0.0, event.time - 0.3),
							"kind": "spin" if event.skill_name == "Whirlwind" else "clap",
							"id": event.source_id,
						})
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
			match state.get("family", ""):
				"slime":
					_sfx("slime_attack", -8.0, randf_range(0.9, 1.1))
				"spider":
					_sfx("spider_bite", -9.0, randf_range(0.92, 1.08))
				_:
					_sfx_pick(["sword_swing_1", "sword_swing_2"], -10.0)
		return
	if item.kind == "spin":
		var state = actors.get(item.id)
		if state and state.mode != "dead" and state.rig.has_method("pose_spin"):
			state.mode = "spin"
			state.anim_t = 0.0
		return
	if item.kind == "quickdraw":
		var state = actors.get(item.id)
		if state and state.mode != "dead" and state.rig.has_method("pose_shoot"):
			state.mode = "shoot"
			state.anim_t = 0.0
			state.anim_speed = 2.4
		return
	if item.kind == "streak":
		var from_state = actors.get(item.from)
		var to_state = actors.get(item.to)
		if from_state and to_state:
			_spawn_arrow_streak(
				from_state.rig.position + Vector3(0, 1.0, 0),
				to_state.rig.position + Vector3(0, 0.7, 0)
			)
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
		CombatEvent.EventType.ROOM_ENTERED:
			_room_reached = maxi(_room_reached, event.room)
			var role := ""
			if _layout != null and event.room - 1 < _layout.room_roles.size():
				role = _layout.room_roles[event.room - 1]
			if role in ["entrance", "landmark", "mid_boss", "boss"]:
				_show_room_banner(event.room)
		CombatEvent.EventType.PACK_PULLED:
			_wake_pack(event.pack_id)
		CombatEvent.EventType.PACK_DEFEATED:
			_bank_pack(event)
		CombatEvent.EventType.PACK_RESET:
			for entity_id in actors:
				var st = actors[entity_id]
				if st.get("pack_id", -1) != event.pack_id or st.mode == "dead":
					continue
				st.dormant = true
				st.mode = "idle"
				enemy_sidebar.remove_unit(entity_id)
			call_deferred("_music_update")
		CombatEvent.EventType.TELEGRAPH:
			var telegraph = AoeTelegraph3D.new(
				event.telegraph_radius * WORLD_SCALE, event.telegraph_duration
			)
			add_child(telegraph)
			telegraph.position = world_at(event.position)

func _play_spawn(event):
	var rig = ActorFactory3D.build_from_spawn(event)
	add_child(rig)
	rig.position = world_at(event.position)
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
		"pack_id": event.pack_id,
		"dormant": event.team == CombatEntity.Team.ENEMY and event.pack_id >= 0,
		"family": _family_of(event.template),
		"reaction": Vector3.ZERO,
	}

	var sidebar = (
		hero_sidebar if event.team == CombatEntity.Team.HERO
		else enemy_sidebar
	)
	# A dormant pack hasn't been met yet: its sidebar entry appears
	# when it wakes, so the enemy panel reads as the current fight.
	_spawn_events[event.entity_id] = event
	if actors[event.entity_id].dormant:
		_pending_units[event.entity_id] = event
	else:
		sidebar.add_unit(event)
		sidebars_by_entity[event.entity_id] = sidebar

func _play_move(event):
	var state = actors.get(event.entity_id)
	if state == null or state.mode == "dead":
		return
	state.move_from = state.rig.position
	state.move_to = world_at(event.position)
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
	_react(event)
	var attacker_family = actors.get(event.source_id, {}).get("family", "")
	if event.blocked and _sfx("shield_block", -4.0, randf_range(0.95, 1.05)):
		pass
	elif event.crit and _sfx("crit_impact", -3.0, randf_range(0.95, 1.05)):
		pass
	elif attacker_family == "slime" and _sfx("slime_impact", -5.0,
			randf_range(0.9, 1.1)):
		pass
	elif attacker_family == "spider" and _sfx("spider_bite", -6.0,
			randf_range(0.92, 1.08)):
		pass
	elif ranged and _sfx("arrow_hit", -5.0, randf_range(0.92, 1.08)):
		pass
	elif not ranged and _sfx("sword_hit_%d" % (randi_range(1, 2)), -5.0,
			randf_range(0.92, 1.08)):
		pass
	else:
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
	if not event.dot:
		_sfx("heal_chime", -8.0, randf_range(0.95, 1.05))
		_spawn_heal_glow(target.rig.position)
	sidebars_by_entity[event.target_id].set_health(
		event.target_id, event.remaining_health, event.max_health
	)
	var caster_bar = sidebars_by_entity.get(event.source_id)
	if caster_bar and event.max_mana > 0:
		caster_bar.set_mana(event.source_id, event.current_mana, event.max_mana)
	_spawn_floating_text(
		target.rig.position, "+%d" % event.amount, Color(0.35, 0.85, 0.3),
		0.7 if event.dot else 1.0, event.target_id
	)

## Bodies answer contact: a jolt away from the blow, a sidestep on a
## dodge, a small brace on a block - offsets that decay in a beat.
func _react(event):
	var target = actors.get(event.target_id)
	var source = actors.get(event.source_id)
	if target == null or target.mode == "dead":
		return
	var away := Vector3(0, 0, 0.12)
	if source:
		away = (target.rig.position - source.rig.position)
		away.y = 0.0
		away = away.normalized()
	if event.dodged:
		var side = away.cross(Vector3.UP)
		target.reaction = side * (0.24 if randf() < 0.5 else -0.24)
	elif event.blocked:
		target.reaction = away * 0.06
	elif not event.dot:
		target.reaction = away * (0.16 if event.crit else 0.1)

func _play_death(event):
	call_deferred("_music_update")
	if actors.get(event.target_id, {}).get("team", -1) == CombatEntity.Team.ENEMY:
		var linger := get_tree().create_timer(7.0)
		linger.timeout.connect(func():
			var bar = sidebars_by_entity.get(event.target_id)
			if bar:
				bar.remove_unit(event.target_id))
	var dead_state = actors.get(event.target_id)
	if dead_state:
		match dead_state.get("family", ""):
			"goblin":
				_sfx("goblin_death", -5.0, randf_range(0.9, 1.1))
			"slime":
				_sfx("slime_death", -5.0, randf_range(0.9, 1.1))
			"spider":
				_sfx("spider_death", -5.0, randf_range(0.9, 1.1))
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
	# Renew shows its cast: the healer raises hands, the target gets a
	# soft green ring.
	if event.status_id == "renew_hot":
		var caster = actors.get(event.source_id)
		if caster and caster.mode == "idle" \
				and caster.rig.has_method("pose_shoot"):
			caster.mode = "shoot"
			caster.anim_t = 0.0
			caster.anim_speed = 1.8
		_spawn_shockwave(target.rig.position, Color(0.5, 0.9, 0.45, 0.7), 2.2)

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
			rig.position = state.move_from.lerp(state.move_to, state.move_progress) \
				+ state.get("reaction", Vector3.ZERO)
			state.reaction = state.get("reaction", Vector3.ZERO) \
				* exp(-7.0 * delta)

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
var _cam_yaw := 0.0
var _cam_zoom := 1.0
var _cam_orbiting := false

## Music stems (vertical layering): explore always plays; the combat
## layer fades in over it when a pack is awake; the boss layer joins
## for the last pack. One key, one tempo - the layers stack in time.
var _stem_players := {}

func _setup_stems():
	var stem_theme: String = {"forest": "darkwood"}.get(dungeon().theme, "")
	if stem_theme == "":
		return
	var base = "res://audio/music/%s_" % stem_theme
	if not ResourceLoader.exists(base + "explore.mp3"):
		var old_music = get_node_or_null("Music")
		if old_music:
			old_music.play()
		return
	for stem in ["explore", "combat", "boss"]:
		var path = base + stem + ".mp3"
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream is AudioStreamMP3:
			stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Music"
		player.volume_db = -4.0 if stem == "explore" else -60.0
		add_child(player)
		player.play()
		_stem_players[stem] = player

func _music_update():
	if _stem_players.is_empty():
		return
	var fighting := false
	var boss_fight := false
	var boss_pack: int = (_layout.packs.size() - 1) if _layout != null else -1
	for state in actors.values():
		if state.team != CombatEntity.Team.ENEMY:
			continue
		if state.get("dormant", false) or state.mode == "dead":
			continue
		fighting = true
		if state.get("pack_id", -1) == boss_pack:
			boss_fight = true
	var targets := {
		"explore": -10.0 if fighting else -4.0,
		"combat": (-14.0 if boss_fight else -6.0) if fighting else -60.0,
		"boss": -4.0 if boss_fight else -60.0,
	}
	for stem in _stem_players:
		var player = _stem_players[stem]
		var goal: float = targets.get(stem, -60.0)
		if absf(player.volume_db - goal) > 0.5:
			var fade := create_tween()
			fade.tween_property(player, "volume_db", goal, 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cam_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_zoom = clampf(_cam_zoom * 0.9, 0.55, 1.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_zoom = clampf(_cam_zoom / 0.9, 0.55, 1.9)
	elif event is InputEventMouseMotion and _cam_orbiting:
		_cam_yaw -= event.relative.x * 0.008

func _update_camera(delta):
	# The party anchors the frame; enemies only widen it when they
	# are part of THIS fight, not stragglers across the map.
	var hero_center := Vector3.ZERO
	var hero_count := 0
	for state in actors.values():
		if state.team == CombatEntity.Team.HERO and state.mode != "dead":
			hero_center += state.rig.position
			hero_count += 1
	if hero_count == 0:
		return
	hero_center /= hero_count
	var low := Vector3(INF, 0, INF)
	var high := Vector3(-INF, 0, -INF)
	var count := 0
	for state in actors.values():
		if state.mode == "dead" or state.get("dormant", false):
			continue
		var p = state.rig.position
		if state.team != CombatEntity.Team.HERO \
				and p.distance_to(hero_center) > 7.0:
			continue
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
	var distance = clampf(4.0 + spread * 0.95, 8.0, 16.0) * _cam_zoom
	var bearing = CAMERA_OFFSET.normalized().rotated(Vector3.UP, _cam_yaw)
	var goal = center + bearing * distance
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

## A fast arrow flying point to point (archer behavior skills).
func _spawn_arrow_streak(from: Vector3, to: Vector3):
	_sfx("bow_release", -8.0, randf_range(0.92, 1.08))
	var streak := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.015
	shaft.bottom_radius = 0.015
	shaft.height = 0.5
	streak.mesh = shaft
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material_override = mat
	add_child(streak)
	streak.position = from
	streak.look_at_from_position(from, to)
	streak.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tween := create_tween()
	tween.tween_property(streak, "position", to, 0.12)
	tween.tween_callback(streak.queue_free)

## An expanding ground ring: thunder gold by default, renew green.
## Healing has a face: a soft green ring and motes drifting up off
## the mended delver, gone in under a second.
func _spawn_heal_glow(at: Vector3):
	_spawn_shockwave(at, Color(0.4, 0.9, 0.45, 0.55), 1.6)
	for i in 5:
		var mote := MeshInstance3D.new()
		var orb := SphereMesh.new()
		orb.radius = 0.035
		orb.height = 0.07
		orb.radial_segments = 6
		orb.rings = 3
		mote.mesh = orb
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.95, 0.5)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mote.material_override = mat
		var a = TAU * i / 5.0 + randf() * 0.6
		mote.position = at + Vector3(cos(a) * 0.22, 0.3 + randf() * 0.3,
			sin(a) * 0.22)
		add_child(mote)
		var rise := create_tween()
		rise.set_parallel(true)
		rise.tween_property(mote, "position:y", mote.position.y + 0.9,
			0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rise.tween_property(mat, "albedo_color:a", 0.0, 0.8) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		rise.chain().tween_callback(mote.queue_free)

func _spawn_shockwave(at: Vector3, tint := Color(1.0, 0.9, 0.5, 0.8), max_scale := 5.6):
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.3, 0.12, 0.3)
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(max_scale, 0.12, max_scale), 0.45) \
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
## The display name of a room: its place name in a delve, its number
## on a plain arena.
func _place_name(room: int) -> String:
	if _layout != null and room - 1 < _layout.room_names.size():
		return _layout.room_names[room - 1]
	return "Room %d" % room

func _show_room_banner(room: int):
	if room == _last_banner_room:
		return
	_last_banner_room = room
	if is_instance_valid(_banner_layer):
		_banner_layer.queue_free()
	_sfx("room_banner", -8.0)
	var layer := CanvasLayer.new()
	_banner_layer = layer
	layer.layer = 11
	add_child(layer)
	var label := Label.new()
	var tier_tag = ""
	if PlayerRoster.current_tier > 1:
		tier_tag = " " + ["", "", "II", "III", "IV", "V"][PlayerRoster.current_tier]
	label.text = "%s%s  -  %s  (%d of %d)" % [
		dungeon().dungeon_name, tier_tag, _place_name(room),
		room, dungeon().length]
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

## A pack noticed the party: wake its actors and reveal them in the
## enemy panel.
func _wake_pack(pack_id: int):
	_sfx("pack_pulled", -6.0)
	call_deferred("_music_update")
	var voices := {"goblin": ["goblin_bark_1", "goblin_bark_2"],
		"spider": ["spider_hiss"], "slime": ["slime_hop"]}
	var pack_family := ""
	for entity_id in actors:
		var st = actors[entity_id]
		if st.get("pack_id", -1) == pack_id and st.get("family", "") != "":
			pack_family = st.family
			break
	if voices.has(pack_family):
		_sfx_pick(voices[pack_family], -5.0)
	for entity_id in actors:
		var state = actors[entity_id]
		if state.get("pack_id", -1) != pack_id or not state.get("dormant", false):
			continue
		state.dormant = false
		if not enemy_sidebar.has_unit(entity_id) and _spawn_events.has(entity_id):
			enemy_sidebar.add_unit(_spawn_events[entity_id])
			sidebars_by_entity[entity_id] = enemy_sidebar
		_pending_units.erase(entity_id)

## A pack died: its loot banks and toasts NOW, mid-run - the delve
## keeps walking while the pouch fills.
func _bank_pack(event):
	var pack = _layout.packs[event.pack_id]
	var slain = pack.templates
	var found = LootTable.roll_enemy_drops(
		slain, event.room,
		PlayerRoster.known_recipes + PlayerRoster.delve_recipes,
		PlayerRoster.known_affixes + PlayerRoster.delve_affixes,
		PlayerRoster.known_lore + PlayerRoster.delve_lore,
		dungeon(),
		PlayerRoster.unlocked_dungeons + PlayerRoster.delve_maps,
		PlayerRoster.current_tier,
		PlayerRoster.known_tactics + PlayerRoster.delve_doctrines,
		PlayerRoster.heroes.size()
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
	PlayerRoster.delve_doctrines.append_array(found.doctrines)

	# Practice: whoever still stands when the pack falls trains.
	var alive_indices := []
	for k in _party_indices.size():
		var state = actors.get(k + 1)
		if state and state.mode != "dead":
			alive_indices.append(_party_indices[k])
	var boss = event.room >= dungeon().length
	var star_ups = PlayerRoster.train_party(alive_indices, 4 if boss else 1)

	# Knowledge pity: three dry packs guarantee a recipe.
	var learned_something = not (found.recipes.is_empty() and found.affixes.is_empty()
		and found.lore.is_empty() and found.maps.is_empty()
		and found.doctrines.is_empty())
	if learned_something:
		PlayerRoster.rooms_since_knowledge = 0
	else:
		PlayerRoster.rooms_since_knowledge += 1
		if PlayerRoster.rooms_since_knowledge >= 3:
			var known = PlayerRoster.known_recipes + PlayerRoster.delve_recipes
			var pool := []
			for template in slain:
				for recipe_id in template.recipe_loot:
					if known.has(recipe_id) or pool.has(recipe_id):
						continue
					var recipe = load(RosterSave.RECIPE_PATHS[recipe_id])
					if recipe.min_tier > PlayerRoster.current_tier:
						continue
					pool.append(recipe_id)
			if not pool.is_empty():
				var granted = pool.pick_random()
				found.recipes.append(granted)
				PlayerRoster.delve_recipes.append(granted)
				PlayerRoster.rooms_since_knowledge = 0

	PlayerRoster.delve_room = _room_reached
	if PlayerRoster.autosave:
		RosterSave.save(PlayerRoster)
	var entries = _drop_entries(found.gear, found.materials, found.recipes,
		found.affixes, found.lore, found.maps, star_ups, found.doctrines)
	if not entries.is_empty():
		_show_room_toast(event.room, entries)

func _finish_battle():
	await get_tree().create_timer(1.4).timeout

	var room = maxi(1, PlayerRoster.delve_room)
	PlayerRoster.battles_fought += 1
	PlayerRoster.last_battle_won = combat_result.victory

	if _layout != null:
		# Continuous delve: every pack banked mid-run; only the ending
		# is left to tell.
		if combat_result.victory:
			PlayerRoster.adventures_completed += 1
			PlayerRoster.record_clear(dungeon().dungeon_id, PlayerRoster.current_tier)
		if PlayerRoster.autosave:
			RosterSave.save(PlayerRoster)
		await _show_battle_result(combat_result.victory)
		await get_tree().create_timer(1.2).timeout
		if combat_result.victory:
			_show_summary(
				"Delve Complete!",
				"%s, walked end to end - all %d rooms of it." % [
					dungeon().dungeon_name, dungeon().length
				]
			)
		else:
			_show_summary(
				"The Party Falls...",
				"They fought as far as room %d. Their spoils make it home." % _room_reached
			)
		return

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
		PlayerRoster.unlocked_dungeons + PlayerRoster.delve_maps,
		PlayerRoster.current_tier,
		PlayerRoster.known_tactics + PlayerRoster.delve_doctrines,
		PlayerRoster.heroes.size()
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
	PlayerRoster.delve_doctrines.append_array(found.doctrines)

	# Practice: the fielded party trains its disciplines room by room.
	var alive_indices := []
	for k in combat_result.heroes.size():
		if combat_result.heroes[k].alive:
			alive_indices.append(_party_indices[k])
	var star_ups = PlayerRoster.train_party(
		alive_indices, 4 if room >= dungeon().length else 1
	)

	# Knowledge pity: three dry rooms guarantee a recipe from the slain
	# enemies' pools. Short failed runs still make progress.
	var learned_something = not (found.recipes.is_empty() and found.affixes.is_empty()
		and found.lore.is_empty() and found.maps.is_empty()
		and found.doctrines.is_empty())
	if learned_something:
		PlayerRoster.rooms_since_knowledge = 0
	else:
		PlayerRoster.rooms_since_knowledge += 1
		if PlayerRoster.rooms_since_knowledge >= 3:
			var known = PlayerRoster.known_recipes + PlayerRoster.delve_recipes
			var pool := []
			for template in slain:
				for recipe_id in template.recipe_loot:
					if known.has(recipe_id) or pool.has(recipe_id):
						continue
					# Pity honors tier gates like any other drop.
					var recipe = load(RosterSave.RECIPE_PATHS[recipe_id])
					if recipe.min_tier > PlayerRoster.current_tier:
						continue
					pool.append(recipe_id)
			if not pool.is_empty():
				var granted = pool.pick_random()
				found.recipes.append(granted)
				PlayerRoster.delve_recipes.append(granted)
				PlayerRoster.rooms_since_knowledge = 0

	if room >= dungeon().length:
		PlayerRoster.adventures_completed += 1
		PlayerRoster.record_clear(dungeon().dungeon_id, PlayerRoster.current_tier)
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
	_show_room_toast(room, _drop_entries(found.gear, found.materials, found.recipes, found.affixes, found.lore, found.maps, star_ups, found.doctrines))
	await get_tree().create_timer(2.6).timeout
	PlayerRoster.delve_room += 1
	SceneFlow.change_scene("res://scenes/theater/battle_theater_3d.tscn")

## Display entries for spoils: gear, materials with counts, and the
## crown jewels — newly learned recipes and affixes.
func _drop_entries(gear: Array, materials: Dictionary, recipes: Array, affixes: Array = [], lore: Array = [], maps: Array = [], star_ups: Array = [], doctrines: Array = []) -> Array:
	var entries := []
	for doctrine_id in doctrines:
		if Doctrines.CAPACITY.has(doctrine_id):
			var capacity = Doctrines.CAPACITY[doctrine_id]
			entries.append({
				"texture": preload("res://art/tomes/tome_journal.png"),
				"text": "%s\nDoctrine: %d nodes" % [capacity.tome, capacity.nodes],
				"color": Color(0.55, 0.75, 1.0),
			})
			continue
		var doctrine = Doctrines.ALL[doctrine_id]
		entries.append({
			"texture": preload("res://art/tomes/tome_journal.png"),
			"text": "%s\nTactic: %s" % [doctrine.tome, doctrine.name],
			"color": Color(0.55, 0.75, 1.0),
		})
	for gain in star_ups:
		entries.append({
			"texture": preload("res://art/status/status_stun.png"),
			"text": "%s: %s %s\n%s" % [
				gain.hero, Mastery.DISCIPLINES[gain.discipline].name,
				"★".repeat(gain.star), gain.label,
			],
			"color": Color(0.95, 0.8, 0.35),
		})
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
var _toast_layer: CanvasLayer = null
var _banner_layer: CanvasLayer = null
var _last_banner_room := -1

func _show_room_toast(room: int, entries: Array):
	_sfx("loot_toast", -6.0)
	if is_instance_valid(_toast_layer):
		_toast_layer.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_toast_layer = layer
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
		"%s cleared — pressing on..." % _place_name(room)
		if not entries.is_empty()
		else "%s cleared — nothing worth carrying. Pressing on..." % _place_name(room)
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
	tween.tween_interval(4.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func():
		if is_instance_valid(layer):
			layer.queue_free())

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
	if not victory:
		for stem in _stem_players:
			var fade := create_tween()
			fade.tween_property(_stem_players[stem], "volume_db", -60.0, 0.5)
		var old_music = get_node_or_null("Music")
		if old_music and old_music.playing:
			var fade_old := create_tween()
			fade_old.tween_property(old_music, "volume_db", -60.0, 0.5)
		await get_tree().create_timer(0.7).timeout
		_sfx("defeat_sting", -4.0)
		var lament_path := "res://audio/music/defeat_theme.mp3"
		if ResourceLoader.exists(lament_path):
			var lament := AudioStreamPlayer.new()
			lament.stream = load(lament_path)
			lament.bus = "Music"
			lament.volume_db = -5.0
			add_child(lament)
			var start := get_tree().create_timer(1.6)
			start.timeout.connect(func(): lament.play())
	else:
		_sfx("victory_sting", -5.0)
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
	_height_grid = arena.heights
	_height_tile_size = arena.tile_size
	# Each dungeon dresses its own stage: the Darkwood is a moonlit
	# forest clearing; the Nest a warm webbed cavern.
	var nest: bool = dungeon().theme == "nest"
	var workshop: bool = dungeon().theme == "workshop"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("16120a") if workshop \
		else Color("140e14") if nest else Color("0d1118")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a7450") if workshop \
		else Color("7a5e6e") if nest else Color("66748e")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("1d160c") if workshop \
		else Color("1c1218") if nest else Color("131a22")
	env.fog_density = 0.014 if nest else 0.011
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -30, 0)
	moon.light_energy = 0.9 if nest else 1.0
	moon.light_color = Color(1.0, 0.8, 0.55) if workshop \
		else Color(1.0, 0.86, 0.72) if nest else Color(0.82, 0.88, 1.0)
	moon.shadow_enabled = true
	add_child(moon)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 140, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.7, 0.55, 0.3) if workshop \
		else Color(0.6, 0.45, 0.6) if nest else Color(0.55, 0.7, 0.55)
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
	mat.albedo_color = Color("241f16") if workshop \
		else Color("332631") if nest else Color("2c3626")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = center
	add_child(ground)

	# The treeline rings a single clearing; a walked dungeon is its
	# own place (architecture kit incoming) - walls carry the look.
	var dressing := _layout == null
	# The treeline: rings of low-poly firs just beyond the field.
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("32251a")
	trunk_mat.roughness = 1.0
	# The backdrop ring hugs the visible clearing, but only behind and
	# beside the fight — the camera's foreground stays clear.
	var cam_dir = Vector3(CAMERA_OFFSET.x, 0, CAMERA_OFFSET.z).normalized()
	for i in (30 if dressing else 0):
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
		if workshop:
			# Brass columns and dead engine housings ring the hall.
			var column := CylinderMesh.new()
			column.top_radius = 0.16
			column.bottom_radius = 0.2
			column.height = 2.6
			column.radial_segments = 8
			var column_mesh := MeshInstance3D.new()
			column_mesh.mesh = column
			var brass := StandardMaterial3D.new()
			brass.albedo_color = Color(0.4, 0.31, 0.17) * (0.85 + 0.3 * ((i * 11) % 3) / 2.0)
			brass.roughness = 0.8
			column_mesh.material_override = brass
			column_mesh.position.y = 1.3
			tree.add_child(column_mesh)
			var housing := BoxMesh.new()
			housing.size = Vector3(0.6, 0.5, 0.5)
			var housing_mesh := MeshInstance3D.new()
			housing_mesh.mesh = housing
			var gunmetal := StandardMaterial3D.new()
			gunmetal.albedo_color = Color(0.3, 0.27, 0.22)
			gunmetal.roughness = 1.0
			housing_mesh.material_override = gunmetal
			housing_mesh.position = Vector3(0.35, 0.25, 0)
			tree.add_child(housing_mesh)
			continue
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
	# Elevated ground: every raised walkable tile is a stone step
	# under the walker - the descent reads in the floor itself.
	if not arena.heights.is_empty():
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color("373b34") if dressing else Color("3a3e37")
		floor_mat.roughness = 1.0
		var raised: Array[Vector2i] = []
		var blocked_lookup := {}
		for t in arena.blocked_tiles:
			blocked_lookup[t] = true
		for tile in arena.heights:
			if blocked_lookup.has(tile):
				continue
			if arena.heights[tile] > 0.02:
				raised.append(tile)
		if not raised.is_empty():
			var slab := BoxMesh.new()
			slab.size = Vector3(1.0, 1.0, 1.0)
			slab.material = floor_mat
			var fmm := MultiMesh.new()
			fmm.transform_format = MultiMesh.TRANSFORM_3D
			fmm.mesh = slab
			fmm.instance_count = raised.size()
			for i in raised.size():
				var tile = raised[i]
				var h = arena.heights[tile] * HEIGHT_Y
				var base = to_world(Vector2(
					(tile.x + 0.5) * arena.tile_size,
					(tile.y + 0.5) * arena.tile_size))
				fmm.set_instance_transform(i, Transform3D(
					Basis.from_scale(Vector3(1.0, maxf(h, 0.05), 1.0)),
					base + Vector3(0, maxf(h, 0.05) * 0.5, 0)))
			var fmmi := MultiMeshInstance3D.new()
			fmmi.multimesh = fmm
			add_child(fmmi)

	# Only wall faces the party can see: blocked tiles touching open
	# ground. Interior rock stays un-meshed.
	var blocked_set := {}
	for tile in arena.blocked_tiles:
		blocked_set[tile] = true
	var shown: Array[Vector2i] = []
	for tile in arena.blocked_tiles:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
				Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1),
				Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: Vector2i = tile + d
			if n.x < 0 or n.y < 0 or n.x >= arena.width or n.y >= arena.height:
				continue
			if not blocked_set.has(n):
				shown.append(tile)
				break
	if shown.size() > 120:
		_build_architecture(arena, shown, blocked_set)
	else:
		for tile in shown:
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
	for i in (14 if dressing else 0):
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

	_setup_stems()
	var beds := {"forest": "darkwood", "nest": "spider_nest",
		"workshop": "sunken_workshop"}
	var bed_path = "res://audio/ambience/%s.mp3" % beds.get(dungeon().theme, "darkwood")
	if ResourceLoader.exists(bed_path):
		var bed_stream = load(bed_path)
		if bed_stream is AudioStreamMP3:
			bed_stream.loop = true
		var bed := AudioStreamPlayer.new()
		bed.stream = bed_stream
		bed.bus = "Ambience"
		bed.volume_db = -8.0
		bed.autoplay = true
		add_child(bed)

	camera = Camera3D.new()
	camera.fov = 35
	var open_on = center
	if _layout != null:
		open_on = world_at(Vector2(
			(arena.hero_spawn_center.x + 0.5) * arena.tile_size,
			(arena.hero_spawn_center.y + 0.5) * arena.tile_size))
	camera.position = open_on + CAMERA_OFFSET.normalized() * 10.0
	add_child(camera)
	camera.look_at(open_on)

## The architecture kit dresses the dungeon: coursed walls in three
## variants (MultiMesh), pillars where masonry stands alone, arches
## over every corridor mouth, rubble where rooms have settled - all
## dyed to the dungeon theme like garments.
func _build_architecture(arena, shown: Array[Vector2i], blocked_set: Dictionary):
	var palette: Dictionary = ARCH_THEMES.get(dungeon().theme, ARCH_THEMES["forest"])
	var kit = load("res://resources/models/arch_kit.glb").instantiate()
	var kit_meshes := {}
	var stack := [kit]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			kit_meshes[String(node.name)] = _themed_mesh(node.mesh, palette)
		stack.append_array(node.get_children())
	kit.free()

	# Sort the shell: freestanding masonry is a pillar, the rest walls.
	var buckets := {"Wall0": [], "Wall1": [], "Wall2": [], "Pillar": []}
	for tile in shown:
		var alone := true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if blocked_set.has(tile + d):
				alone = false
				break
		if alone:
			buckets["Pillar"].append(tile)
		else:
			buckets["Wall%d" % ((tile.x * 7 + tile.y * 13) % 3)].append(tile)

	for bucket_name in buckets:
		var tiles: Array = buckets[bucket_name]
		if tiles.is_empty() or not kit_meshes.has(bucket_name):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kit_meshes[bucket_name]
		mm.instance_count = tiles.size()
		for i in tiles.size():
			var tile: Vector2i = tiles[i]
			var yaw = (PI / 2.0) * ((tile.x * 5 + tile.y * 3) % 4)
			var base = world_at(Vector2(
				(tile.x + 0.5) * arena.tile_size,
				(tile.y + 0.5) * arena.tile_size
			))
			mm.set_instance_transform(i, Transform3D(
				Basis(Vector3.UP, yaw), base))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)

	if _layout == null:
		return
	# Arches crown every corridor mouth.
	if kit_meshes.has("Arch"):
		for door in _layout.doors:
			var arch := MeshInstance3D.new()
			arch.mesh = kit_meshes["Arch"]
			arch.position = world_at(door.center)
			if not door.horizontal:
				arch.rotation.y = PI / 2.0
			add_child(arch)
	# Rubble where the masonry has settled.
	for i in _layout.rooms.size():
		if (i * 13) % 3 == 0 or not kit_meshes.has("Rubble%d" % (i % 2)):
			continue
		var room: Rect2i = _layout.rooms[i]
		var corner = Vector2(
			(room.position.x + 1.5 + ((i * 7) % (maxi(room.size.x - 3, 1)))),
			(room.position.y + 1.5)) * _layout.arena.tile_size
		var pile := MeshInstance3D.new()
		pile.mesh = kit_meshes["Rubble%d" % (i % 2)]
		pile.position = world_at(corner)
		pile.rotation.y = (i * 2.4)
		add_child(pile)

	# Ecology: every pack seeds its surroundings, so the dungeon shows
	# who LIVES here before a single enemy moves.
	var eco := {"spider": ["Web", "Web", "EggSac", "EggSac"],
		"slime": ["GelPool", "GelPool"], "goblin": ["Campfire"]}
	for pi in _layout.packs.size():
		var pack = _layout.packs[pi]
		var family := _pack_family(pack)
		if family == "" or not eco.has(family):
			continue
		var props: Array = eco[family]
		for k in props.size():
			if not kit_meshes.has(props[k]):
				continue
			var angle = pi * 2.1 + k * (TAU / props.size())
			var dist = 0.0 if props[k] == "Campfire" else (1.6 + 0.5 * ((pi + k) % 3))
			var spot = pack.center + Vector2(cos(angle), sin(angle)) 				* dist * _layout.arena.tile_size
			var prop := MeshInstance3D.new()
			prop.mesh = kit_meshes[props[k]]
			prop.position = world_at(spot)
			prop.rotation.y = angle + PI
			add_child(prop)

	# The landmark: the thing this dungeon is remembered by.
	var lm_path = "res://resources/models/landmark_%s.glb" % dungeon().theme
	if _layout.landmark_room >= 0 and ResourceLoader.exists(lm_path):
		var lm_room: Rect2i = _layout.rooms[_layout.landmark_room]
		var lm = load(lm_path).instantiate()
		var aabb := AABB()
		var lm_stack := [lm]
		while not lm_stack.is_empty():
			var n = lm_stack.pop_back()
			if n is MeshInstance3D:
				var b: AABB = n.get_aabb()
				aabb = b if aabb.size == Vector3.ZERO else aabb.merge(b)
			lm_stack.append_array(n.get_children())
		var lm_scale = 3.4 / maxf(aabb.size.y, 0.01)
		lm.scale = Vector3.ONE * lm_scale
		var spot = Vector2(lm_room.get_center().x + 0.5,
			lm_room.position.y + 2.2) * _layout.arena.tile_size
		lm.position = world_at(spot)
		lm.position.y += -aabb.position.y * lm_scale
		add_child(lm)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.85, 0.55)
		glow.light_energy = 2.4
		glow.omni_range = 6.0
		glow.position = lm.position + Vector3(0, 2.0, 0.8)
		add_child(glow)

## The resident family of a pack: nests outrank puddles outrank camps.
func _pack_family(pack: Dictionary) -> String:
	var ids: Array = pack.templates.map(func(t): return String(t.enemy_id))
	for eid in ids:
		if "spider" in eid or "brood" in eid or "weaver" in eid or "spiderling" in eid:
			return "spider"
	for eid in ids:
		if "slime" in eid or "ooze" in eid or "slick" in eid:
			return "slime"
	for eid in ids:
		if "goblin" in eid:
			return "goblin"
	return ""

## Kit meshes carry solid Arch* materials; dye them to the theme the
## same way garment surfaces dye (per-surface, by material name).
func _themed_mesh(mesh: Mesh, palette: Dictionary) -> Mesh:
	var themed = mesh.duplicate()
	for si in themed.get_surface_count():
		var mat = themed.surface_get_material(si)
		if not (mat is StandardMaterial3D):
			continue
		var mat_name := String(mat.resource_name)
		var tinted: StandardMaterial3D = mat.duplicate()
		if mat_name.contains("Secondary"):
			tinted.albedo_color = palette.secondary
		elif mat_name.contains("Trim"):
			tinted.albedo_color = palette.trim
		elif mat_name.contains("Primary"):
			tinted.albedo_color = palette.primary
		themed.surface_set_material(si, tinted)
	return themed

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
	enemy_sidebar.group_meters = true
	enemy_sidebar.group_units = true
	enemy_sidebar.position = Vector2(1328, 12)
	enemy_sidebar.size = Vector2(260, 876)
	layer.add_child(enemy_sidebar)

	# Replay speed: the player's clock, not the sim's.
	var speed_row := HBoxContainer.new()
	speed_row.position = Vector2(744, 16)
	speed_row.add_theme_constant_override("separation", 6)
	layer.add_child(speed_row)
	var speed_buttons := {}
	for speed in [1.0, 2.0, 3.0]:
		var b := Button.new()
		b.text = "%d×" % int(speed)
		b.custom_minimum_size = Vector2(34, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color",
			Color(0.85, 0.72, 0.42) if speed == 1.0 else Color(0.55, 0.5, 0.42))
		speed_buttons[speed] = b
		b.pressed.connect(func():
			replay_speed = speed
			for sp in speed_buttons:
				speed_buttons[sp].add_theme_color_override("font_color",
					Color(0.85, 0.72, 0.42) if sp == speed
					else Color(0.55, 0.5, 0.42)))
		speed_row.add_child(b)
