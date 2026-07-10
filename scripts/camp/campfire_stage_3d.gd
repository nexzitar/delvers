extends Node3D
class_name CampfireStage3D

## 3D night clearing shared by the main menu and the camp: a crackling
## low-poly campfire, log seats in a ring, and the party seated around
## it. Same contract as the old 2D stage: `hero_selected` when a seated
## hero is clicked (camp only), `refresh_hero` after loadout changes,
## `set_picking` while modals are open.

signal hero_selected(hero_index: int)

const DelverRig = preload("res://scripts/theater3d/delver_rig.gd")
const NAMEPLATE_FONT = preload("res://art/fonts/Herculanum.ttf")

const SEAT_COUNT := 10
const SEAT_RING_RADIUS := 2.35
const LOG_TOP := 0.3

## Camp scene turns this on to let the player pick heroes.
@export var interactive := false
## "menu" frames the clearing wide; "camp" sits closer to the fire.
@export var framing := "menu"

const MENU_CAMERA := {"position": Vector3(-1.9, 2.6, 7.0), "look": Vector3(-1.6, 0.7, 0)}
const CAMP_CAMERA := {"position": Vector3(0, 3.1, 5.2), "look": Vector3(0, 0.4, 0)}

var camera: OrbitCamera
var _flames: Array = []
var _embers: Array = []
var _fire_light: OmniLight3D
var _intensity := 0.15
var _time := randf() * 100.0

# hero_index -> {"seat_name": String, "rig": Node3D, "anchor": Vector3,
#   "plate": Label, "ring": MeshInstance3D, "phase": float}
var _seated := {}
var _plates_layer: CanvasLayer
var _picking_enabled := true
var _hovered := -1
var _was_pressed := false

func _ready():
	_intensity = PlayerRoster.fire_intensity()
	_setup_world()
	_build_history()
	_build_campfire()
	_build_seats()
	_seat_heroes()
	apply_framing(framing)

## Points the camera at this scene's framing preset.
func apply_framing(which: String):
	framing = which
	var preset = CAMP_CAMERA if which == "camp" else MENU_CAMERA
	camera.position = preset.position
	camera.look_at(preset.look)
	# At camp the player may circle the fire: right-drag orbits, the
	# wheel zooms. The menu stays scripted.
	camera.enabled = which == "camp"
	if camera.enabled:
		camera.target = preset.look
		camera.orbit_button = MOUSE_BUTTON_RIGHT
		camera.adopt_current()

## Menu -> camp: glide the camera to the camp framing (the party keeps
## their seats via PlayerRoster.keep_seating).
func transition_to_camp(duration: float) -> Tween:
	camera.enabled = false
	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "position", CAMP_CAMERA.position, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var start_look = MENU_CAMERA.look
	tween.tween_method(
		func(k):
			camera.look_at(start_look.lerp(CAMP_CAMERA.look, k)),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func():
		framing = "camp"
		camera.enabled = true
		camera.target = CAMP_CAMERA.look
		camera.orbit_button = MOUSE_BUTTON_RIGHT
		camera.adopt_current())
	return tween

# --- Party ---------------------------------------------------------------

func _seat_positions() -> Dictionary:
	# Ring around the fire, skipping the arc directly behind it from the
	# camera so no one has their back squarely to the viewer.
	var out := {}
	for i in SEAT_COUNT:
		var a = TAU * (0.62 + float(i) / SEAT_COUNT)
		out["Seat%d" % (i + 1)] = Vector3(
			SEAT_RING_RADIUS * sin(a), 0, SEAT_RING_RADIUS * cos(a)
		)
	return out

