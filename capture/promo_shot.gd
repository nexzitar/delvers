extends Node

## The capabilities promo: what Delvers can do today, staged on the
## real game systems and recorded for capture/make_promo.sh.
## Beats: the camp, compiled garments, the continuous dungeon (walk,
## pull, mid-run loot, the King), the guild, the card.

const FONT = preload("res://art/fonts/Herculanum.ttf")
const OUT := "res://capture/proto3d/renders/promo"
const EVERY_NTH := 2
const WIDTH := 1920

var _grab := false
var _rendered := 0
var _saved := 0
var _segment := ""
var _dir: String
var _manifest := {}
var _movie := OS.has_feature("movie")

func _ready():
	_dir = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(_dir)
	RenderingServer.frame_post_draw.connect(_on_frame)
	PlayerRoster.autosave = false
	GameSettings.set_volume("master", 1.0)
	GameSettings.set_volume("music", 0.7)
	GameSettings.set_volume("sfx", 0.85)
	GameSettings.set_volume("ambience", 0.6)
	_run()

func _run():
	# --- 1. The camp ---------------------------------------------------
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.adventures_completed = 1
	PlayerRoster.battles_fought = 14
	PlayerRoster.check_milestones()  # Wren answers the fire
	var stage = CampfireStage3D.new()
	add_child(stage)
	await _settle()
	stage.camera.position = Vector3(-2.5, 3.4, 8.4)
	stage.camera.look_at(Vector3(-2.0, 0.5, 0))
	var drift = create_tween()
	drift.tween_property(stage.camera, "position", Vector3(0.4, 2.7, 7.0), 6.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title("DELVERS", "A world compiled, not assembled.", 0.8, 6.0)
	await _record("01_camp", 6.5)
	stage.queue_free()
	await _settle()

	# --- 2. The wardrobe: garments compiled from the body ---------------
	var wardrobe := Node3D.new()
	add_child(wardrobe)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.09, 0.11, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.52, 0.54, 0.52)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	wardrobe.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.shadow_enabled = true
	wardrobe.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.2, 0.25, 0.19)
	gmat.roughness = 1.0
	ground.material_override = gmat
	wardrobe.add_child(ground)
	var outfits = [
		{"model": "res://resources/models/delver_male.glb",
			"pieces": ["starter_armor", "starter_trousers", "starter_boots",
				"starter_gloves", "starter_belt"]},
		{"model": "res://resources/models/delver_male.glb",
			"pieces": ["oiled_leathers", "leather_trousers", "iron_shod_boots"]},
		{"model": "res://resources/models/delver_female.glb",
			"pieces": ["starter_headband", "starter_armor", "leather_trousers",
				"iron_shod_boots"],
			"dye": {"primary": Color(0.2, 0.3, 0.16),
				"secondary": Color(0.12, 0.18, 0.1),
				"trim": Color(0.5, 0.45, 0.28), "flatten": 0.9}},
		{"model": "res://resources/models/delver_male.glb",
			"pieces": ["oiled_leathers", "leather_trousers", "iron_shod_boots"],
			"dye": {"primary": Color(0.36, 0.14, 0.12),
				"secondary": Color(0.2, 0.09, 0.08),
				"trim": Color(0.6, 0.5, 0.34), "flatten": 0.9}},
	]
	for i in outfits.size():
		var outfit = outfits[i]
		var config = ActorFactory3D.MODEL_CONFIGS[outfit.model].duplicate(true)
		var actor = AnimatedActor.new(load(outfit.model), config)
		actor.position = Vector3(-1.5 + i * 1.0, 0, 0)
		actor.rotation.y = 0.15 - i * 0.1
		wardrobe.add_child(actor)
		for piece_id in outfit.pieces:
			actor._mount_worn_model(piece_id)
		if outfit.has("dye"):
			for fit_key in actor.worn_mounts:
				if not fit_key in ["jacket", "jacket_plain", "pants"]:
					continue
				for piece in actor.worn_mounts[fit_key]:
					actor._recolor(piece, outfit.dye)
		if i == 2:
			actor.pose_swing(0.5)
		else:
			actor.pose_idle(1.0 + i * 1.7)
	var wcam := Camera3D.new()
	wcam.fov = 38
	wardrobe.add_child(wcam)
	wcam.position = Vector3(-1.6, 1.1, 3.4)
	wcam.look_at(Vector3(-1.2, 0.62, 0))
	wcam.current = true
	var dolly = create_tween()
	dolly.tween_property(wcam, "position", Vector3(1.6, 1.3, 3.8), 7.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dolly.parallel().tween_method(
		func(t): wcam.look_at(Vector3(lerpf(-1.2, 1.0, t), 0.62, 0)),
		0.0, 1.0, 7.6)
	_title("", "Every garment compiled from the delver's own body.", 0.8, 6.5)
	await _record("02_wardrobe", 8.0)
	wardrobe.queue_free()
	await _settle()

	# --- 3-6. The continuous dungeon ------------------------------------
	# A party strong enough to make the far door on camera.
	PlayerRoster.heroes[0].equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize(
			"starter_sword", 7, ItemQuality.Tier.RARE, "virulent"),
		Equip.Position.OFF_HAND: LootTable.materialize(
			"starter_shield", 7, ItemQuality.Tier.UNCOMMON),
		Equip.Position.HEAD: LootTable.materialize(
			"starter_helmet", 7, ItemQuality.Tier.UNCOMMON),
		Equip.Position.CHEST: LootTable.materialize(
			"starter_armor", 7, ItemQuality.Tier.UNCOMMON),
		Equip.Position.LEGS: LootTable.materialize(
			"leather_trousers", 7, ItemQuality.Tier.UNCOMMON),
		Equip.Position.FEET: LootTable.materialize(
			"starter_boots", 7, ItemQuality.Tier.COMMON),
		Equip.Position.HANDS: LootTable.materialize(
			"starter_gloves", 7, ItemQuality.Tier.COMMON),
		Equip.Position.WAIST: LootTable.materialize(
			"starter_belt", 7, ItemQuality.Tier.COMMON),
	}
	PlayerRoster._sync_role(PlayerRoster.heroes[0])
	if PlayerRoster.heroes.size() > 1:
		PlayerRoster.heroes[1].equipped = {
			Equip.Position.MAIN_HAND: LootTable.materialize(
				"starter_bow", 7, ItemQuality.Tier.RARE),
			Equip.Position.HEAD: LootTable.materialize(
				"starter_headband", 7, ItemQuality.Tier.COMMON),
			Equip.Position.CHEST: LootTable.materialize(
				"starter_armor", 7, ItemQuality.Tier.UNCOMMON),
			Equip.Position.LEGS: LootTable.materialize(
				"leather_trousers", 7, ItemQuality.Tier.UNCOMMON),
			Equip.Position.FEET: LootTable.materialize(
				"starter_boots", 7, ItemQuality.Tier.COMMON),
		}
		PlayerRoster._sync_role(PlayerRoster.heroes[1])
	PlayerRoster.equip_bonus_skill(0, load("res://resources/skills/heal.tres"), 1)

	# The King must fall on camera: retry the compile until the party
	# proves it can walk the whole dungeon.
	var theater = null
	var king_death := 0.0
	for attempt in 5:
		PlayerRoster.start_delve()
		theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
		add_child(theater)
		get_tree().current_scene = theater
		await _settle()
		king_death = 0.0
		for item in theater._timeline:
			if item.kind == "event" and item.event.type == CombatEvent.EventType.DEATH \
					and item.event.target_name.begins_with("Slime King"):
				king_death = item.time
		if king_death > 0.0:
			break
		theater.queue_free()
		await _settle()

	_title("", "One dungeon. Walked end to end. No teleports.", 1.2, 7.5)
	await _record("03_setout", 9.0)

	# Forward to the first pull.
	var first_pull := 0.0
	var pack_falls: Array[float] = []
	for item in theater._timeline:
		if item.kind != "event":
			continue
		if item.event.type == CombatEvent.EventType.PACK_PULLED \
				and first_pull == 0.0:
			first_pull = item.time
		if item.event.type == CombatEvent.EventType.PACK_DEFEATED:
			pack_falls.append(item.time)
	if first_pull > theater._clock + 2.0:
		theater._clock = first_pull - 1.5
	_title("", "Packs sleep until you wake them. Pulls are real.", 0.8, 7.0)
	await _record("04_pull", 9.0)

	# Forward to a mid-run pack kill: the loot toast lands on camera.
	for t in pack_falls:
		if t > theater._clock + 4.0:
			theater._clock = t - 4.0
			break
	_title("", "Loot banks mid-run. The party presses on.", 2.0, 6.5)
	await _record("05_loot", 9.0)

	# Forward to the King's last stand.
	if king_death - 6.5 > theater._clock:
		theater._clock = king_death - 6.5
	_title("", "And the King still waits in room ten.", 1.0, 6.5)
	await _record("06_king", 9.5)
	theater.queue_free()
	await _settle()

	# --- 7. The guild --------------------------------------------------
	PlayerRoster.material_stash = {"gel": 6, "ash_wood": 4, "iron_scrap": 6,
		"leather": 4, "royal_jelly": 1}
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	get_tree().current_scene = camp
	await _settle()
	var stage2 = camp.stage
	stage2.camera.position = Vector3(0, 2.4, 5.6)
	stage2.camera.look_at(Vector3(0, 0.5, 0))
	var rise = create_tween()
	rise.tween_property(stage2.camera, "position", Vector3(1.6, 3.2, 6.4), 6.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title("", "Every run makes the guild wiser.", 1.0, 5.5)
	await _record("07_guild", 6.5)
	camp.queue_free()
	await _settle()

	# --- 8. Outro -------------------------------------------------------
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.04)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outro_layer := CanvasLayer.new()
	outro_layer.layer = 30
	outro_layer.add_child(black)
	add_child(outro_layer)
	_title("DELVERS", "Built by two brothers' worth of stubbornness.", 0.5, 4.5, 31)
	await _record("08_outro", 5.0)

	var manifest := FileAccess.open(OUT + "/manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_manifest))
	print("PROMO SEGMENTS DONE")
	get_tree().quit()

func _settle():
	await get_tree().process_frame
	await get_tree().process_frame

func _record(segment: String, seconds: float):
	if _movie:
		var start = Engine.get_process_frames()
		await get_tree().create_timer(seconds).timeout
		_manifest[segment] = {
			"start_frame": start,
			"end_frame": Engine.get_process_frames(),
		}
		print("segment %s: movie frames %d-%d" % [
			segment, start, Engine.get_process_frames()])
		return
	DirAccess.make_dir_recursive_absolute("%s/%s" % [_dir, segment])
	_segment = segment
	_saved = 0
	_rendered = 0
	_grab = true
	await get_tree().create_timer(seconds).timeout
	_grab = false
	_manifest[segment] = {"frames": _saved, "seconds": seconds}
	print("segment %s: %d frames / %.1fs" % [segment, _saved, seconds])

func _on_frame():
	if _movie or not _grab:
		return
	_rendered += 1
	if _rendered % EVERY_NTH != 0:
		return
	var img = get_viewport().get_texture().get_image()
	var height = int(WIDTH * img.get_height() / float(img.get_width()))
	img.resize(WIDTH, height, Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/%s/frame_%05d.png" % [_dir, _segment, _saved])
	_saved += 1

func _title(big: String, small: String, delay: float, hold: float, on_layer := 20):
	var layer := CanvasLayer.new()
	layer.layer = on_layer
	add_child(layer)
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.68
	box.anchor_bottom = 0.9
	box.add_theme_constant_override("separation", 10)
	layer.add_child(box)
	if big != "":
		var title := Label.new()
		title.text = big
		title.add_theme_font_override("font", FONT)
		title.add_theme_font_size_override("font_size", 110)
		title.add_theme_color_override("font_color", Color(0.85, 0.72, 0.42))
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 14)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
	if small != "":
		var sub := Label.new()
		sub.text = small
		sub.add_theme_font_override("font", FONT)
		sub.add_theme_font_size_override("font_size", 40)
		sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		sub.add_theme_color_override("font_outline_color", Color.BLACK)
		sub.add_theme_constant_override("outline_size", 8)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(box, "modulate:a", 1.0, 0.7)
	tween.tween_interval(maxf(0.5, hold - delay - 1.9))
	tween.tween_property(box, "modulate:a", 0.0, 1.2)
	tween.tween_callback(layer.queue_free)
