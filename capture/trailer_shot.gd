extends Node

## The Chapter One vertical-slice trailer: stages the nine story beats
## in sequence and records frame segments for capture/make_trailer.sh.
## Everything runs on the real game systems — nothing is mocked.

const FONT = preload("res://art/fonts/Herculanum.ttf")
const OUT := "res://capture/proto3d/renders/trailer"
const EVERY_NTH := 2
const WIDTH := 1920

var _grab := false
var _rendered := 0
var _saved := 0
var _segment := ""
var _dir: String
var _manifest := {}
## Movie Maker mode (--write-movie --fixed-fps 30): the engine writes
## every frame itself; we only log segment frame ranges to cut later.
var _movie := OS.has_feature("movie")

func _ready():
	_dir = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(_dir)
	RenderingServer.frame_post_draw.connect(_on_frame)
	PlayerRoster.autosave = false
	# The render mixes its own soundtrack regardless of the local
	# settings file (applied only in memory, never saved).
	GameSettings.set_volume("master", 1.0)
	GameSettings.set_volume("music", 0.7)
	GameSettings.set_volume("sfx", 0.85)
	GameSettings.set_volume("ambience", 0.6)
	if _movie:
		print("movie mode: logging segment ranges")
	_run()

func _run():
	# --- 1. The abandoned camp -----------------------------------------
	PlayerRoster._build_heroes()
	PlayerRoster._build_stash()
	PlayerRoster.adventures_completed = 0
	PlayerRoster.battles_fought = 0
	var stage = CampfireStage3D.new()
	add_child(stage)
	await _settle()
	# Slow push past the ruins toward the lonely fire.
	stage.camera.position = Vector3(-2.5, 3.4, 8.4)
	stage.camera.look_at(Vector3(-2.0, 0.5, 0))
	var drift = create_tween()
	drift.set_parallel(true)
	drift.tween_property(stage.camera, "position", Vector3(0.4, 2.7, 7.0), 6.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title("DELVERS", "The camp was not always empty.", 0.8, 6.0)
	await _record("01_camp", 6.5)
	stage.queue_free()
	await _settle()

	# --- 2. Entering the Darkwood --------------------------------------
	PlayerRoster.start_delve()
	PlayerRoster.delve_room = 1
	PlayerRoster.equip_bonus_skill(0, load("res://resources/skills/heal.tres"), 1)
	var theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(theater)
	get_tree().current_scene = theater
	await _settle()
	await _record("02_darkwood", 5.0)
	theater.queue_free()
	await _settle()

	# --- 3. Combat: poison and arrows -----------------------------------
	# Mid-delve kit: he holds the line instead of dying on camera.
	PlayerRoster.heroes[0].equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize(
			"starter_sword", 5, ItemQuality.Tier.UNCOMMON),
		Equip.Position.OFF_HAND: LootTable.materialize(
			"starter_shield", 5, ItemQuality.Tier.UNCOMMON),
		Equip.Position.HEAD: LootTable.materialize(
			"starter_helmet", 5, ItemQuality.Tier.UNCOMMON),
		Equip.Position.CHEST: LootTable.materialize(
			"starter_armor", 5, ItemQuality.Tier.UNCOMMON),
	}
	PlayerRoster._sync_role(PlayerRoster.heroes[0])
	PlayerRoster.delve_room = 5
	theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(theater)
	get_tree().current_scene = theater
	await _settle()
	await get_tree().create_timer(2.0).timeout
	_title("", "Monsters drop resources and knowledge.", 1.5, 6.0)
	await _record("03_combat", 8.0)

	# --- 4. Recovering a tome -------------------------------------------
	theater._show_room_toast(5, theater._drop_entries(
		[], {"poison_sac": 2, "iron_scrap": 2}, [], ["virulent"]
	))
	await _record("04_tome", 4.5)
	theater.queue_free()
	await _settle()

	# --- 5. Crafting the Virulent Sword ---------------------------------
	PlayerRoster.known_recipes = ["iron_sword", "reinforced_shield"]
	PlayerRoster.known_affixes = ["virulent"]
	PlayerRoster.material_stash = {"iron_scrap": 4, "gel": 5, "poison_sac": 2}
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	get_tree().current_scene = camp
	await _settle()
	var loadout = camp.loadout
	loadout.open(0)
	for tabs in loadout.find_children("*", "TabContainer", true, false):
		tabs.current_tab = 2
	loadout._forge_affix_choice["iron_sword"] = "virulent"
	loadout._forge_selected = "iron_sword"
	loadout._fill_forge()
	_title("", "Craft the build you want.", 0.6, 5.0)
	var craft_at = get_tree().create_timer(3.0)
	craft_at.timeout.connect(func():
		PlayerRoster.craft(load("res://resources/recipes/iron_sword.tres"), "virulent")
		loadout.refresh())
	await _record("05_forge", 6.0)
	camp.queue_free()
	await _settle()

	# --- 6. The Slime King falls ----------------------------------------
	PlayerRoster.adventures_completed = 0
	PlayerRoster.check_milestones()  # no-op: keeps the party solo here
	PlayerRoster.heroes[0].equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize(
			"starter_sword", 8, ItemQuality.Tier.RARE, "virulent"),
		Equip.Position.OFF_HAND: LootTable.materialize(
			"starter_shield", 8, ItemQuality.Tier.RARE),
		Equip.Position.HEAD: LootTable.materialize(
			"starter_helmet", 8, ItemQuality.Tier.UNCOMMON),
		Equip.Position.CHEST: LootTable.materialize(
			"starter_armor", 8, ItemQuality.Tier.UNCOMMON),
	}
	PlayerRoster._sync_role(PlayerRoster.heroes[0])
	PlayerRoster.start_delve()
	PlayerRoster.delve_room = 10
	theater = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(theater)
	get_tree().current_scene = theater
	await _settle()
	# Jump the replay clock to just before the King himself falls.
	var king_death := 0.0
	for item in theater._timeline:
		if item.kind == "event" and item.event.type == CombatEvent.EventType.DEATH \
				and item.event.target_name.begins_with("Slime King"):
			king_death = item.time
	theater._clock = maxf(0.0, king_death - 6.0)
	await _record("06_king", 9.5)
	theater.queue_free()
	await _settle()

	# --- 7. The banner rises; Wren arrives -------------------------------
	PlayerRoster.adventures_completed = 1
	PlayerRoster.battles_fought = 14
	PlayerRoster.check_milestones()
	var camp2 = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp2)
	get_tree().current_scene = camp2
	await _settle()
	var stage2 = camp2.stage
	stage2.camera.position = Vector3(0, 2.4, 5.6)
	stage2.camera.look_at(Vector3(0, 0.5, 0))
	var rise = create_tween()
	rise.set_parallel(true)
	rise.tween_property(stage2.camera, "position", Vector3(1.6, 3.2, 6.4), 6.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _record("07_banner", 7.0)

	# --- 8. The Guild restored -------------------------------------------
	PlayerRoster.material_stash = {"gel": 6, "ash_wood": 4, "corrosion_core": 2,
		"iron_scrap": 6, "leather": 4}
	camp2._on_guild_pressed()
	await _record("08_guild", 5.0)
	camp2.queue_free()
	await _settle()

	# --- 9. Outro ---------------------------------------------------------
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.04)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outro_layer := CanvasLayer.new()
	outro_layer.layer = 30
	outro_layer.add_child(black)
	add_child(outro_layer)
	_title("DELVERS", "Chapter One: The Darkwood", 0.5, 4.0, 31)
	await _record("09_outro", 4.5)

	var manifest := FileAccess.open(OUT + "/manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_manifest))
	print("TRAILER SEGMENTS DONE")
	get_tree().quit()

# --- Recording rig -------------------------------------------------------

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

## A title card that fades in and out over the running scene.
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