func _build_seats():
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5e4630")
	wood.roughness = 1.0
	for seat_name in _seat_positions():
		var pos: Vector3 = _seat_positions()[seat_name]
		var log := CylinderMesh.new()
		log.top_radius = 0.16
		log.bottom_radius = 0.16
		log.height = 0.85
		log.radial_segments = 8
		var mesh := MeshInstance3D.new()
		mesh.mesh = log
		mesh.material_override = wood
		mesh.position = pos + Vector3(0, 0.16, 0)
		# Lying down, tangent to the fire ring.
		mesh.rotation_degrees = Vector3(90, rad_to_deg(atan2(pos.x, pos.z)) + 90, 0)
		add_child(mesh)

func _seat_heroes():
	_plates_layer = CanvasLayer.new()
	add_child(_plates_layer)

	var assignment = _resolve_seating()
	var positions = _seat_positions()
	for seat_name in assignment:
		_spawn_seated(seat_name, positions[seat_name], assignment[seat_name])

## Rebuilds a hero's seated rig in place (e.g. after a loadout change).
func refresh_hero(hero_index: int):
	if not _seated.has(hero_index):
		return
	var record = _seated[hero_index]
	if is_instance_valid(record.rig):
		record.rig.queue_free()
	if is_instance_valid(record.plate):
		record.plate.queue_free()
	if is_instance_valid(record.ring):
		record.ring.queue_free()
	var seat_name: String = record.seat_name
	_spawn_seated(seat_name, _seat_positions()[seat_name], hero_index)

func _spawn_seated(seat_name: String, seat_pos: Vector3, hero_index: int):
	var template = PlayerRoster.heroes[hero_index]
	var rig = ActorFactory3D.build_hero(template.equipped,
		template.model_scene.resource_path if template.model_scene else "")
	add_child(rig)
	# Perched on the log, facing the fire.
	rig.position = seat_pos + Vector3(0, LOG_TOP - 0.06, 0)
	rig.rotation.y = atan2(-seat_pos.x, -seat_pos.z)

	var plate: Label = null
	var ring: MeshInstance3D = null
	if interactive:
		plate = _make_nameplate(template.hero_name)
		_plates_layer.add_child(plate)
		ring = _make_hover_ring()
		add_child(ring)
		ring.position = Vector3(seat_pos.x, 0.02, seat_pos.z)

	_seated[hero_index] = {
		"seat_name": seat_name, "rig": rig,
		"anchor": rig.position + Vector3(0, 0.75, 0),
		"plate": plate, "ring": ring,
		"phase": randf() * 100.0,
	}

func _make_nameplate(text: String) -> Label:
	var plate := Label.new()
	plate.text = text
	plate.add_theme_font_override("font", NAMEPLATE_FONT)
	plate.add_theme_font_size_override("font_size", 30)
	plate.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	plate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	plate.add_theme_constant_override("outline_size", 8)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.size = Vector2(260, 40)
	plate.visible = false
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate

func _make_hover_ring() -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.5
	ring.rings = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.8, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.75, 0.3)
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.material_override = mat
	mesh.visible = false
	return mesh

# --- Hover & pick --------------------------------------------------------

func _process(delta):
	_time += delta
	_animate_fire()
	for record in _seated.values():
		if is_instance_valid(record.rig):
			record.rig.pose_sit(_time + record.phase)

	if not interactive or not _picking_enabled:
		return

	var mouse = get_viewport().get_mouse_position()
	var hovered = _hit_test(mouse)
	if hovered != _hovered:
		_set_hover(_hovered, false)
		_set_hover(hovered, true)
		_hovered = hovered
	if _hovered != -1:
		_position_plate(_hovered)

	var pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not _was_pressed and hovered != -1:
		hero_selected.emit(hovered)
	_was_pressed = pressed

