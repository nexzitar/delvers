extends Node2D
class_name CampfireStage

## Shared backdrop for the main menu and the camp scene: the night
## clearing, the smoldering fire, and the party seated around it.
##
## When `interactive` is on (the camp scene), seated heroes can be
## hovered for an outline + nameplate and clicked to open their
## loadout, via the `hero_selected` signal.

signal hero_selected(hero_index: int)

## Distance from an actor's origin (sprite center) down to its feet.
const ACTOR_FOOT_OFFSET = 104.0

const OUTLINE_SHADER = preload("res://art/shaders/sprite_outline.gdshader")
const NAMEPLATE_FONT = preload("res://art/fonts/Herculanum.ttf")

## Slight scale-up for a more intimate framing, pivoting on the fire.
@export var zoom := 1.0
@export var zoom_center := Vector2(820, 620)

## Camp scene turns this on to let the player pick heroes.
@export var interactive := false

@onready var seats_root = $Seats
@onready var campfire = $Seats/Campfire

# hero_index -> { "seat": Marker2D, "actor": Node2D, "plate": Control }
var _seated := {}

func _ready():

	if zoom != 1.0:
		scale = Vector2.ONE * zoom
		position = zoom_center * (1.0 - zoom)

	campfire.intensity = PlayerRoster.fire_intensity()

	_seat_heroes()

func _seat_heroes():

	var seats = []
	for child in seats_root.get_children():
		if child is Marker2D:
			seats.append(child)

	var assignment = _resolve_seating(seats)

	for seat_name in assignment:
		var hero_index = assignment[seat_name]
		var seat = seats_root.get_node(NodePath(seat_name))
		_spawn_seated(seat, hero_index)

## Rebuilds a hero's seated actor in place (e.g. after a loadout change).
func refresh_hero(hero_index: int):
	if not _seated.has(hero_index):
		return
	var record = _seated[hero_index]
	var seat = record.seat
	if is_instance_valid(record.actor):
		record.actor.queue_free()
	if is_instance_valid(record.plate):
		record.plate.queue_free()
	_spawn_seated(seat, hero_index)

func _spawn_seated(seat, hero_index):

	var template = PlayerRoster.heroes[hero_index]

	var actor = template.actor_scene.instantiate()
	seat.add_child(actor)

	# Seats further back are smaller, for a touch of depth.
	var depth = remap(
		clampf(seat.position.y, 520.0, 820.0),
		520.0, 820.0, 0.72, 1.0
	)
	actor.scale = Vector2(depth, depth)

	# Everyone turns toward the fire.
	if seat.position.x > campfire.position.x:
		actor.scale.x = -depth

	# Seat markers sit on the ground line; lift the actor so its
	# feet land on the marker.
	actor.position = Vector2(0, -ACTOR_FOOT_OFFSET * depth)

	actor.equip_gear(template.starting_gear)

	var plate = null
	if interactive:
		plate = _make_nameplate(template.hero_name, depth)
		seat.add_child(plate)
		_add_picker(actor, hero_index)

	_seated[hero_index] = {"seat": seat, "actor": actor, "plate": plate}

func _make_nameplate(text, depth) -> Control:
	var plate = Label.new()
	plate.text = text
	plate.add_theme_font_override("font", NAMEPLATE_FONT)
	plate.add_theme_font_size_override("font_size", int(30 * depth))
	plate.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	plate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	plate.add_theme_constant_override("outline_size", 8)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.size = Vector2(260, 40)
	plate.position = Vector2(-130, -250 * depth)
	plate.visible = false
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate

func _add_picker(actor, hero_index):

	# A rectangle roughly covering the body so the hero is clickable.
	var area = Area2D.new()
	area.input_pickable = true
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(120, 250)
	shape.shape = rect
	shape.position = Vector2(0, -25)
	area.add_child(shape)
	actor.add_child(area)

	area.mouse_entered.connect(_on_hero_hover.bind(hero_index, true))
	area.mouse_exited.connect(_on_hero_hover.bind(hero_index, false))
	area.input_event.connect(_on_hero_input.bind(hero_index))

func _on_hero_hover(hero_index, entered):
	if not _seated.has(hero_index):
		return
	var record = _seated[hero_index]
	_set_outline(record.actor, entered)
	if is_instance_valid(record.plate):
		record.plate.visible = entered

func _on_hero_input(_viewport, event, _shape_idx, hero_index):
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		hero_selected.emit(hero_index)

## Clears any active hover highlight (used when a modal takes over).
func clear_hover():
	for hero_index in _seated:
		var record = _seated[hero_index]
		_set_outline(record.actor, false)
		if is_instance_valid(record.plate):
			record.plate.visible = false

func _set_outline(actor, on):
	if not is_instance_valid(actor):
		return
	var sprites = actor.find_children("*", "Sprite2D", true, false)
	for sprite in sprites:
		if on:
			var mat = ShaderMaterial.new()
			mat.shader = OUTLINE_SHADER
			# Keep the outline ~3px on screen regardless of how much
			# this particular sprite is scaled down.
			var gscale = sprite.global_scale
			var avg = max(0.02, (abs(gscale.x) + abs(gscale.y)) * 0.5)
			mat.set_shader_parameter("outline_width", clampf(3.0 / avg, 1.0, 30.0))
			sprite.material = mat
		else:
			sprite.material = null

func _resolve_seating(seats) -> Dictionary:

	if PlayerRoster.keep_seating:
		PlayerRoster.keep_seating = false
		if _seating_valid(PlayerRoster.saved_seating, seats):
			return PlayerRoster.saved_seating

	seats.shuffle()

	var assignment = {}
	for i in mini(PlayerRoster.heroes.size(), seats.size()):
		assignment[String(seats[i].name)] = i

	PlayerRoster.saved_seating = assignment
	return assignment

func _seating_valid(assignment, seats) -> bool:

	if assignment.size() != mini(PlayerRoster.heroes.size(), seats.size()):
		return false

	var seat_names = seats.map(func(seat): return String(seat.name))
	for seat_name in assignment:
		if not seat_names.has(seat_name):
			return false

	return true