## Screen-space picking: nearest seated hero whose projected anchor is
## within reach of the cursor.
func _hit_test(mouse: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for hero_index in _seated:
		var record = _seated[hero_index]
		if camera.is_position_behind(record.anchor):
			continue
		var screen = camera.unproject_position(record.anchor)
		var d = (screen - mouse).length()
		if d < 85.0 and d < best_dist:
			best_dist = d
			best = hero_index
	return best

func _set_hover(hero_index: int, on: bool):
	if hero_index == -1 or not _seated.has(hero_index):
		return
	var record = _seated[hero_index]
	if is_instance_valid(record.plate):
		record.plate.visible = on
	if is_instance_valid(record.ring):
		record.ring.visible = on

func _position_plate(hero_index: int):
	var record = _seated[hero_index]
	if not is_instance_valid(record.plate):
		return
	var screen = camera.unproject_position(record.anchor + Vector3(0, 0.55, 0))
	record.plate.position = screen - Vector2(130, 20)

func set_picking(enabled):
	_picking_enabled = enabled
	if not enabled:
		clear_hover()

func clear_hover():
	_set_hover(_hovered, false)
	_hovered = -1

func _resolve_seating() -> Dictionary:
	var seat_names := _seat_positions().keys()

	if PlayerRoster.keep_seating:
		PlayerRoster.keep_seating = false
		if _seating_valid(PlayerRoster.saved_seating, seat_names):
			return PlayerRoster.saved_seating

	seat_names.shuffle()
	var assignment := {}
	for i in mini(PlayerRoster.heroes.size(), seat_names.size()):
		assignment[seat_names[i]] = i
	PlayerRoster.saved_seating = assignment
	return assignment

func _seating_valid(assignment, seat_names) -> bool:
	if assignment.size() != mini(PlayerRoster.heroes.size(), seat_names.size()):
		return false
	for seat_name in assignment:
		if not seat_names.has(seat_name):
			return false
	return true

# --- Fire & world ---------------------------------------------------------

func _build_campfire():
	# Stone ring.
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("62605c")
	stone.roughness = 1.0
	for i in 9:
		var a = TAU * i / 9.0
		var rock := SphereMesh.new()
		rock.radius = 0.11 + 0.02 * (i % 3)
		rock.height = rock.radius * 1.4
		rock.radial_segments = 7
		rock.rings = 4
		var mesh := MeshInstance3D.new()
		mesh.mesh = rock
		mesh.material_override = stone
		mesh.position = Vector3(0.62 * sin(a), 0.05, 0.62 * cos(a))
		add_child(mesh)

	# Crossed logs.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("4a3524")
	wood.roughness = 1.0
	for i in 3:
		var log := CylinderMesh.new()
		log.top_radius = 0.07
		log.bottom_radius = 0.07
		log.height = 0.8
		log.radial_segments = 7
		var mesh := MeshInstance3D.new()
		mesh.mesh = log
		mesh.material_override = wood
		mesh.rotation_degrees = Vector3(75, i * 120.0, 0)
		mesh.position = Vector3(0, 0.18, 0)
		add_child(mesh)

	# Low-poly flames: layered emissive cones, anchored at the fire bed
	# so flicker scaling never detaches them from the logs.
	var flame_colors = [Color("ff7a24"), Color("ffb43a"), Color("ffe08a")]
	var flame_sizes = [0.5, 0.35, 0.2]
	var flame_heights = [0.95, 0.72, 0.5]
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = flame_sizes[i]
		cone.height = flame_heights[i]
		cone.radial_segments = 7
		var mat := StandardMaterial3D.new()
		mat.albedo_color = flame_colors[i]
		mat.emission_enabled = true
		mat.emission = flame_colors[i]
		mat.emission_energy_multiplier = 2.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh := MeshInstance3D.new()
		mesh.mesh = cone
		mesh.material_override = mat
		add_child(mesh)
		_flames.append({"node": mesh, "height": flame_heights[i]})

	# Drifting embers: tiny emissive cubes looping upward.
	for i in 6:
		var spark := BoxMesh.new()
		spark.size = Vector3.ONE * 0.035
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ffb03a")
		mat.emission_enabled = true
		mat.emission = Color("ff9030")
		mat.emission_energy_multiplier = 2.2
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh := MeshInstance3D.new()
		mesh.mesh = spark
		mesh.material_override = mat
		add_child(mesh)
		_embers.append({"node": mesh, "phase": randf() * 10.0, "angle": randf() * TAU})

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.62, 0.3)
	_fire_light.omni_range = 9.0
	_fire_light.position = Vector3(0, 0.9, 0)
	_fire_light.shadow_enabled = true
	add_child(_fire_light)

func _animate_fire():
	var flicker = (
		0.75
		+ 0.18 * sin(_time * 2.3)
		+ 0.12 * sin(_time * 5.7 + 1.3)
	)
	var vigor = 0.55 + _intensity * 0.55
	for i in _flames.size():
		var flame = _flames[i]
		var s = vigor * (flicker + 0.1 * i)
		flame.node.scale = Vector3.ONE * s
		flame.node.rotation.z = 0.05 * sin(_time * (3.0 + i) + i * 2.0)
		# Cylinder meshes center vertically: lift by half the scaled
		# height so the flame base stays planted on the fire bed.
		flame.node.position = Vector3(0, 0.2 + flame.height * 0.5 * s, 0)
	_fire_light.light_energy = (1.6 + _intensity * 2.4) * flicker

	# Embers spiral up and respawn at the base.
	for ember in _embers:
		var k = fmod(_time * 0.35 + ember.phase, 1.0)
		var visible_count = 1 + int(_intensity * (_embers.size() - 1))
		ember.node.visible = _embers.find(ember) < visible_count
		var r = 0.15 + k * 0.25
		ember.node.position = Vector3(
			r * sin(ember.angle + k * 4.0),
			0.4 + k * 1.6,
			r * cos(ember.angle + k * 4.0)
		)
		ember.node.scale = Vector3.ONE * (1.0 - k)

## Environmental storytelling: the clearing carries the previous
## guild's ruin, and rebuilds itself as this one earns it. Nothing is
## narrated — the player just sees it.
func _build_history():
	# The wreck of the Black Hollow: a broken cart, always.
	var cart := Node3D.new()
	cart.position = Vector3(-3.7, 0, -1.9)
	cart.rotation.y = 0.7
	add_child(cart)
	var bed := _prop(cart, BoxMesh.new(), Color("4a3524"), Vector3(0, 0.28, 0))
	bed.mesh.size = Vector3(1.3, 0.1, 0.75)
	bed.rotation.z = 0.32
	for side in [-1, 1]:
		var rail := _prop(cart, BoxMesh.new(), Color("3c2b1e"),
			Vector3(0.1, 0.42, side * 0.36))
		rail.mesh.size = Vector3(1.2, 0.16, 0.05)
		rail.rotation.z = 0.32
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.3
	wheel.bottom_radius = 0.3
	wheel.height = 0.07
	wheel.radial_segments = 9
	var up_wheel := _prop(cart, wheel, Color("332419"), Vector3(-0.55, 0.3, 0.42))
	up_wheel.rotation.x = PI / 2
	var flat_wheel := _prop(cart, wheel.duplicate(), Color("332419"),
		Vector3(0.75, 0.04, -0.5))
	flat_wheel.rotation.z = 0.15

	# The guild banner: fallen among the tents — until the Slime King
	# falls, and it flies again.
	var banner := Node3D.new()
	banner.position = Vector3(3.5, 0, -2.5)
	add_child(banner)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.035
	pole.bottom_radius = 0.045
	pole.height = 2.2
	var restored: bool = PlayerRoster.adventures_completed >= 1
	if restored:
		var standing := _prop(banner, pole, Color("4a3524"), Vector3(0, 1.1, 0))
		standing.rotation.z = 0.03
		var cloth := _prop(banner, BoxMesh.new(), Color("7a2f2a"),
			Vector3(0.3, 1.75, 0))
		cloth.mesh.size = Vector3(0.55, 0.5, 0.03)
		var trim := _prop(banner, BoxMesh.new(), Color("d8c684"),
			Vector3(0.3, 1.52, 0))
		trim.mesh.size = Vector3(0.55, 0.05, 0.035)
	else:
		var leaning := _prop(banner, pole, Color("3c2b1e"), Vector3(0.5, 0.5, 0))
		leaning.rotation.z = 1.25
		var rag := _prop(banner, BoxMesh.new(), Color("4d3430"),
			Vector3(1.15, 0.09, 0))
		rag.mesh.size = Vector3(0.6, 0.14, 0.03)
		rag.rotation.z = 0.9

	# The forge's anvil returns once the guild has knowledge worth
	# hammering into shape.
	if PlayerRoster.known_recipes.size() >= 3:
		var forge := Node3D.new()
		forge.position = Vector3(4.1, 0, -0.4)
		forge.rotation.y = -0.5
		add_child(forge)
		var stump := CylinderMesh.new()
		stump.top_radius = 0.24
		stump.bottom_radius = 0.28
		stump.height = 0.42
		stump.radial_segments = 8
		_prop(forge, stump, Color("4a3524"), Vector3(0, 0.21, 0))
		var anvil := _prop(forge, BoxMesh.new(), Color("3a3d44"), Vector3(0, 0.5, 0))
		anvil.mesh.size = Vector3(0.5, 0.16, 0.2)
		var horn := _prop(forge, BoxMesh.new(), Color("32353b"), Vector3(0.3, 0.5, 0))
		horn.mesh.size = Vector3(0.16, 0.1, 0.12)

	# A training dummy, once the guild has seen real fighting.
	if PlayerRoster.battles_fought >= 15:
		var dummy := Node3D.new()
		dummy.position = Vector3(-4.1, 0, 0.9)
		dummy.rotation.y = 0.9
		add_child(dummy)
		var post := CylinderMesh.new()
		post.top_radius = 0.05
		post.bottom_radius = 0.06
		post.height = 1.3
		_prop(dummy, post, Color("4a3524"), Vector3(0, 0.65, 0))
		var arms := _prop(dummy, BoxMesh.new(), Color("4a3524"), Vector3(0, 1.0, 0))
		arms.mesh.size = Vector3(0.9, 0.07, 0.07)
		var head := SphereMesh.new()
		head.radius = 0.13
		head.height = 0.26
		head.radial_segments = 8
		head.rings = 4
		_prop(dummy, head, Color("b9a05e"), Vector3(0, 1.4, 0))

func _prop(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance

func _setup_world():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d0f18")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("36405e")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Cold moonlight against the warm fire.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, 140, 0)
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.25
	add_child(moon)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2d3226")
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	# A few scattered rocks and tufts for depth.
	for i in 12:
		var a = i * 2.4 + 1.3
		var mesh := MeshInstance3D.new()
		var prop_mat := StandardMaterial3D.new()
		prop_mat.roughness = 1.0
		if i % 2 == 0:
			var rock := SphereMesh.new()
			rock.radius = 0.09 + 0.03 * (i % 3)
			rock.height = rock.radius * 1.2
			rock.radial_segments = 7
			rock.rings = 4
			mesh.mesh = rock
			prop_mat.albedo_color = Color("41453c")
		else:
			var tuft := BoxMesh.new()
			tuft.size = Vector3(0.06, 0.16, 0.06)
			mesh.mesh = tuft
			mesh.position.y = 0.08
			prop_mat.albedo_color = Color("3c4a30")
		mesh.material_override = prop_mat
		mesh.position += Vector3(
			(4.0 + 2.5 * sin(i * 1.7)) * sin(a), 0,
			(4.0 + 2.5 * cos(i * 2.1)) * cos(a)
		)
		add_child(mesh)

	camera = OrbitCamera.new()
	camera.fov = 38
	add_child(camera)
